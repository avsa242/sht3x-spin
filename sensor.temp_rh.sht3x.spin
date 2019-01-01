{
    --------------------------------------------
    Filename: sensor.temp_rh.sht3x.spin
    Author: Jesse Burt
    Description: Driver for Sensirion's SHT3X Temperature/RH Sensors
    Copyright (c) 2019
    Started Nov 19, 2017
    Updated Jan 1, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON
'' I2C Defaults
    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR|1

    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = core#I2C_DEF_FREQ

    LOW             = 0
    MED             = 1
    HIGH            = 2

    MSB             = 1
    LSB             = 0
    POLYNOMIAL      = $31

OBJ

    core  : "core.con.sht3x"
    time  : "time"
    i2c   : "jm_i2c_fast"

VAR

    byte _i2c_cog
    byte _scale
    word _temp_word
    word _rh_word
    byte _repeatability_mode
    byte _addr_bit
  
PUB Null
'This is not a top-level object

PUB Start(ADDR_BIT): okay
' Default to "standard" Propeller I2C pins and 400kHz
' ADDR_BIT
'   0 - Default Slave address
'   1 - Optional alternate Slave address
    okay := Startx (DEF_SCL, DEF_SDA, DEF_HZ, ADDR_BIT)

PUB Startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BIT): okay
' ADDR_BIT
'   0 - Default Slave address
'   1 - Optional alternate Slave address

    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31)
        if I2C_HZ =< core#I2C_MAX_FREQ
            if okay := i2c.setupx (SCL_PIN, SDA_PIN, I2C_HZ)    'I2C Object Started?
                time.MSleep (1)
            case ADDR_BIT
                1: _addr_bit := 1 << 1
                0: _addr_bit := 0
                OTHER:
                    return FALSE

            if i2c.present (SLAVE_WR | _addr_bit)               'Response from device?
                _scale := 100 <# 100                            'Scale fixed-point math up by this factor
                return okay

    return FALSE                                                'If we got here, something went wrong

PUB Stop

    i2c.terminate

