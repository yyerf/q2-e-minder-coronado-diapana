#!/usr/bin/env python3

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

# Configuration
CONFIG = {
    "mqtt": {
        "broker": "localhost",  # Change to "localhost" since MQTT runs on the same Pi
        "port": 1883,
        "username": None,  
        "password": None,
        "keepalive": 60
    },
    "car": {
        "car_id": "car_1",  # Match your Flutter app's car ID
        "device_id": "rpi_001"
    },
    "sensors": {
        "voltage_channel": 0,  # ADS1115 channel (0-3) for voltage sensor
        "voltage_sensor_ratio": 5.0,  # Your voltage sensor module ratio (typically 5:1)
        "sample_interval": 5.0,  # Seconds between readings
        "publish_interval": 10.0  # Seconds between MQTT publishes
    },
    "battery": {
        "nominal_voltage": 12.0,
        "min_voltage": 10.5,
        "max_voltage": 14.4,
        "full_charge_voltage": 12.6
    }
}

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/home/pi/battery_monitor.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class BatteryMonitor:
    def __init__(self):
        self.running = False
        self.mqtt_client = None
        self.ads = None
        self.voltage_channel = None
        self.last_publish = 0
        self.voltage_readings = []
        
    def setup_hardware(self):
        """Initialize ADS1115 and voltage sensor"""
        try:
            # Create the I2C bus
            i2c = busio.I2C(board.SCL, board.SDA)
            
            # Create the ADC object
            self.ads = ADS.ADS1115(i2c)
            
            # Create single-ended input on channel 0 (adjust if needed)
            channel = CONFIG["sensors"]["voltage_channel"]
            self.voltage_channel = AnalogIn(self.ads, getattr(ADS, f'P{channel}'))
            
            logger.info(f"ADS1115 initialized on I2C, channel {channel}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize hardware: {e}")
            return False
    
    def setup_mqtt(self):
        """Initialize MQTT client and connect to broker"""
        try:
            self.mqtt_client = mqtt.Client()
            
            # Set username/password if configured
            if CONFIG["mqtt"]["username"]:
                self.mqtt_client.username_pw_set(
                    CONFIG["mqtt"]["username"],
                    CONFIG["mqtt"]["password"]
                )
            
            # Set callbacks
            self.mqtt_client.on_connect = self.on_mqtt_connect
            self.mqtt_client.on_disconnect = self.on_mqtt_disconnect
            self.mqtt_client.on_message = self.on_mqtt_message
            
            # Connect to broker
            self.mqtt_client.connect(
                CONFIG["mqtt"]["broker"],
                CONFIG["mqtt"]["port"],
                CONFIG["mqtt"]["keepalive"]
            )
            
            # Start the MQTT loop in background
            self.mqtt_client.loop_start()
            
            logger.info(f"MQTT client initialized, connecting to {CONFIG['mqtt']['broker']}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to setup MQTT: {e}")
            return False
    
    def on_mqtt_connect(self, client, userdata, flags, rc):
        """Callback for MQTT connection"""
        if rc == 0:
            logger.info("Connected to MQTT broker")
            # Subscribe to ping topic
            ping_topic = f"car/{CONFIG['car']['car_id']}/ping"
            client.subscribe(ping_topic)
            logger.info(f"Subscribed to {ping_topic}")
        else:
            logger.error(f"Failed to connect to MQTT broker: {rc}")
    
    def on_mqtt_disconnect(self, client, userdata, rc):
        """Callback for MQTT disconnection"""
        logger.warning(f"Disconnected from MQTT broker: {rc}")
    
    def on_mqtt_message(self, client, userdata, msg):
        """Handle incoming MQTT messages (like ping)"""
        try:
            topic = msg.topic
            payload = msg.payload.decode()
            logger.info(f"Received: {topic} -> {payload}")
            
            # Respond to ping
            if topic.endswith("/ping"):
                car_id = CONFIG['car']['car_id']
                pong_topic = f"car/{car_id}/pong"
                response = {
                    "timestamp": datetime.now().isoformat(),
                    "device_id": CONFIG['car']['device_id'],
                    "status": "online"
                }
                client.publish(pong_topic, json.dumps(response))
                logger.info(f"Sent pong response to {pong_topic}")
                
        except Exception as e:
            logger.error(f"Error handling MQTT message: {e}")
    
    def read_voltage(self) -> Optional[float]:
        """Read voltage from ADS1115 with voltage sensor module"""
        try:
            # Read raw voltage from ADC (this is the voltage sensor's output)
            sensor_output = self.voltage_channel.voltage
            
            # Calculate actual battery voltage
            # Your voltage sensor module already does voltage division
            actual_voltage = sensor_output * CONFIG["sensors"]["voltage_sensor_ratio"]
            
            return actual_voltage
            
        except Exception as e:
            logger.error(f"Failed to read voltage: {e}")
            return None
    
    def calculate_battery_health(self, voltage: float) -> Dict[str, Any]:
        """
        Calculate car battery health without alternator
        Uses advanced voltage-based assessment with load testing simulation
        """
        config = CONFIG["battery"]
        
        # Add to voltage history for trend analysis
        current_time = time.time()
        if not hasattr(self, 'voltage_history'):
            self.voltage_history = []
        
        self.voltage_history.append({
            "voltage": voltage,
            "timestamp": current_time
        })
        
        # Keep only last 20 minutes of history for trend analysis
        cutoff_time = current_time - 1200  # 20 minutes
        self.voltage_history = [
            reading for reading in self.voltage_history 
            if reading["timestamp"] > cutoff_time
        ]
        
        # Calculate State of Charge (SOC) for 12V car battery (no alternator)
        # More accurate voltage mapping for lead-acid batteries
        if voltage >= 12.7:
            soc = 100.0  # Fully charged
        elif voltage >= 12.4:
            soc = 75 + ((voltage - 12.4) / 0.3) * 25
        elif voltage >= 12.2:
            soc = 50 + ((voltage - 12.2) / 0.2) * 25
        elif voltage >= 12.0:
            soc = 25 + ((voltage - 12.0) / 0.2) * 25
        elif voltage >= 11.8:
            soc = 10 + ((voltage - 11.8) / 0.2) * 15
        elif voltage >= config["min_voltage"]:
            soc = 0 + ((voltage - config["min_voltage"]) / (11.8 - config["min_voltage"])) * 10
        else:
            soc = 0.0
        
        # Calculate State of Health (SOH) using voltage analysis
        soh = self.calculate_advanced_soh(voltage, config)
        
        # Determine battery condition and recommendations
        condition_data = self.assess_battery_condition(voltage, soh, soc)
        
        # Calculate cold cranking capacity estimate
        cca_estimate = self.estimate_cold_cranking_capacity(voltage, soh)
        
        return {
            "voltage": round(voltage, 2),
            "soc": round(soc, 1),
            "soh": round(soh, 1),
            "status": condition_data["status"],
            "condition": condition_data["condition"],
            "recommendation": condition_data["recommendation"],
            "cca_estimate": cca_estimate,
            "estimated_life_months": condition_data["estimated_life"],
            "battery_type": "12V_lead_acid",
            "measurement_method": "voltage_trend_analysis",
            "timestamp": datetime.now().isoformat()
        }
    
    def calculate_advanced_soh(self, current_voltage: float, config: Dict) -> float:
        """Advanced SOH calculation without alternator"""
        
        # Base health from voltage level
        if current_voltage >= 12.6:
            voltage_health = 100
        elif current_voltage >= 12.4:
            voltage_health = 85 + ((current_voltage - 12.4) / 0.2) * 15
        elif current_voltage >= 12.2:
            voltage_health = 70 + ((current_voltage - 12.2) / 0.2) * 15
        elif current_voltage >= 12.0:
            voltage_health = 50 + ((current_voltage - 12.0) / 0.2) * 20
        elif current_voltage >= 11.8:
            voltage_health = 25 + ((current_voltage - 11.8) / 0.2) * 25
        else:
            voltage_health = max(0, (current_voltage - 10.5) / 1.3 * 25)
        
        # Voltage stability analysis
        if len(self.voltage_history) >= 5:
            voltages = [reading["voltage"] for reading in self.voltage_history]
            
            # Calculate voltage variance (stability)
            avg_voltage = sum(voltages) / len(voltages)
            variance = sum((v - avg_voltage) ** 2 for v in voltages) / len(voltages)
            stability_score = max(0, 100 - (variance * 500))  # Penalize high variance
            
            # Calculate voltage recovery trend
            if len(voltages) >= 10:
                recent_trend = sum(voltages[-5:]) / 5 - sum(voltages[-10:-5]) / 5
                if recent_trend > 0:
                    recovery_bonus = min(10, recent_trend * 50)
                else:
                    recovery_penalty = min(20, abs(recent_trend) * 100)
                    recovery_bonus = -recovery_penalty
            else:
                recovery_bonus = 0
            
            # Combine factors
            final_soh = (voltage_health * 0.7 + stability_score * 0.2) + recovery_bonus * 0.1
        else:
            final_soh = voltage_health
        
        return max(0, min(100, final_soh))
    
    def assess_battery_condition(self, voltage: float, soh: float, soc: float) -> Dict[str, Any]:
        """Assess overall battery condition and provide recommendations"""
        
        if voltage >= 12.6 and soh >= 85:
            status = "excellent"
            condition = "Battery is in excellent condition"
            recommendation = "Battery is healthy, continue regular maintenance"
            estimated_life = 36  # months
        elif voltage >= 12.4 and soh >= 75:
            status = "good"
            condition = "Battery is in good condition"
            recommendation = "Battery is functioning well, monitor voltage regularly"
            estimated_life = 24
        elif voltage >= 12.2 and soh >= 60:
            status = "fair"
            condition = "Battery is showing signs of aging"
            recommendation = "Consider load testing, may need replacement within 6 months"
            estimated_life = 12
        elif voltage >= 12.0 and soh >= 40:
            status = "poor"
            condition = "Battery is in poor condition"
            recommendation = "Replace battery soon, may fail to start vehicle"
            estimated_life = 6
        elif voltage >= 11.8:
            status = "critical"
            condition = "Battery is critically low"
            recommendation = "Replace battery immediately, risk of being stranded"
            estimated_life = 1
        else:
            status = "failed"
            condition = "Battery has failed"
            recommendation = "Battery is dead, replace immediately"
            estimated_life = 0
        
        return {
            "status": status,
            "condition": condition,
            "recommendation": recommendation,
            "estimated_life": estimated_life
        }
    
    def estimate_cold_cranking_capacity(self, voltage: float, soh: float) -> int:
        """Estimate remaining cold cranking amps (CCA)"""
        # Typical car battery is 500-800 CCA when new
        # Estimate based on voltage and SOH
        base_cca = 600  # Average new battery CCA
        
        voltage_factor = min(1.0, max(0.1, (voltage - 10.5) / 2.1))  # 10.5V to 12.6V range
        soh_factor = soh / 100
        
        estimated_cca = int(base_cca * voltage_factor * soh_factor)
        return max(0, estimated_cca)
    
    def publish_sensor_data(self, voltage: float):
        """Publish sensor data to MQTT topics"""
        if not self.mqtt_client:
            return
        
        car_id = CONFIG['car']['car_id']
        timestamp = datetime.now().isoformat()
        
        try:
            # Calculate battery health
            health_data = self.calculate_battery_health(voltage)
            
            # Publish to battery health topic (composite data)
            health_topic = f"car/{car_id}/battery/health"
            self.mqtt_client.publish(health_topic, json.dumps(health_data))
            
            # Publish individual sensor readings (for compatibility)
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
            
            logger.info(f"Published: V={voltage:.2f}V, SOC={health_data['soc']:.1f}%, SOH={health_data['soh']:.1f}%")
            
        except Exception as e:
            logger.error(f"Failed to publish sensor data: {e}")
    
    def run(self):
        """Main monitoring loop"""
        logger.info("Starting battery monitoring...")
        
        if not self.setup_hardware():
            logger.error("Hardware setup failed")
            return False
        
        if not self.setup_mqtt():
            logger.error("MQTT setup failed")
            return False
        
        self.running = True
        sample_interval = CONFIG["sensors"]["sample_interval"]
        publish_interval = CONFIG["sensors"]["publish_interval"]
        
        logger.info(f"Monitoring started - sampling every {sample_interval}s, publishing every {publish_interval}s")
        
        try:
            while self.running:
                current_time = time.time()
                
                # Read voltage
                voltage = self.read_voltage()
                if voltage is not None:
                    self.voltage_readings.append(voltage)
                    
                    # Keep only recent readings
                    max_readings = int(publish_interval / sample_interval)
                    if len(self.voltage_readings) > max_readings:
                        self.voltage_readings = self.voltage_readings[-max_readings:]
                    
                    # Publish if it's time
                    if current_time - self.last_publish >= publish_interval:
                        # Use average of recent readings for stability
                        avg_voltage = sum(self.voltage_readings) / len(self.voltage_readings)
                        self.publish_sensor_data(avg_voltage)
                        self.last_publish = current_time
                
                time.sleep(sample_interval)
                
        except KeyboardInterrupt:
            logger.info("Monitoring stopped by user")
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
        logger.info("Cleanup completed")

def signal_handler(sig, frame):
    """Handle Ctrl+C gracefully"""
    logger.info("Received interrupt signal")
    sys.exit(0)

def main():
    # Set up signal handler for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    
    logger.info("IoT E-Waste Battery Monitor starting...")
    logger.info(f"Configuration: {json.dumps(CONFIG, indent=2)}")
    
    monitor = BatteryMonitor()
    
    try:
        success = monitor.run()
        if not success:
            sys.exit(1)
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
