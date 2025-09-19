#!/usr/bin/env python3
"""
Simple ADS1115 test script
Use this to verify your hardware is working before running the full monitor
"""

import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn

# Configuration
VOLTAGE_DIVIDER_RATIO = 11.0  # Adjust based on your voltage divider
CHANNEL = 0  # ADS1115 channel (0-3)

def main():
    print("ADS1115 Voltage Test")
    print("===================")
    
    try:
        # Initialize I2C and ADS1115
        i2c = busio.I2C(board.SCL, board.SDA)
        ads = ADS.ADS1115(i2c)
        chan = AnalogIn(ads, getattr(ADS, f'P{CHANNEL}'))
        
        print(f"Reading from channel {CHANNEL}")
        print(f"Voltage divider ratio: {VOLTAGE_DIVIDER_RATIO}")
        print("Press Ctrl+C to stop\n")
        
        while True:
            # Read raw voltage
            raw_voltage = chan.voltage
            
            # Calculate actual voltage
            actual_voltage = raw_voltage * VOLTAGE_DIVIDER_RATIO
            
            print(f"Raw: {raw_voltage:.3f}V  ->  Actual: {actual_voltage:.2f}V")
            
            time.sleep(1)
            
    except KeyboardInterrupt:
        print("\nTest stopped")
    except Exception as e:
        print(f"Error: {e}")
        print("\nTroubleshooting:")
        print("1. Check I2C is enabled: sudo raspi-config")
        print("2. Check wiring connections")
        print("3. Scan I2C bus: sudo i2cdetect -y 1")

if __name__ == "__main__":
    main()
