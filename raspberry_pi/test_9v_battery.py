#!/usr/bin/env python3
"""
ADS1115 + Voltage Sensor Test with 9V Battery
Safer test using 9V battery before connecting to 12V car battery
"""

import time
import board
import busio
import adafruit_ads1x15.ads1115 as ADS
from adafruit_ads1x15.analog_in import AnalogIn

# Configuration for 9V battery testing
CHANNEL = 0  # ADS1115 channel A0 (where your voltage sensor S pin connects)

# Voltage sensor specs for 9V testing:
# - Your voltage sensor can handle up to 25V, so 9V is safe
# - Expected output: 9V ÷ 5 = ~1.8V to ADS1115
VOLTAGE_RATIO = 5.0  # Your voltage sensor's built-in ratio

def main():
    print("ADS1115 + Voltage Sensor Test (9V Battery)")
    print("==========================================")
    print("Testing with 9V battery - SAFER than 12V car battery")
    print("Expected readings: 8.5V - 9.6V for good 9V battery")
    
    try:
        # Initialize I2C and ADS1115
        i2c = busio.I2C(board.SCL, board.SDA)
        ads = ADS.ADS1115(i2c)
        
        # Create analog input on channel 0 (A0)
        chan = AnalogIn(ads, ADS.P0)
        
        print(f"Reading from ADS1115 channel A{CHANNEL}")
        print(f"Voltage sensor ratio: {VOLTAGE_RATIO}:1")
        print("Connect 9V battery to voltage sensor input (+/- terminals)")
        print("Press Ctrl+C to stop\n")
        
        reading_count = 0
        voltage_sum = 0
        
        while True:
            # Read voltage from ADS1115 (this is the voltage sensor's output)
            sensor_output = chan.voltage
            
            # Calculate actual battery voltage
            battery_voltage = sensor_output * VOLTAGE_RATIO
            
            # Track readings for average
            reading_count += 1
            voltage_sum += battery_voltage
            average_voltage = voltage_sum / reading_count
            
            print(f"Reading #{reading_count:3d}: Sensor: {sensor_output:.3f}V  →  9V Battery: {battery_voltage:.2f}V")
            print(f"                   Average so far: {average_voltage:.2f}V")
            
            # 9V Battery status indication
            if battery_voltage > 9.2:
                status = "FRESH 9V"
                color = "🟢"
            elif battery_voltage > 8.5:
                status = "GOOD 9V"
                color = "🟡"
            elif battery_voltage > 7.5:
                status = "WEAK 9V"
                color = "🟠"
            elif battery_voltage > 6.0:
                status = "LOW 9V"
                color = "🔴"
            else:
                status = "DEAD 9V or NO CONNECTION"
                color = "❌"
            
            print(f"                   Status: {color} {status}")
            
            # Expected values for troubleshooting
            expected_sensor_output = battery_voltage / VOLTAGE_RATIO
            print(f"                   Expected sensor output: ~{expected_sensor_output:.3f}V")
            print("-" * 60)
            
            time.sleep(2)
            
    except KeyboardInterrupt:
        print(f"\nTest stopped after {reading_count} readings")
        if reading_count > 0:
            print(f"Final average: {voltage_sum / reading_count:.2f}V")
        print("\nIf readings look good, your setup is working!")
        print("You can now try with 12V car battery.")
        
    except Exception as e:
        print(f"Error: {e}")
        print("\nTroubleshooting for 9V test:")
        print("1. Check I2C is enabled: sudo raspi-config -> Interface Options -> I2C")
        print("2. Check ADS1115 wiring:")
        print("   VDD -> Pi 3.3V (Pin 1)")
        print("   GND -> Pi GND (Pin 6)")
        print("   SCL -> Pi SCL (Pin 5, GPIO 3)")
        print("   SDA -> Pi SDA (Pin 3, GPIO 2)")
        print("3. Check voltage sensor wiring:")
        print("   VCC -> Pi 3.3V (shared with ADS1115)")
        print("   GND -> Pi GND (shared with ADS1115)")
        print("   S -> ADS1115 A0")
        print("   + -> 9V battery positive")
        print("   - -> 9V battery negative")
        print("4. Check I2C devices: sudo i2cdetect -y 1")
        print("5. Try different 9V battery")
        print("6. Measure 9V battery with multimeter first")
        
        print("\nExpected values for working 9V battery:")
        print("- Fresh 9V battery: 9.2V - 9.6V")
        print("- Good 9V battery: 8.5V - 9.2V")
        print("- Sensor output should be: battery_voltage ÷ 5")
        print("- Example: 9.0V battery → ~1.8V sensor output")

if __name__ == "__main__":
    main()
