# sht3x-spin
--------------

This is a P8X32A/Propeller driver object for Sensirion's SHT3x (30, 31, 35) line of combination temperature and relative humidity sensors.

## Salient Features

* I2C connection (tested up to 400kHz)
* Support for optional alternate slave address (untested)
* Verifies received CRC of data against calculated CRC for data integrity
* Supports both one-shot (with clock-stretching) as well as periodic measurement modes of the sensor
* Supports all three measurement repeatability modes
* Supports toggling the on-chip heating element
* Supports reading the sensor's serial number
* Supports setting alert thresholds

## TODO
* Massive code cleanup

