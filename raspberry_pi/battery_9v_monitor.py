#!/usr/bin/env python3
"""
9V Battery Health Monitor - No Alternator Required
Uses voltage-based health assessment for 9V batteries
"""

import time
import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any
import signal
import sys

try:
    import board
    import busio
    import adafruit_ads1x15.ads1115 as ADS
    from adafruit_ads1x15.analog_in import AnalogIn
    import paho.mqtt.client as mqtt
except ImportError as e:
    print(f"Missing required packages. Install with:")
    print("pip3 install adafruit-circuitpython-ads1x15 paho-mqtt")
    print(f"Error: {e}")
    sys.exit(1)

# Configuration for 9V battery testing
CONFIG = {
    "mqtt": {
        "broker": "localhost",
        "port": 1883,
        "username": None,
        "password": None,
        "keepalive": 60
    },
    "car": {
        "car_id": "car_1",
        "device_id": "rpi_9v_test"
    },
    "sensors": {
        "voltage_channel": 0,
        "voltage_sensor_ratio": 5.0,
        "sample_interval": 3.0,  # Faster sampling for testing
        "publish_interval": 5.0
    },
    "battery_9v": {
        "nominal_voltage": 9.0,
        "fresh_voltage": 9.5,      # Brand new 9V
        "good_voltage": 8.5,       # Still usable
        "weak_voltage": 7.5,       # Getting weak
        "dead_voltage": 6.0        # Replace battery
    }
}

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/pi/battery_9v_monitor.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class Battery9VMonitor:
    def __init__(self):
        self.running = False
        self.mqtt_client = None
        self.ads = None
        self.voltage_channel = None
        self.last_publish = 0
        self.voltage_readings = []
        self.voltage_history = []  # For trend analysis
        
    def setup_hardware(self):
        """Initialize ADS1115 and voltage sensor"""
        try:
            i2c = busio.I2C(board.SCL, board.SDA)
            self.ads = ADS.ADS1115(i2c)
            channel = CONFIG["sensors"]["voltage_channel"]
            self.voltage_channel = AnalogIn(self.ads, getattr(ADS, f'P{channel}'))
            
            logger.info(f"ADS1115 initialized for 9V testing, channel {channel}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize hardware: {e}")
            return False
    
    def setup_mqtt(self):
        """Initialize MQTT client"""
        try:
            self.mqtt_client = mqtt.Client()
            
            if CONFIG["mqtt"]["username"]:
                self.mqtt_client.username_pw_set(
                    CONFIG["mqtt"]["username"],
                    CONFIG["mqtt"]["password"]
                )
            
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_disconnect = self.on_mqtt_disconnect
            self.mqtt_client.on_message = self.on_mqtt_message
            
            self.mqtt_client.connect(
                CONFIG["mqtt"]["broker"],
                CONFIG["mqtt"]["port"],
                CONFIG["mqtt"]["keepalive"]
            )
            
            self.mqtt_client.loop_start()
            logger.info(f"MQTT client connected to {CONFIG['mqtt']['broker']}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to setup MQTT: {e}")
            return False
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logger.info("Connected to MQTT broker")
            ping_topic = f"car/{CONFIG['car']['car_id']}/ping"
            client.subscribe(ping_topic)
        else:
            logger.error(f"Failed to connect to MQTT broker: {rc}")
    
    def on_mqtt_disconnect(self, client, userdata, rc):
        logger.warning(f"Disconnected from MQTT broker: {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        try:
            topic = msg.topic
            payload = msg.payload.decode()
            logger.info(f"Received: {topic} -> {payload}")
            
            if topic.endswith("/ping"):
                car_id = CONFIG['car']['car_id']
                pong_topic = f"car/{car_id}/pong"
                response = {
                    "timestamp": datetime.now().isoformat(),
                    "device_id": CONFIG['car']['device_id'],
                    "status": "online",
                    "battery_type": "9V_alkaline"
                }
                client.publish(pong_topic, json.dumps(response))
                
        except Exception as e:
            logger.error(f"Error handling MQTT message: {e}")
    
    def read_voltage(self) -> Optional[float]:
        """Read voltage from 9V battery"""
        try:
            sensor_output = self.voltage_channel.voltage
            actual_voltage = sensor_output * CONFIG["sensors"]["voltage_sensor_ratio"]
            return actual_voltage
        except Exception as e:
            logger.error(f"Failed to read voltage: {e}")
            return None
    
    def calculate_9v_battery_health(self, voltage: float) -> Dict[str, Any]:
        """
        Calculate 9V battery health without alternator
        Uses voltage-based assessment with trend analysis
        """
        config = CONFIG["battery_9v"]
        
        # Add to voltage history for trend analysis
        self.voltage_history.append({
            "voltage": voltage,
            "timestamp": time.time()
        })
        
        # Keep only last 10 minutes of history
        cutoff_time = time.time() - 600  # 10 minutes
        self.voltage_history = [
            reading for reading in self.voltage_history 
            if reading["timestamp"] > cutoff_time
        ]
        
        # Calculate State of Charge (SOC) for 9V battery
        if voltage >= config["fresh_voltage"]:
            soc = 100.0
        elif voltage >= config["good_voltage"]:
            # Linear scale between good and fresh
            range_size = config["fresh_voltage"] - config["good_voltage"]
            soc = 80 + ((voltage - config["good_voltage"]) / range_size) * 20
        elif voltage >= config["weak_voltage"]:
            # Linear scale between weak and good
            range_size = config["good_voltage"] - config["weak_voltage"]
            soc = 40 + ((voltage - config["weak_voltage"]) / range_size) * 40
        elif voltage >= config["dead_voltage"]:
            # Linear scale between dead and weak
            range_size = config["weak_voltage"] - config["dead_voltage"]
            soc = 10 + ((voltage - config["dead_voltage"]) / range_size) * 30
        else:
            soc = 0.0
        
        # Calculate State of Health (SOH) using voltage trend
        soh = self.calculate_voltage_trend_health(voltage, config)
        
        # Determine status
        if voltage >= config["fresh_voltage"]:
            status = "fresh"
            recommendation = "Battery is fresh and ready to use"
        elif voltage >= config["good_voltage"]:
            status = "good"
            recommendation = "Battery is in good condition"
        elif voltage >= config["weak_voltage"]:
            status = "weak"
            recommendation = "Battery is getting weak, consider replacement soon"
        elif voltage >= config["dead_voltage"]:
            status = "low"
            recommendation = "Battery is low, replace soon"
        else:
            status = "dead"
            recommendation = "Battery is dead, replace immediately"
        
        # Calculate estimated remaining time (simplified)
        estimated_hours = self.estimate_remaining_time(voltage, soc)
        
        return {
            "voltage": round(voltage, 2),
            "soc": round(soc, 1),
            "soh": round(soh, 1),
            "status": status,
            "recommendation": recommendation,
            "estimated_hours": estimated_hours,
            "battery_type": "9V_alkaline",
            "measurement_method": "voltage_only",
            "timestamp": datetime.now().isoformat()
        }
    
    def calculate_voltage_trend_health(self, current_voltage: float, config: Dict) -> float:
        """Calculate health based on voltage stability and trend"""
        if len(self.voltage_history) < 3:
            # Not enough data, use voltage-based estimate
            voltage_ratio = current_voltage / config["nominal_voltage"]
            return min(100, max(0, voltage_ratio * 100))
        
        # Calculate voltage stability (lower variance = better health)
        voltages = [reading["voltage"] for reading in self.voltage_history]
        avg_voltage = sum(voltages) / len(voltages)
        variance = sum((v - avg_voltage) ** 2 for v in voltages) / len(voltages)
        stability_score = max(0, 100 - (variance * 1000))  # Scale variance
        
        # Calculate voltage decline rate
        if len(self.voltage_history) >= 5:
            recent_avg = sum(voltages[-3:]) / 3
            older_avg = sum(voltages[:3]) / 3
            decline_rate = (older_avg - recent_avg) / (self.voltage_history[-1]["timestamp"] - self.voltage_history[0]["timestamp"]) * 3600  # Per hour
            decline_penalty = min(50, max(0, decline_rate * 100))
        else:
            decline_penalty = 0
        
        # Combine voltage level, stability, and decline
        voltage_health = (current_voltage / config["fresh_voltage"]) * 100
        combined_health = (voltage_health * 0.6 + stability_score * 0.3) - decline_penalty * 0.1
        
        return max(0, min(100, combined_health))
    
    def estimate_remaining_time(self, voltage: float, soc: float) -> float:
        """Estimate remaining battery life in hours (very simplified)"""
        config = CONFIG["battery_9v"]
        
        if voltage >= config["good_voltage"]:
            # Good battery, estimate based on SOC
            base_hours = 20  # Typical 9V alkaline life
            return (soc / 100) * base_hours
        elif voltage >= config["weak_voltage"]:
            # Weak battery, shorter estimate
            return min(5, (soc / 100) * 8)
        else:
            # Very weak battery
            return min(1, (soc / 100) * 2)
    
    def publish_sensor_data(self, voltage: float):
        """Publish 9V battery data to MQTT"""
        if not self.mqtt_client:
            return
        
        car_id = CONFIG['car']['car_id']
        timestamp = datetime.now().isoformat()
        
        try:
            # Calculate 9V battery health
            health_data = self.calculate_9v_battery_health(voltage)
            
            # Publish to battery health topic
            health_topic = f"car/{car_id}/battery/health"
            self.mqtt_client.publish(health_topic, json.dumps(health_data))
            
            # Publish individual sensor readings
            base_id = f"sensor_{int(time.time())}"
            
            # Voltage reading
            voltage_data = {
                "id": f"{base_id}_voltage",
                "carId": car_id,
                "sensorType": "voltage",
                "value": voltage,
                "unit": "V",
                "timestamp": timestamp
            }
            voltage_topic = f"car/{car_id}/sensors/voltage"
            self.mqtt_client.publish(voltage_topic, json.dumps(voltage_data))
            
            # Battery SOC
            soc_data = {
                "id": f"{base_id}_battery",
                "carId": car_id,
                "sensorType": "battery",
                "value": health_data["soc"],
                "unit": "%",
                "timestamp": timestamp
            }
            battery_topic = f"car/{car_id}/sensors/battery"
            self.mqtt_client.publish(battery_topic, json.dumps(soc_data))
            
            logger.info(f"9V Battery: V={voltage:.2f}V, SOC={health_data['soc']:.1f}%, SOH={health_data['soh']:.1f}%, Status={health_data['status']}")
            logger.info(f"Estimated time: {health_data['estimated_hours']:.1f}h, {health_data['recommendation']}")
            
        except Exception as e:
            logger.error(f"Failed to publish sensor data: {e}")
    
    def run(self):
        """Main monitoring loop"""
        logger.info("Starting 9V battery monitoring (no alternator)...")
        
        if not self.setup_hardware():
            logger.error("Hardware setup failed")
            return False
        
        if not self.setup_mqtt():
            logger.error("MQTT setup failed")
            return False
        
        self.running = True
        sample_interval = CONFIG["sensors"]["sample_interval"]
        publish_interval = CONFIG["sensors"]["publish_interval"]
        
        logger.info(f"9V monitoring started - sampling every {sample_interval}s, publishing every {publish_interval}s")
        
        try:
            while self.running:
                current_time = time.time()
                
                voltage = self.read_voltage()
                if voltage is not None:
                    self.voltage_readings.append(voltage)
                    
                    max_readings = int(publish_interval / sample_interval)
                    if len(self.voltage_readings) > max_readings:
                        self.voltage_readings = self.voltage_readings[-max_readings:]
                    
                    if current_time - self.last_publish >= publish_interval:
                        avg_voltage = sum(self.voltage_readings) / len(self.voltage_readings)
                        self.publish_sensor_data(avg_voltage)
                        self.last_publish = current_time
                
                time.sleep(sample_interval)
                
        except KeyboardInterrupt:
            logger.info("9V monitoring stopped by user")
        except Exception as e:
            logger.error(f"Monitoring error: {e}")
        finally:
            self.cleanup()
        
        return True
    
    def cleanup(self):
        """Clean up resources"""
        self.running = False
        if self.mqtt_client:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
        logger.info("9V monitor cleanup completed")

def signal_handler(sig, frame):
    logger.info("Received interrupt signal")
    sys.exit(0)

def main():
    signal.signal(signal.SIGINT, signal_handler)
    
    logger.info("IoT E-Waste 9V Battery Monitor starting...")
    logger.info("No alternator required - voltage-based health assessment")
    logger.info(f"Configuration: {json.dumps(CONFIG, indent=2)}")
    
    monitor = Battery9VMonitor()
    
    try:
        success = monitor.run()
        if not success:
            sys.exit(1)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
