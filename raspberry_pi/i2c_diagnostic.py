#!/usr/bin/env python3
"""
I2C diagnostic script for ADS1115 troubleshooting
"""

import time
import subprocess
import sys

def run_command(cmd):
    """Run a shell command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except Exception as e:
        return "", str(e), 1

def check_i2c_enabled():
    """Check if I2C is enabled"""
    print("1. Checking I2C status...")
    
    # Check if i2c devices exist
    stdout, stderr, code = run_command("ls /dev/i2c*")
    if code == 0:
        print(f"✓ I2C devices found: {stdout}")
    else:
        print("✗ No I2C devices found")
        print("Run: sudo raspi-config -> Interface Options -> I2C -> Enable")
        return False
    
    # Check kernel modules
    stdout, stderr, code = run_command("lsmod | grep i2c")
    if "i2c_bcm2835" in stdout:
        print("✓ I2C kernel modules loaded")
    else:
        print("✗ I2C kernel modules not loaded")
        return False
    
    return True

def scan_i2c_devices():
    """Scan for I2C devices"""
    print("\n2. Scanning I2C bus...")
    
    stdout, stderr, code = run_command("sudo i2cdetect -y 1")
    if code == 0:
        print("I2C scan results:")
        print(stdout)
        
        # Check for common ADS1115 addresses
        if "48" in stdout:
            print("✓ Found device at 0x48 (likely ADS1115)")
            return True
        elif "49" in stdout:
            print("✓ Found device at 0x49 (ADS1115 with ADDR connected)")
            return True
        else:
            print("✗ No ADS1115 found at expected addresses (0x48-0x4B)")
            return False
    else:
        print(f"✗ I2C scan failed: {stderr}")
        return False

def test_gpio_pins():
    """Test GPIO pin states"""
    print("\n3. Checking GPIO pins...")
    
    # Check if GPIO pins are in correct mode
    stdout, stderr, code = run_command("gpio readall")
    if code == 0:
        print("GPIO pin states:")
        lines = stdout.split('\n')
        for line in lines:
            if 'SDA' in line or 'SCL' in line:
                print(line)
    else:
        print("gpio command not available (install with: sudo apt install wiringpi)")

def test_python_imports():
    """Test if required Python packages are installed"""
    print("\n4. Testing Python imports...")
    
    try:
        import board
        print("✓ board module imported")
    except ImportError:
        print("✗ board module missing")
        print("Install with: pip3 install adafruit-blinka")
    
    try:
        import busio
        print("✓ busio module imported")
    except ImportError:
        print("✗ busio module missing")
        print("Install with: pip3 install adafruit-blinka")
    
    try:
        import adafruit_ads1x15.ads1115 as ADS
        print("✓ ADS1115 library imported")
    except ImportError:
        print("✗ ADS1115 library missing")
        print("Install with: pip3 install adafruit-circuitpython-ads1x15")

def main():
    print("ADS1115 I2C Diagnostic Tool")
    print("============================")
    
    # Run all checks
    i2c_ok = check_i2c_enabled()
    if not i2c_ok:
        print("\n❌ I2C is not properly enabled. Fix this first.")
        return
    
    device_found = scan_i2c_devices()
    if not device_found:
        print("\n❌ ADS1115 not found on I2C bus.")
        print("\nCheck your wiring:")
        print("- ADS1115 VDD → Pi Pin 1 (3.3V)")
        print("- ADS1115 GND → Pi Pin 6 (GND)")
        print("- ADS1115 SCL → Pi Pin 5 (GPIO 3)")
        print("- ADS1115 SDA → Pi Pin 3 (GPIO 2)")
        return
    
    test_gpio_pins()
    test_python_imports()
    
    if device_found:
        print("\n✅ ADS1115 detected! Your hardware setup looks good.")
        print("Try running the test script again.")

if __name__ == "__main__":
    main()
