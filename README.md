This is a Parallax P8X32A/Propeller MCU driver for Sensirion's SHT3x-series (-DIS, or digital) combination Temperature/Humidity sensors.

The sensor communicates over I2C at up to 1MHz, although I've only had success at up to about 530kHz (using a Propeller Board of Education).

Features/notes/limitations:
* An interactive (serial terminal-based) demo is included that can be used to continually read data from the sensor, check for temp or RH alerts, the status register, the unique serial number of the die
* Uses 1 extra core for the PASM I2C driver, although I believe the equivalent SPIN version, which wouldn't need an additional core, would work just fine. It'd just be limited to slower I2C bus speeds. I may test this in the future, but for now it's untested.
* Uses fixed-point math for conversion routines, and returns temperature and RH in hundredths. The user is expected to perform formatting of the scaled-up values as they see fit (e.g., the float math libraries could be used if deemed necessary. A simple decimal-dot notation method is included in the Demo for the purposes of displaying the values)
* Should work with SHT30 and 35 devices as well. This is untested, as I only have a module based on the SHT31.
