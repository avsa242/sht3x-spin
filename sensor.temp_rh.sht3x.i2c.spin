{
    --------------------------------------------
    Filename: sensor.temp_rh.sht3x.i2c.spin
    Author: Jesse Burt
    Description: Driver for Sensirion SHT3x series Temperature/Relative Humidity sensors
    Copyright (c) 2019
    Started Nov 19, 2017
    Updated Jun 7, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 400_000
    I2C_MAX_FREQ    = core#I2C_MAX_FREQ

    MSB             = 1
    LSB             = 0

' Measurement repeatability
    RPT_LOW         = 0
    RPT_MED         = 1
    RPT_HIGH        = 2

VAR

    word _lasttemp, _lastrh
    byte _repeatability
    byte _addr_bit

OBJ

    i2c : "com.i2c"
    core: "core.con.sht3x"
    time: "time"

PUB Null
' This is not a top-level object

PUB Start: okay                                                 'Default to "standard" Propeller I2C pins and 400kHz

    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ, 0)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BIT): okay

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)    'I2C Object Started?
                time.MSleep (1)
                case ADDR_BIT
                    0:
                        _addr_bit := 0
                    OTHER:
                        _addr_bit := 1 << 1
                if i2c.present (SLAVE_WR | _addr_bit)           'Response from device?
                    if SerialNum
                        Reset
                        return okay

    return FALSE                                                'If we got here, something went wrong

PUB Stop

    i2c.terminate

PUB ClearStatus
' Clears the status register
    writeReg(core#CLEARSTATUS, 0, 0)

PUB Heater(enabled) | tmp
' Enable/Disable built-in heater
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per SHT3x datasheet, this is for plausability checking only
    tmp := 0
    readReg(core#STATUS, 3, @tmp)
    tmp >>= 8

    case ||enabled
        0, 1:
            enabled := lookupz(||enabled: core#HEATERDIS, core#HEATEREN)
        OTHER:
            return result := ((tmp >> core#FLD_HEATER) & %1) * TRUE
    writeReg(enabled, 0, 0)

PUB Humidity
' Return Relative Humidity from last measurement, in hundredths of a percent
'   (e.g., 4762 is equivalent to 47.62%)
    return (100 * (_lastrh * 100)) / 65535

PUB Measure | tmp[2]
' Perform measurement
'   Returns: Temperature and Humidity as most-significant and least-significant words, respectively (unprocessed)
'   Also sets variables readable with Temperature and Humidity methods
    case _repeatability
        RPT_LOW, RPT_MED, RPT_HIGH:
            readReg(lookupz(_repeatability: core#MEAS_LOWREP, core#MEAS_MEDREP, core#MEAS_HIGHREP), 6, @tmp)
        OTHER:
            return

    _lasttemp := (tmp.byte[5] << 8) | tmp.byte[4]
    _lastrh := (tmp.byte[2] << 8) | tmp.byte[1]
    return (_lasttemp << 16) | (_lastrh)

PUB Repeatability(level) | tmp
' Set measurement repeatability/stability
'   Valid values: RPT_LOW (0), RPT_MED (1), RPT_HIGH (2)
'   Any other value returns the current setting
    case level
        RPT_LOW, RPT_MED, RPT_HIGH:
            _repeatability := level
        OTHER:
            return _repeatability

PUB TemperatureC
' Return Temperature from last measurement, in hundredths of a degree Celsius
'   (e.g., 2105 is equivalent to 21.05 deg C)
    return ((175 * (_lasttemp * 100)) / 65535)-(45 * 100)

PUB TemperatureF
' Return Temperature from last measurement, in hundredths of a degree Fahrenheit
'   (e.g., 6989 is equivalent to 69.89 deg F)
    return ((315 * (_lasttemp * 100)) / 65535)-(49 * 100)

PUB SerialNum
' Return device Serial Number
    readReg(core#READ_SERIALNUM, 4, @result)

PUB Reset
' Perform Soft Reset
    writeReg(core#SOFTRESET, 0, 0)
    time.MSleep (1)

PRI readReg(reg, nr_bytes, buff_addr) | cmd_packet, tmp
' Read nr_bytes from the slave device into the address stored in buff_addr
    writeReg(reg, 0, 0)
    case reg                                                    'Basic register validation
        core#READ_SERIALNUM:                                    'S/N Read Needs delay before repeated start
            time.USleep (500)
        core#MEAS_HIGHREP..core#MEAS_LOWREP:
        core#STATUS:
        OTHER:
            return

    i2c.start
    i2c.write (SLAVE_RD | _addr_bit)
    repeat tmp from 0 to nr_bytes-1
        byte[buff_addr][(nr_bytes-1)-tmp] := i2c.read (tmp == nr_bytes-1)
    i2c.stop
    return

PRI writeReg(reg, nr_bytes, buff_addr) | cmd_packet, tmp
' Write nr_bytes to the slave device from the address stored in buff_addr
    cmd_packet.byte[0] := (SLAVE_WR | _addr_bit)
    cmd_packet.byte[1] := reg.byte[MSB]
    cmd_packet.byte[2] := reg.byte[LSB]

    i2c.start
    repeat tmp from 0 to 2
        i2c.write (cmd_packet.byte[tmp])
    i2c.stop

    case reg                                                    'Basic register validation
        core#CLEARSTATUS:
        core#HEATEREN, core#HEATERDIS:
        core#MEAS_HIGHREP..core#MEAS_LOWREP:
            time.MSleep (20)
        core#SOFTRESET:
            time.MSleep (10)
        OTHER:
            return

    return

DAT
{
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}
