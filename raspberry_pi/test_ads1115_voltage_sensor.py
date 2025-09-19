#!/usr/bin/env python3
"""
ADS1115 test script for your exact hardware setup
Tests the voltage sensor module connected to ADS1115
"""

import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn

# Configuration based on your voltage sensor module
CHANNEL = 0  # ADS1115 channel A0 (where your voltage sensor S pin connects)

# Your voltage sensor module specs (from the image):
# - Input: Up to 25V DC
# - Output: 0-5V (but clamped to 3.3V for Pi safety)
# - Built-in voltage divider: 5:1 ratio typically
VOLTAGE_RATIO = 5.0  # Adjust this based on your sensor's actual ratio

def main():
    print("ADS1115 + Voltage Sensor Test")
    print("=============================")
    print("Testing your blue voltage sensor module")
    
    try:
        # Initialize I2C and ADS1115
        i2c = busio.I2C(board.SCL, board.SDA)
        ads = ADS.ADS1115(i2c)
        
        # Create analog input on channel 0 (A0)
        chan = AnalogIn(ads, ADS.P0)
        
        print(f"Reading from ADS1115 channel A{CHANNEL}")
        print(f"Voltage sensor ratio: {VOLTAGE_RATIO}:1")
        print("Connect your battery to the voltage sensor input")
        print("Press Ctrl+C to stop\n")
        
        while True:
            # Read voltage from ADS1115 (this is the voltage sensor's output)
            sensor_output = chan.voltage
            
            # Calculate actual battery voltage
            # The voltage sensor already does the division, so we multiply back
            battery_voltage = sensor_output * VOLTAGE_RATIO
            
            print(f"Sensor output: {sensor_output:.3f}V  ->  Battery: {battery_voltage:.2f}V")
            
            # Battery status indication
            if battery_voltage > 12.6:
                status = "CHARGED"
            elif battery_voltage > 12.0:
                status = "GOOD"
            elif battery_voltage > 11.5:
                status = "LOW"
            else:
                status = "CRITICAL"
            
            print(f"Status: {status}")
            print("-" * 40)
            
            time.sleep(2)
            
    except KeyboardInterrupt:
        print("\nTest stopped")
    except Exception as e:
        print(f"Error: {e}")
        print("\nTroubleshooting:")
        print("1. Check I2C is enabled: sudo raspi-config -> Interface Options -> I2C")
        print("2. Check ADS1115 wiring:")
        print("   VDD -> Pi 3.3V")
        print("   GND -> Pi GND") 
        print("   SCL -> Pi SCL (GPIO 3)")
        print("   SDA -> Pi SDA (GPIO 2)")
        print("3. Check voltage sensor wiring:")
        print("   VCC -> Pi 5V or 3.3V")
        print("   GND -> Pi GND")
        print("   S -> ADS1115 A0")
        print("4. Check I2C devices: sudo i2cdetect -y 1")
        print("5. Install packages: pip3 install adafruit-circuitpython-ads1x15")

if __name__ == "__main__":
    main()
