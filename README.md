# sht3x-spin
------------

This is a P8X32A/Propeller driver object for Sensirion's SHT3x (30, 31, 35) line of combination temperature and relative humidity sensors.

## Salient Features

* I2C connection up to 1MHz
* Supports one-shot (without clock-stretching) measurement mode
* Supports all three measurement repeatability modes
* Supports toggling the on-chip heating element
* Supports reading the sensor's serial number
* Supports alternate slave address
* Supports periodic measurement mode

## Example Code
* Simple serial terminal-based readout demo

## TODO
- [ ] Support alert thresholds
- [x] Support alternate slave address
- [ ] Support runtime switchable CRC-checking of received data
