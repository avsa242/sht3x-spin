# sht3x-spin
------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for Sensirion's SHT3x (30, 31, 35) line of combination temperature and relative humidity sensors.

## Salient Features

* I2C connection up to 1MHz (Propeller 2/spin2 TBD)
* Supports one-shot (without clock-stretching) measurement mode
* Supports all three measurement repeatability modes
* Supports toggling the on-chip heating element
* Supports reading the sensor's serial number
* Supports alternate slave address
* Supports periodic measurement mode
* Supports settings alert thresholds

## Requirements

* 1 extra core/cog for the PASM I2C driver (n/a for P2 - I2C runs in same cog)

## Compiler compatibility

- [x] OpenSpin (tested with 1.00.81)
- [x] FastSpin (when generating P2 only; tested with 4.0.3-beta, rev A silicon)

## TODO
- [x] Support alert thresholds
- [x] Support alternate slave address
- [ ] Support runtime switchable CRC-checking of received data
