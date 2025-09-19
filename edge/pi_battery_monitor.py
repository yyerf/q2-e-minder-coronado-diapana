#!/usr/bin/env python3
"""
Raspberry Pi 3 B+ Battery Monitor (No Alternator)
-------------------------------------------------
Estimates:
  - State of Charge (SoC) via rest Open Circuit Voltage (OCV)
  - Internal resistance via natural load steps
  - Simple capacity trend (if current sensor present)
  - Composite State of Health (SoH)
Publishes metrics to MQTT.

Hardware Assumptions:
  - Voltage divider scaling 0–15V -> 0–1.8V (ADC input range)
  - External ADC (ADS1115) for better resolution than Pi + MCP3008 optional
  - Optional bidirectional current sensor (INA219 / INA226) OR Hall sensor -> I2C
  - Optional DS18B20 for battery temperature

Edit CONFIG section to match your hardware.
"""
import time
import math
import json
import statistics
from collections import deque
from datetime import datetime, timedelta

try:
    import Adafruit_ADS1x15  # ADS1115
except ImportError:
    Adafruit_ADS1x15 = None

try:
    from w1thermsensor import W1ThermSensor
except ImportError:
    W1ThermSensor = None

try:
    import smbus2
except ImportError:
    smbus2 = None

try:
    import paho.mqtt.client as mqtt
except ImportError:
    mqtt = None

# ---------------- Configuration -----------------
CONFIG = {
    'car_id': 'car_1',
    'loop_interval_sec': 2.0,
    'publish_interval_sec': 10.0,
    'ocv_rest_min_sec': 1800,          # 30 min rest for valid OCV snapshot
    'rest_current_threshold_a': 0.3,   # If current magnitude below this considered resting
    'voltage_divider_ratio': (100_000 + 10_000) / 10_000,  # Rtop=100k, Rbottom=10k -> 11.0
    'ads_gain': 1,                     # ADS1115 gain (±4.096V) adjust if needed
    'nominal_capacity_ah': 60.0,
    'reference_temp_c': 25.0,
    'temp_coeff_v_per_cell': -0.002,   # ~ -2 mV/°C per cell => -0.012V/°C pack
    'rint_window': 10,
    'mqtt': {
        'host': 'broker.hivemq.com',
        'port': 1883,
        'topic': 'car/{carId}/battery/health'
    }
}

# OCV table (12V lead-acid @25°C)
OCV_TABLE = [
    (12.73, 1.00),
    (12.62, 0.90),
    (12.50, 0.80),
    (12.42, 0.70),
    (12.32, 0.60),
    (12.20, 0.50),
    (12.06, 0.40),
    (11.90, 0.30),
    (11.75, 0.20),
    (11.58, 0.10),
    (10.50, 0.00)
]

# -------------- Hardware Wrappers ---------------
class VoltageReader:
    def __init__(self):
        if Adafruit_ADS1x15 is None:
            raise RuntimeError('ADS1115 lib not installed')
        self.adc = Adafruit_ADS1x15.ADS1115()
        self.gain = CONFIG['ads_gain']

    def read_voltage(self):
        raw = self.adc.read_adc(0, gain=self.gain)
        # ADS1115: 16-bit (actually 15-bit + sign) -> LSB @ gain ±4.096V = 0.125mV
        # Library handles scaling? We compute manually:
        # FS = 4.096V -> raw range 32767 -> LSB ≈ 4.096/32767
        fs_v = 4.096
        volts_adc = (raw / 32767.0) * fs_v
        pack_v = volts_adc * CONFIG['voltage_divider_ratio']
        return pack_v

class CurrentReaderINA219:
    def __init__(self):
        try:
            from ina219 import INA219
        except ImportError:
            raise RuntimeError('INA219 lib not installed')
        self.ina = INA219(shunt_ohms=0.1, max_expected_amps=10)  # adjust
        self.ina.configure()

    def read_current(self):  # Amps (positive = discharge)
        # INA219 reports positive for load usually; adapt sign if needed
        return self.ina.current() / 1000.0  # mA -> A

class TemperatureReader:
    def __init__(self):
        if W1ThermSensor is None:
            self.sensor = None
        else:
            self.sensor = W1ThermSensor()

    def read_temp(self):
        if not self.sensor:
            return None
        return self.sensor.get_temperature()

# -------------- SoC / SoH Logic ------------------

def interpolate_soc(ocv):
    table = sorted(OCV_TABLE, reverse=True)
    for i in range(len(table) - 1):
        v1, s1 = table[i]
        v2, s2 = table[i + 1]
        if v1 >= ocv >= v2:
            # linear interpolation
            frac = (ocv - v2) / (v1 - v2)
            return s2 + frac * (s1 - s2)
    if ocv >= table[0][0]:
        return 1.0
    if ocv <= table[-1][0]:
        return 0.0
    return 0.0