PUB Alert
'Get Alert status
'   FALSE   - No alerts
'   TRUE    - At least one alert pending
    return ((readReg_STATUS >> core#SHT3X_STATUS_ALERT) & %1) * TRUE

PUB Alert_RH
'RH Tracking Alert
'   FALSE   - No alert
'   TRUE    - Alert
    return ((readReg_STATUS >> core#SHT3X_STATUS_RHALERT) & %1) * TRUE

PUB Alert_Temp
'Temp Tracking Alert
' FALSE   - No alert
' TRUE    - Alert
    return ((readReg_STATUS >> core#SHT3X_STATUS_TEMPALERT) & %1) * TRUE

PUB Break
'Stop Periodic Data Acquisition Mode
' Use this when you wish to return to One-shot mode from Periodic Mode
    writeRegX(core#SHT3X_BREAK_STOP, 0, 0)

PUB ClearStatus
'Clears bits 15, 11, 10, and 4 in the status register
    writeRegX(core#SHT3X_CLEARSTATUS, 0, 0)

PUB FetchData | read_data[2], ms_word, ms_crc, ls_word, ls_crc
'Get Temperature and RH data when sensor is in Periodic mode
'   Returns temperature in upper word, RH in lower word
'To stop Periodic mode and return to One-shot mode, call the Break method,
' then proceed with your one-shot mode calls.
    if readRegX(core#SHT3X_FETCHDATA, 6, @read_data)    'If readRegX returned -1, then
        return                                          ' no data was available - do nothing.
    _temp_word := (read_data.byte[0] << 8) | read_data.byte[1]
    _rh_word := (read_data.byte[3] << 8) | read_data.byte[4]
    return (_temp_word << 16) | (_rh_word)

PUB GetHeaterStatus
'Get Heater status
'   Returns
'       FALSE   - OFF
'       TRUE    - ON
    return ((readReg_STATUS >> core#SHT3X_STATUS_HEATER) & %1) * TRUE

PUB GetRH
'Return Calculated Relative Humidity in hundreths of a percent
'   e.g., 32.15% would return 3215
    return (100 * (_rh_word * _scale)) / 65535

PUB GetRH_Raw
'Return Humidity as a 16-bit word
    return _rh_word & $FFFF

PUB GetTempC
'Return Calculated temperature in hundredths of a degree Celsius
'   e.g., 21.05C would return 2105
    return ((175 * (_temp_word * _scale)) / 65535)-(45 * _scale)

PUB GetTempF
'Return Calculated temperature in hundredths of a degree Fahrenheit
'   e.g., 70.05C would return 7005
    return ((315 * (_temp_word * _scale)) / 65535)-(49 * _scale)

PUB GetTemp_Raw
'Return uncalculated Temperature as a 16-bit word
    return _temp_word & $FFFF

PUB ReadTempRH | read_data[2], repeatability
'Get Temperature and RH data from sensor (one-shot mode)
' with repeatability level LOW, MED, HIGH
'Returns temperature in high word, RH in low word
    case _repeatability_mode
        LOW:
            repeatability := core#SHT3X_MEAS_LOWREP_STRETCH
        MED:
            repeatability := core#SHT3X_MEAS_MEDREP_STRETCH
        HIGH:
            repeatability := core#SHT3X_MEAS_HIGHREP_STRETCH
        OTHER:
            return

    readRegX(repeatability, 6, @read_data)
    _temp_word := (read_data.byte[0] << 8) | read_data.byte[1]
    _rh_word := (read_data.byte[3] << 8) | read_data.byte[4]
    return (_temp_word << 16) | (_rh_word)

PUB GetAlertTrig_High | read_crc, read_data
'Returns High Alarm threshold trigger settings
'   Upper 7 bits - Humidity limit
'   Lower 9 bits - Temperature limit (deg C)
    readRegX(core#SHT3X_ALERTLIM_RD_HI_SET, 3, @read_data)
    read_crc := read_data.byte[2]
    result := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

    if crcgood(@result, read_crc)
        return result
    else
        return $DEADBEEF

PUB GetAlertTrig_HighRH
'Returns RH High Alarm threshold trigger settings as
'   7-bit value in MSB
    return GetAlertTrig_High & $FE00

PUB GetAlertTrig_HighTemp
'Returns Temperature High Alarm threshold trigger settings as
'   9-bit value in LSB
    return (GetAlertTrig_High & $1FF)

PUB GetAlertOk_High | read_crc, read_data
'Returns High Alarm threshold clear settings
'   Upper 7 bits - Humidity limit
'   Lower 9 bits - Temperature limit (deg C)
    readRegX(core#SHT3X_ALERTLIM_RD_HI_CLR, 3, @read_data)
    read_crc := read_data.byte[2]
    result := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

    if crcgood(@result, read_crc)
        return result
    else
        return FALSE

PUB GetAlertOk_HighRH
'Returns RH High Alarm threshold clear settings as
'   7-bit value in MSB
    return GetAlertOk_High & $FE00

PUB GetAlertOk_HighTemp
'Returns Temperature High Alarm threshold clear settings as
'   9-bit value in LSB
    return GetAlertOk_High & $1FF

PUB GetAlertOk_Low | read_crc, read_data
'Returns Low Alarm threshold clear settings
'   Upper 7 bits - Humidity limit
'   Lower 9 bits - Temperature limit (deg C)
    readRegX(core#SHT3X_ALERTLIM_RD_LO_CLR, 3, @read_data)
    read_crc := read_data.byte[2]
    result := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

    if crcgood(@result, read_crc)
        return result
    else
        return FALSE

PUB GetAlertOk_LowRH

    return GetAlertOk_Low & $FE00

PUB GetAlertOk_LowTemp

    return GetAlertOk_Low & $1FF

PUB GetAlertTrig_Low | read_crc, read_data
'Returns Low Alarm threshold set settings
'   Upper 7 bits - Humidity limit
'   Lower 9 bits - Temperature limit (deg C)
    readRegX(core#SHT3X_ALERTLIM_RD_LO_SET, 3, @read_data)
    read_crc := read_data.byte[2]
    result := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

    if crcgood(@result, read_crc)
        return result
    else
        return FALSE

PUB GetAlertTrig_LowRH

    return GetAlertTrig_Low & $FE00

PUB GetAlertTrig_LowTemp

    return GetAlertTrig_Low & $1FF

PUB SerialNum | read_data[2], ms_word, ls_word, ms_crc, ls_crc
'Read 32bit serial number from SHT3x (*not found in datasheet)
    readRegX(core#SHT3X_READ_SERIALNUM, 6, @read_data)
    ms_word := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF
    ms_crc := read_data.byte[2]
    ls_word := ((read_data.byte[3] << 8) | read_data.byte[4]) & $FFFF
    ls_crc := read_data.byte[5]

    if crcgood(@ms_word, ms_crc) AND crcgood(@ls_word, ls_crc)
        return (ms_word << 16) | ls_word
    else
        return FALSE                                    'Return implausible value if CRC check failed

PUB SetAlerts(rh_trig_hi, rh_ok_hi, rh_ok_lo, rh_trig_lo, temp_trig_hi, temp_ok_hi, temp_ok_lo, temp_trig_lo)
' Set all alert thresholds at once
    SetAlertTrig_Hi (rh_trig_hi, temp_trig_hi)
    SetAlertOk_Hi (rh_ok_hi, temp_ok_hi)
    SetAlertOk_Lo (rh_ok_lo, temp_ok_lo)
    SetAlertTrig_Lo (rh_trig_lo, temp_trig_lo)

PUB SetAlertTrig_Hi(rh_set, temp_set) | rht, tt, crct, tmp, write_data
' Set high alarm trigger threshold for RH and Temp
    rht := RHPct_Raw7 (rh_set)
    tt := TempDeg_Raw9 (temp_set)
    tmp := (rht | tt)
    crct := crc8(@tmp, 2)
    write_data.byte[0] := tmp.byte[1]
    write_data.byte[1] := tmp.byte[0]
    write_data.byte[2] := crct

    writeRegX(core#SHT3X_ALERTLIM_WR_HI_SET, 3, write_data)

PUB SetAlertOk_Hi(rh_clr, temp_clr) | rht, tt, write_data, crct, tmp
' Set high alarm clear threshold for RH and Temp
    rht := RHPct_Raw7 (rh_clr)
    tt := TempDeg_Raw9 (temp_clr)
    tmp := (rht | tt)
    crct := crc8(@tmp, 2)
    write_data.byte[0] := (tmp >> 8) & $FF
    write_data.byte[1] := tmp & $FF
    write_data.byte[2] := crct

    writeRegX(core#SHT3X_ALERTLIM_WR_HI_CLR, 3, write_data)

PUB SetAlertOk_Lo(rh_clr, temp_clr) | rht, tt, write_data, crct, tmp
' Set low alarm clear threshold for RH and Temp
    rht := RHPct_Raw7 (rh_clr)
    tt := TempDeg_Raw9 (temp_clr)
    tmp := (rht | tt)
    crct := crc8(@tmp, 2)
    write_data.byte[0] := (tmp >> 8) & $FF
    write_data.byte[1] := tmp & $FF
    write_data.byte[2] := crct

    writeRegX(core#SHT3X_ALERTLIM_WR_LO_CLR, 3, write_data)

PUB SetAlertTrig_Lo(rh_set, temp_set) | rht, tt, write_data, crct, tmp
' Set low alarm trigger threshold for RH and Temp
    rht := RHPct_Raw7 (rh_set)
    tt := TempDeg_Raw9 (temp_set)
    tmp := (rht | tt)
    crct := crc8(@tmp, 2)
    write_data.byte[0] := (tmp >> 8) & $FF
    write_data.byte[1] := tmp & $FF
    write_data.byte[2] := crct

    writeRegX(core#SHT3X_ALERTLIM_WR_LO_SET, 3, write_data)

PUB EnableHeater(enabled)
'Enable/Disable built-in heater
'(per SHT3x datasheet, it is for plausability checking only)
    case ||enabled
        0, 1:
            enabled := lookupz(||enabled: core#SHT3X_HEATERDIS, core#SHT3X_HEATEREN)
        OTHER:
            return
    writeRegX(enabled, 0, 0)

PUB ResetDetected
'Check for System Reset
'   Returns
'      FALSE   - No reset since last 'clear status register'
'       TRUE    - reset detected (hard reset, soft reset, power fail)
    return ((readReg_STATUS >> core#SHT3X_STATUS_RESET) & %1) * TRUE

PUB SetPeriodicRead(meas_per_sec) | cmdword, mps, repeatability
'Sets number of measurements per second the sensor should take
'   in Periodic Measurement mode.
'To stop Periodic mode and return to One-shot mode, call the Break method,
'   then proceed with your one-shot mode calls.
'NOTE: This mode is required in order to use the sensor's built-in
'   threshold alarms. They do not work with one-shot readings.
'*** Sensirion notes in their datasheet that at 10mps with repeatability set High,
'***  self-heating of the sensor might occur.
    case meas_per_sec
        0, 5, 0.5:
            mps := $20
            repeatability := lookupz(_repeatability_mode: $2F, $24, $32)
        1:
            mps := $21
            repeatability := lookupz(_repeatability_mode: $2D, $26, $30)
        2:
            mps := $22
            repeatability := lookupz(_repeatability_mode: $2B, $20, $36)
        4:
            mps := $23
            repeatability := lookupz(_repeatability_mode: $29, $22, $34)
        10:
            mps := $27
            repeatability := lookupz(_repeatability_mode: $2A, $21, $37)
        OTHER:
            mps := $23
            repeatability := lookupz(_repeatability_mode: $29, $22, $34)

    ifnot repeatability
        return $DEADBEEF
    Break                                             'Stop any measurements that might be ongoing
    cmdword := (mps << 8) | repeatability
    writeRegX(cmdword, 2, 0)'XXX nr_bytes should be 0, but this doesn't work??
    return repeatability

PUB SetRepeatability(mode)'XXX doesn't commit mode in periodic
'Sets repeatability mode for subsequent temperature/RH measurements taken
' using either One-shot or Periodic mode
    case mode
        LOW:    _repeatability_mode := LOW
        MED:    _repeatability_mode := MED
        HIGH:   _repeatability_mode := HIGH
        OTHER:  _repeatability_mode := LOW              'Default to least energy-consuming/least self-heating mode

PUB SoftReset
'Perform Soft Reset. Bit 4 of status register should subsequently read 1
    writeRegX(core#SHT3X_SOFTRESET, 0, 0)
    time.MSleep (1)

PUB RHPct_Raw7(rh_pct)
'Converts Percent RH to 7-bit value (in MSB of word)
'   Intended for use with alert threshold settings
    case rh_pct
        0..100:
            return (((rh_pct * _scale) / 100 * 65535) / _scale) & $FE00
        OTHER:
            return

PUB RHRaw7_Pct(rh_raw)
'Converts 7-bit value (in MSB of word) to Percent RH
'   Intended for use with alert threshold settings
    return ((100 * ((rh_raw & $FE00) * _scale)) / 65535) '+ 32 { + error }

PUB TempDeg_Raw9(temp_c)
'Converts degrees C to 9-bit value
'   Intended for use with alert threshold settings
    result := (((( (temp_c) * _scale) + (45 * _scale)) / 175 * 65535) / _scale) '+ 384 { + error }
    return (result >> 7) & $001FF

PUB TempRaw9_Deg(temp_raw)
'Converts raw 9-bit value to temperature in
'   hundredths of a degree C (0..511 -> -4500..12966 or -45.00C 129.66C)
'   Out of range values are ignored
    case temp_raw
        0..511:
            result := (temp_raw << 7)
            return ((175 * (result * _scale)) / 65535)-(45 * _scale)
        OTHER:
            return

PRI readReg_STATUS| read_data, status_crc
'Read SHT3x status register
    readRegX(core#SHT3X_READSTATUS, 3, @read_data)
    result := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF
    status_crc := read_data.byte[2]
    if crcgood(@result, status_crc)
        return result
    else
        return $53EC                                    'Return invalid value if CRC check failed
                                                        '(sets all 'Reserved' bits, which should normally be 0)
PRI lastCRCStatus
'Write data checksum status
'   Returns
'       FALSE   - Checksum of last transfer was correct
'       TRUE    - Checksum of last transfer write failed
    return (readReg_STATUS & %1) * TRUE

PRI cmdStatus
'Command status
'   Returns
'       FALSE   - Last command executed successfully
'       TRUE    - Last command not processed. Invalid or failed integrated checksum
    return ((readReg_STATUS >> core#SHT3X_STATUS_CMDSTAT) & %1) * TRUE

PRI readRegX(reg, nr_bytes, addr_buff) | cmd_packet[2], ackbit
'Read nr_bytes from register 'reg' to address 'addr_buff'
    cmd_packet.byte[0] := SLAVE_WR | _addr_bit
    cmd_packet.byte[1] := reg.byte[MSB]                 'Register MSB
    cmd_packet.byte[2] := reg.byte[LSB]                 'Register LSB

    i2c.start
    ackbit := i2c.pwrite (@cmd_packet, 3)
    if ackbit == i2c#NAK
        i2c.stop
        return

'Some registers have quirky behavior - handle it on a case-by-case basis
    case reg
        core#SHT3X_READ_SERIALNUM:                      'S/N Read Needs delay before repeated start
            time.USleep (500)
            i2c.start
            ackbit := i2c.write (SLAVE_RD | _addr_bit)
        core#SHT3X_MEAS_HIGHREP_STRETCH..core#SHT3X_MEAS_LOWREP_STRETCH:
            i2c.stop                                    ' Measurements with clock-stretching don't
            i2c.start                                   ' seem to work without this STOP condition
            ackbit := i2c.write (SLAVE_RD | _addr_bit)
            i2c.stop
        OTHER:
            i2c.start
            ackbit := i2c.write (SLAVE_RD | _addr_bit)

    if ackbit == i2c#NAK
        i2c.stop                                        'No data was available,
        return -1                                       ' so do nothing

    i2c.pread (addr_buff, nr_bytes, TRUE)
    i2c.stop

PRI writeRegX(reg, nr_bytes, val) | cmd_packet[2]
' Write nr_bytes to register 'reg' stored in val
' If nr_bytes is
'   0, It's a command that has no arguments - write the command only
'   1, It's a command with a single byte argument - write the command, then the byte
'   2, It's a command with two arguments - write the command, then the two bytes (encoded as a word)
'   3, It's a command with two arguments and a CRC - write the command, then the two bytes (encoded as a word), lastly the CRC
    cmd_packet.byte[0] := SLAVE_WR | _addr_bit

    case nr_bytes
        0:
            cmd_packet.byte[1] := reg.byte[MSB]       'Simple command
            cmd_packet.byte[2] := reg.byte[LSB]
        1:
            cmd_packet.byte[1] := reg.byte[MSB]       'Command w/1-byte argument
            cmd_packet.byte[2] := reg.byte[LSB]
            cmd_packet.byte[3] := val
        2:
            cmd_packet.byte[1] := reg.byte[MSB]       'Command w/2-byte argument
            cmd_packet.byte[2] := reg.byte[LSB]
            cmd_packet.byte[3] := val.byte[0]
            cmd_packet.byte[4] := val.byte[1]
        3:
            cmd_packet.byte[1] := reg.byte[MSB]       'Command w/2-byte argument and CRC
            cmd_packet.byte[2] := reg.byte[LSB]
            cmd_packet.byte[3] := val.byte[0]
            cmd_packet.byte[4] := val.byte[1]
            cmd_packet.byte[5] := val.byte[2]
        OTHER:
            return

    i2c.start
    i2c.pwrite (@cmd_packet, 3 + nr_bytes)
    i2c.stop

PRI compare(b1, b2)
'Compare b1 to b2
'   Returns TRUE if equal
    return b1 == b2

PRI crcgood(calc_crc, rcvd_crc)

    return crc8(calc_crc, 2) == rcvd_crc

PRI crc8(data, len) | currbyte, i, j, crc
'Calculate CRC8 of data with length 'len' bytes at address 'data'
'   Datasheet example of $BEEF should return $92
    crc := $FF                                      'Initialize CRC with $FF
    repeat j from 0 to len-1
        currbyte := byte[data][(len-1)-j]
        crc := crc ^ currbyte

        repeat i from 1 to 8
            if (crc & $80)
                crc := (crc << 1) ^ POLYNOMIAL      '$31 (x^8 + x^5 + x^4 + 1)
            else
                crc := (crc << 1)
    crc := crc ^ $00                                'Final XOR
    result := crc & $FF                             '

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
