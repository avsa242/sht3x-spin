# sht3x-spin
------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for Sensirion's SHT3x (30, 31, 35) line of combination temperature and relative humidity sensors.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or [p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P). Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.

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

P1/SPIN1:
* spin-standard-library
* 1 extra core/cog for the PASM I2C driver

P2/SPIN2:
* p2-spin-standard-library

## Compiler Compatibility

* P1/SPIN1: OpenSpin (tested with 1.00.81)
* P2/SPIN2: FastSpin (tested with 4.2.5-beta)
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build

## TODO
- [x] Support alert thresholds
- [x] Support alternate slave address
- [ ] Calculate thresholds bsed on currently set TempScale()
- [ ] Add an interrupt-oriented demo app
- [ ] Support runtime switchable CRC-checking of received data