class BatteryEstimator:
    def __init__(self):
        self.last_rest_time = None
        self.last_rest_voltage = None
        self.last_soc = None
        self.rint_events = deque(maxlen=CONFIG['rint_window'])
        self.prev_voltage = None
        self.prev_current = None
        self.capacity_est_ah = CONFIG['nominal_capacity_ah']
        self.cycle_discharge_ah = 0.0
        self.last_soc_full_mark = None
        self.reference_rint = None

    def temperature_compensate(self, voltage, temp_c):
        if temp_c is None:
            return voltage
        delta = (CONFIG['reference_temp_c'] - temp_c) * (CONFIG['temp_coeff_v_per_cell'] * 6)
        return voltage + delta

    def update_rest(self, voltage, current, temp_c):
        now = time.time()
        resting = (current is None or abs(current) < CONFIG['rest_current_threshold_a'])
        if resting:
            if self.last_rest_time is None:
                self.last_rest_time = now
            elif (now - self.last_rest_time) >= CONFIG['ocv_rest_min_sec']:
                # Accept as rest OCV
                ocv = self.temperature_compensate(voltage, temp_c)
                self.last_rest_voltage = ocv
                self.last_soc = interpolate_soc(ocv)
        else:
            self.last_rest_time = None

    def detect_rint(self, voltage, current):
        if self.prev_voltage is None or self.prev_current is None or current is None:
            self.prev_voltage = voltage
            self.prev_current = current
            return
        dv = voltage - self.prev_voltage
        di = current - self.prev_current
        if abs(di) > 0.5 and abs(dv) > 0.02:  # thresholds
            r = abs(dv) / abs(di)
            self.rint_events.append(r)
            if self.reference_rint is None and len(self.rint_events) >= 5:
                self.reference_rint = statistics.median(self.rint_events)
        self.prev_voltage = voltage
        self.prev_current = current

    def update_capacity(self, current, dt_sec):
        if current is None or self.last_soc is None:
            return
        # Positive current = discharge assumption; adjust if sign reversed
        if current > 0:
            self.cycle_discharge_ah += current * dt_sec / 3600.0
        # If near full SoC mark a top
        if self.last_soc >= 0.95:
            if self.last_soc_full_mark is None:
                self.last_soc_full_mark = time.time()
            elif time.time() - self.last_soc_full_mark > 1800:  # stable near full
                # Use cycle discharge as observed capacity
                if self.cycle_discharge_ah > 1.0:  # ignore tiny
                    # Exponential smoothing
                    alpha = 0.3
                    self.capacity_est_ah = alpha * self.cycle_discharge_ah + (1 - alpha) * self.capacity_est_ah
                self.cycle_discharge_ah = 0.0
        else:
            self.last_soc_full_mark = None

    def compute_soh(self):
        # Capacity component
        soh_c = min(self.capacity_est_ah / CONFIG['nominal_capacity_ah'], 1.0)
        # Resistance component
        if self.rint_events:
            current_r = statistics.median(self.rint_events)
            if self.reference_rint is None:
                soh_r = 1.0
            else:
                soh_r = max(min(self.reference_rint / current_r, 1.0), 0.0)
        else:
            soh_r = 1.0
        # Combine
        soh = 0.6 * soh_c + 0.4 * soh_r
        return soh * 100.0, soh_c * 100.0, soh_r * 100.0

    def build_flags(self, soh, soh_c, soh_r):
        flags = []
        if soh < 50: flags.append('critical_health')
        elif soh < 70: flags.append('degraded')
        if soh_c < 70: flags.append('capacity_fade')
        if soh_r < 70: flags.append('resistance_high')
        if self.last_soc is None:
            flags.append('soc_unconfirmed_rest')
        return flags

    def snapshot(self, voltage, current, temp_c):
        soh, soh_c, soh_r = self.compute_soh()
        return {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'voltage': round(voltage, 3),
            'temp_c': round(temp_c, 2) if temp_c is not None else None,
            'soc': round(self.last_soc * 100, 1) if self.last_soc is not None else None,
            'soh': round(soh, 1),
            'soh_capacity': round(soh_c, 1),
            'soh_resistance': round(soh_r, 1),
            'capacity_est_ah': round(self.capacity_est_ah, 2),
            'r_int_median': round(statistics.median(self.rint_events), 4) if self.rint_events else None,
            'flags': self.build_flags(soh, soh_c, soh_r)
        }

# -------------- MQTT Wrapper ---------------------
class MqttPublisher:
    def __init__(self):
        if mqtt is None:
            raise RuntimeError('paho-mqtt not installed')
        self.client = mqtt.Client()
        self.client.connect(CONFIG['mqtt']['host'], CONFIG['mqtt']['port'], 60)
        self.topic = CONFIG['mqtt']['topic'].replace('{carId}', CONFIG['car_id'])

    def publish(self, payload: dict):
        self.client.publish(self.topic, json.dumps(payload), qos=0, retain=False)

# -------------- Main Loop ------------------------

def main():
    voltage_reader = VoltageReader()
    temp_reader = TemperatureReader()
    # Optional current sensor; wrap in try
    try:
        current_reader = CurrentReaderINA219()
    except Exception:
        current_reader = None
    estimator = BatteryEstimator()

    try:
        publisher = MqttPublisher()
    except Exception as e:
        publisher = None
        print(f"MQTT disabled: {e}")

    last_pub = 0
    last_time = time.time()

    print('Starting battery monitor loop...')
    while True:
        now = time.time()
        dt = now - last_time
        last_time = now

        try:
            voltage = voltage_reader.read_voltage()
        except Exception as e:
            print('Voltage read error:', e)
            time.sleep(CONFIG['loop_interval_sec'])
            continue

        current = None
        if current_reader:
            try:
                current = current_reader.read_current()
            except Exception as e:
                print('Current read error:', e)

        temp_c = temp_reader.read_temp() if temp_reader else None

        # Update estimations
        estimator.update_rest(voltage, current, temp_c)
        estimator.detect_rint(voltage, current)
        estimator.update_capacity(current, dt)

        if (now - last_pub) >= CONFIG['publish_interval_sec']:
            snap = estimator.snapshot(voltage, current, temp_c)
            snap['car_id'] = CONFIG['car_id']
            if publisher:
                try:
                    publisher.publish(snap)
                except Exception as e:
                    print('MQTT publish error:', e)
            print('[DATA]', json.dumps(snap))
            last_pub = now

        time.sleep(CONFIG['loop_interval_sec'])

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('Exiting.')
