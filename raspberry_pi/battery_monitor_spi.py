#!/usr/bin/env python3
"""
Battery Monitor using MCP3008 SPI ADC
Alternative version for when I2C is not available
"""

import time
import json
import logging
from datetime import datetime
from typing import Optional, Dict, Any
import signal
import sys

try:
    import spidev
    import paho.mqtt.client as mqtt
except ImportError as e:
    print(f"Missing required packages. Install with:")
    print("pip3 install spidev paho-mqtt")
    print(f"Error: {e}")
    sys.exit(1)

# Configuration
CONFIG = {
    "mqtt": {
        "broker": "localhost",  # Change to your MQTT broker IP
        "port": 1883,
        "username": None,  # Set if your broker requires auth
        "password": None,
        "keepalive": 60
    },
    "car": {
        "car_id": "car_1",  # Match your Flutter app's car ID
        "device_id": "rpi_001"
    },
    "sensors": {
        "voltage_channel": 0,  # MCP3008 channel (0-7) for voltage sensor
        "voltage_divider_ratio": 11.0,  # Adjust based on your voltage divider
        "sample_interval": 5.0,  # Seconds between readings
        "publish_interval": 10.0,  # Seconds between MQTT publishes
        "spi_bus": 0,  # SPI bus number
        "spi_device": 0  # SPI device number
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

class MCP3008:
    """Simple MCP3008 SPI ADC driver"""
    def __init__(self, bus=0, device=0):
        self.spi = spidev.SpiDev()
        self.spi.open(bus, device)
        self.spi.max_speed_hz = 1000000  # 1MHz
        self.spi.mode = 0
    
    def read_channel(self, channel):
        """Read raw ADC value from channel (0-7)"""
        if channel < 0 or channel > 7:
            raise ValueError("Channel must be 0-7")
        
        # MCP3008 command format
        cmd = 0x18 | channel  # Start bit + single-ended + channel
        response = self.spi.xfer2([1, cmd << 4, 0])
        
        # Extract 10-bit value
        value = ((response[1] & 0x03) << 8) | response[2]
        return value
    
    def read_voltage(self, channel, vref=3.3):
        """Read voltage from channel with reference voltage"""
        raw_value = self.read_channel(channel)
        voltage = (raw_value * vref) / 1024.0  # 10-bit resolution
        return voltage
    
    def close(self):
        self.spi.close()

class BatteryMonitor:
    def __init__(self):
        self.running = False
        self.mqtt_client = None
        self.adc = None
        self.last_publish = 0
        self.voltage_readings = []
        
    def setup_hardware(self):
        """Initialize MCP3008 SPI ADC"""
        try:
            bus = CONFIG["sensors"]["spi_bus"]
            device = CONFIG["sensors"]["spi_device"]
            self.adc = MCP3008(bus=bus, device=device)
            
            # Test read to verify connection
            test_channel = CONFIG["sensors"]["voltage_channel"]
            test_value = self.adc.read_channel(test_channel)
            
            logger.info(f"MCP3008 initialized on SPI {bus}.{device}, test read: {test_value}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize MCP3008: {e}")
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
        """Read voltage from MCP3008"""
        try:
            channel = CONFIG["sensors"]["voltage_channel"]
            
            # Read raw voltage from ADC (0-3.3V range)
            raw_voltage = self.adc.read_voltage(channel, vref=3.3)
            
            # Apply voltage divider calculation
            actual_voltage = raw_voltage * CONFIG["sensors"]["voltage_divider_ratio"]
            
            return actual_voltage
            
        except Exception as e:
            logger.error(f"Failed to read voltage: {e}")
            return None
    
    def calculate_battery_health(self, voltage: float) -> Dict[str, Any]:
        """Calculate battery health metrics from voltage"""
        config = CONFIG["battery"]
        
        # State of Charge (SOC) estimation based on voltage
        if voltage >= config["full_charge_voltage"]:
            soc = 100.0
        elif voltage <= config["min_voltage"]:
            soc = 0.0
        else:
            # Linear interpolation between min and full charge voltage
            voltage_range = config["full_charge_voltage"] - config["min_voltage"]
            soc = ((voltage - config["min_voltage"]) / voltage_range) * 100.0
        
        # State of Health (SOH) - simplified calculation
        voltage_deviation = abs(voltage - config["nominal_voltage"])
        max_deviation = 2.0  # Maximum expected deviation
        soh = max(0, 100 - (voltage_deviation / max_deviation) * 20)
        
        # Health status
        if voltage < config["min_voltage"]:
            status = "critical"
        elif voltage < 11.8:
            status = "warning" 
        else:
            status = "healthy"
        
        return {
            "voltage": round(voltage, 2),
            "soc": round(soc, 1),
            "soh": round(soh, 1),
            "status": status,
            "timestamp": datetime.now().isoformat()
        }
    
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
        logger.info("Starting battery monitoring (SPI version)...")
        
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
        if self.adc:
            self.adc.close()
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
    
    logger.info("IoT E-Waste Battery Monitor (SPI version) starting...")
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
