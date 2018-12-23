{
    --------------------------------------------
    Filename: sensor.temp_rh.sht3x.spin
    Author: Jesse Burt
    Description: Driver for Sensirion's SHT3X Temperature/RH Sensors
    Copyright (c) 2018
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
    byte _ackbit
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

PUB Break
'Stop Periodic Data Acquisition Mode
' Use this when you wish to return to One-shot mode from Periodic Mode
    writeRegX(core#SHT3X_BREAK_STOP, 0, 0)

PUB ClearStatus
'Clears bits 15, 11, 10, and 4 in the status register
    writeRegX( core#SHT3X_CLEARSTATUS, 0, 0)

PUB FetchData: tempword_rhword | read_data[2], ms_word, ms_crc, ls_word, ls_crc
'Get Temperature and RH data when sensor is in Periodic mode
'To stop Periodic mode and return to One-shot mode, call the Break method,
' then proceed with your one-shot mode calls.
    if readRegX(core#SHT3X_FETCHDATA, 6, @read_data)    'If readRegX returned -1, then
        return                                          ' no data was available - do nothing.
    _temp_word := (read_data.byte[0] << 8) | read_data.byte[1]
    _rh_word := (read_data.byte[3] << 8) | read_data.byte[4]
    tempword_rhword := (_temp_word << 16) | (_rh_word)

PUB GetHeaterStatus: bool__heater_enabled
'Get Heater status
' FALSE*  - OFF
' TRUE    - ON
  return bool__heater_enabled := ((GetStatus >> 13) & %1) * -1

PUB GetLastCmdStatus: bool__lastcmd_status
'Command status
' FALSE*  - Last command executed successfully
' TRUE    - Last command not processed. Invalid or failed integrated checksum
  return bool__lastcmd_status := ((GetStatus >> 1) & %1) * -1

PUB GetLastCRCStatus: bool__lastwritecrc_status
'Write data checksum status
' FALSE*  - Checksum of last transfer was correct
' TRUE    - Checksum of last transfer write failed
  return bool__lastwritecrc_status := (GetStatus & %1) * -1

PUB GetResetStatus: bool__reset_detected
'Check for System Reset
' FALSE   - No reset since last 'clear status register'
' TRUE*   - reset detected (hard reset, soft reset, power fail)
  return bool__reset_detected := ((GetStatus >> 4) & %1) * -1

PUB GetRH: humidity | read_data, rhtmp, rh
'Return uncalculated Relative Humidity in hundreths of a percent
  return humidity := (100 * (_rh_word * _scale)) / 65535

PUB GetRH_Raw: word__rh
'Return Humidity as a 16-bit word
  word__rh := _rh_word & $FFFF

PUB GetSN: long__serial_num | read_data[2], ms_word, ls_word, ms_crc, ls_crc
'Read 32bit serial number from SHT3x (*not found in datasheet)
    readRegX(core#SHT3X_READ_SERIALNUM, 6, @read_data)
    ms_word := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF
    ms_crc := read_data.byte[2]
    ls_word := ((read_data.byte[3] << 8) | read_data.byte[4]) & $FFFF
    ls_crc := read_data.byte[5]
    
    if compare(crc8(@ms_word, 2), ms_crc) AND compare(crc8(@ls_word, 2), ls_crc)
        return long__serial_num := (ms_word << 16) | ls_word
    else
        return FALSE                                    'Return implausible value if CRC check failed

PUB GetStatus: word__status | read_data, status_crc
'Read SHT3x status register
  readRegX(core#SHT3X_READSTATUS, 3, @read_data)
  word__status := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF
  status_crc := read_data.byte[2]
  if compare (crc8(@word__status, 2), status_crc)
    return word__status
  else
    return $53EC                                    'Return invalid value if CRC check failed
                                                    '(sets all 'Reserved' bits, which should normally be 0)
PUB GetTempC: temperature | read_data, ttmp, temp
'Return Calculated temperature in hundredths of a degree Celsius
  return temperature := ((175 * (_temp_word * _scale)) / 65535)-(45 * _scale)

PUB GetTempF: temperature | read_data, ttmp, temp
'Return Calculated temperature in hundredths of a degree Fahrenheit
  return temperature := ((315 * (_temp_word * _scale)) / 65535)-(49 * _scale)

PUB GetTemp_Raw: word__temp
'Return uncalculated Temperature as a 16-bit word
  return _temp_word & $FFFF

PUB IsAlertPending: bool__alert_pending
'Get Alert status
' FALSE*  - No alerts
' TRUE    - At least one alert pending
  return bool__alert_pending := ((GetStatus >> 15) & %1) * -1

PUB IsRHTrack_Alert: bool__rhtrack_alert
'RH Tracking Alert
' FALSE   - No alert
' TRUE    - Alert
  return bool__rhtrack_alert := ((GetStatus >> 11) & %1) * -1

PUB IsTempTrack_Alert: bool__temptrack_alert
'Temp Tracking Alert
' FALSE   - No alert
' TRUE    - Alert
  return bool__temptrack_alert := ((GetStatus >> 10) & %1) * -1

PUB ReadTempRH: tempword_rhword | check, read_data[2], ms_word, ms_crc, ls_word, ls_crc, meas_wait1, meas_wait2, repeatability
'Get Temperature and RH data from sensor
' with repeatability level LOW, MED, HIGH
    case _repeatability_mode                          'Wait x uSec for measurement to complete
        LOW:
            meas_wait1 := 500
            meas_wait2 := 2000
            repeatability := core#SHT3X_MEAS_LOWREP_STRETCH
        MED:
            meas_wait1 := 1500
            meas_wait2 := 3000
            repeatability := core#SHT3X_MEAS_MEDREP_STRETCH
        HIGH:
            meas_wait1 := 3500
            meas_wait2 := 9000
            repeatability := core#SHT3X_MEAS_HIGHREP_STRETCH
        OTHER:                                          'Default to low-repeatability
            meas_wait1 := 500
            meas_wait2 := 2000
            repeatability := core#SHT3X_MEAS_LOWREP_STRETCH

    readRegX(repeatability, 6, @read_data)
    _temp_word := (read_data.byte[0] << 8) | read_data.byte[1]
    _rh_word := (read_data.byte[3] << 8) | read_data.byte[4]
    tempword_rhword := (_temp_word << 16) | (_rh_word)

PUB GetAlertHighSet: word__hilimit_set | read_crc, read_data, ackbit, tmp

    readRegX(core#SHT3X_ALERTLIM_RD_HI_SET, 3, @read_data)
    read_crc := read_data.byte[2]
    word__hilimit_set := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

    if compare(crc8(@word__hilimit_set, 2), read_crc)
        return word__hilimit_set
    else
        return $DEADBEEF

PUB GetAlertHighSetRH: word__rh_hilimit_set

  return GetAlertHighSet & $FE00

PUB GetAlertHighSetTemp: word__temp_hilimit_set

  return (GetAlertHighSet & $1FF)

PUB GetAlertHighClear: word__hilimit_clear| read_crc, read_data

  readRegX( core#SHT3X_ALERTLIM_RD_HI_CLR, 3, @read_data)
  read_crc := read_data.byte[2]
  word__hilimit_clear := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

  if compare(crc8(@word__hilimit_clear, 2), read_crc)
    return word__hilimit_clear
  else
    return FALSE

PUB GetAlertHighClearRH: word__rh_hilimit_clear

  return GetAlertHighClear & $FE00

PUB GetAlertHighClearTemp: word__temp_hilimit_clear

  return GetAlertHighClear & $1FF

PUB GetAlertLowClear: word__lolimit_clear| read_crc, read_data

  readRegX( core#SHT3X_ALERTLIM_RD_LO_CLR, 3, @read_data)
  read_crc := read_data.byte[2]
  word__lolimit_clear := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

  if compare(crc8(@word__lolimit_clear, 2), read_crc)
    return word__lolimit_clear
  else
    return FALSE

PUB GetAlertLowClearRH: word__rh_lolimit_clear

  return GetAlertLowClear & $FE00

PUB GetAlertLowClearTemp: word__temp_lolimit_clear

  return GetAlertLowClear & $1FF

PUB GetAlertLowSet: word__lolimit_set| read_crc, read_data

  readRegX( core#SHT3X_ALERTLIM_RD_LO_SET, 3, @read_data)
  read_crc := read_data.byte[2]
  word__lolimit_set := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

  if compare(crc8(@word__lolimit_set, 2), read_crc)
    return word__lolimit_set
  else
    return FALSE

PUB GetAlertLowSetRH: word__rh_lolimit_set

  return GetAlertLowSet & $FE00

PUB GetAlertLowSetTemp: word__temp_lolimit_set

  return GetAlertLowSet & $1FF

PUB SetAlertHigh(rh_set, rh_clr, temp_set, temp_clr)

  SetAlertHigh_Set (rh_set, temp_set)
  SetAlertHigh_Clr (rh_clr, temp_clr)

PUB SetAlertLow(rh_clr, rh_set, temp_clr, temp_set)

  SetAlertLow_Set (rh_set, temp_set)
  SetAlertLow_Clr (rh_clr, temp_clr)

PUB SetAllAlert(rh_hi_set, temp_hi_set, rh_hi_clr, temp_hi_clr, rh_lo_clr, temp_lo_clr, rh_lo_set, temp_lo_set)

  SetAlertHigh_Set (rh_hi_set, temp_hi_set)
  SetAlertHigh_Clr (rh_hi_clr, temp_hi_clr)
  SetAlertLow_Clr (rh_lo_clr, temp_lo_clr)
  SetAlertLow_Set (rh_lo_set, temp_lo_set)

PUB SetAlertHigh_Set(rh_set, temp_set) | rht, tt, crct, tmp, write_data, t
' Set high alarm trip threshold for RH and Temp
  rht := RHPct_Raw7 (rh_set)
  tt := TempDeg_Raw9 (temp_set)
  tmp := (rht | tt)
  crct := crc8(@tmp, 2)
  write_data.byte[0] := tmp.byte[1]
  write_data.byte[1] := tmp.byte[0]
  write_data.byte[2] := crct
  
  writeRegX(core#SHT3X_ALERTLIM_WR_HI_SET, 3, write_data)

PUB SetAlertHigh_Clr(rh_clr, temp_clr) | rht, tt, write_data, crct, tmp

  rht := RHPct_Raw7 (rh_clr)
  tt := TempDeg_Raw9 (temp_clr)
  tmp := (rht | tt)
  crct := crc8(@tmp, 2)
  write_data.byte[0] := (tmp >> 8) & $FF
  write_data.byte[1] := tmp & $FF
  write_data.byte[2] := crct
  
  writeRegX(core#SHT3X_ALERTLIM_WR_HI_CLR, 3, write_data)

PUB SetAlertLow_Clr(rh_clr, temp_clr) | rht, tt, write_data, crct, tmp

  rht := RHPct_Raw7 (rh_clr)
  tt := TempDeg_Raw9 (temp_clr)
  tmp := (rht | tt)
  crct := crc8(@tmp, 2)
  write_data.byte[0] := (tmp >> 8) & $FF
  write_data.byte[1] := tmp & $FF
  write_data.byte[2] := crct
  
  writeRegX(core#SHT3X_ALERTLIM_WR_LO_CLR, 3, write_data)

PUB SetAlertLow_Set(rh_set, temp_set) | rht, tt, write_data, crct, tmp

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

PUB SetPeriodicRead(meas_per_sec) | cmdword, mps, repeatability
'Sets number of measurements per second the sensor should take
' in Periodic Measurement mode.
'To stop Periodic mode and return to One-shot mode, call the Break method,
' then proceed with your one-shot mode calls.
'*** Sensirion notes in their datasheet that at 10mps with repeatability set High,
'***  self-heating of the sensor might occur.
    case meas_per_sec
        0, 5, 0.5:
            mps := $20
            case _repeatability_mode
                LOW:
                    repeatability := $2F
                MED:
                    repeatability := $24
                HIGH:
                    repeatability := $32
                OTHER:
                    repeatability := $2F
        1:
            mps := $21
            case _repeatability_mode
                LOW:
                    repeatability := $2D
                MED:
                    repeatability := $26
                HIGH:
                    repeatability := $30
                OTHER:
                    repeatability := $2D
        2:
            mps := $22
            case _repeatability_mode
                LOW:
                    repeatability := $2B
                MED:
                    repeatability := $20
                HIGH:
                    repeatability := $36
                OTHER:
                    repeatability := $2B
        4:
            mps := $23
            case _repeatability_mode
                LOW:
                    repeatability := $29
                MED:
                    repeatability := $22
                HIGH:
                    repeatability := $34
                OTHER:
                    repeatability := $29
        10:
            mps := $27
            case _repeatability_mode
                LOW:
                    repeatability := $2A
                MED:
                    repeatability := $21
                HIGH:
                    repeatability := $37
                OTHER:
                    repeatability := $2A
        OTHER:
            mps := $23
            case _repeatability_mode
                LOW:
                    repeatability := $29
                MED:
                    repeatability := $22
                HIGH:
                    repeatability := $34
                OTHER:
                    repeatability := $29
    Break                                             'Stop any measurements that might be ongoing
    cmdword := (mps << 8) | repeatability
    writeRegX(cmdword, 2, 0)

PUB SetRepeatability(mode)
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

PUB RHPct_Raw7(rh_pct): rh_raw

    case rh_pct
        0..100:
            return ( ( (rh_pct * _scale) / 100 * 65535) / _scale) & $FE00
        OTHER:
            return

PUB RHRaw7_Pct(rh_raw): rh_pct

    return rh_pct := ((100 * ((rh_raw & $FE00) * _scale)) / 65535) + {}32{ + error }

PUB TempDeg_Raw9(temp_c): temp_raw
' Takes degrees C and returns 9-bit value
    temp_raw := (((( (temp_c) * _scale) + (45 * _scale)) / 175 * 65535) / _scale)
    temp_raw := (temp_raw >> 7) & $001FF

PUB TempRaw9_Deg(temp_raw): temp_c
' Takes raw 9-bit value and returns temperature in
'   hundredths of a degree C (0..511 -> -4500..12966 or -45.00C 129.66C)
    case temp_raw
        0..511:
            temp_c := (temp_raw << 7)
            return ((175 * (temp_c * _scale)) / 65535)-(45 * _scale)
        OTHER:
            return

PRI readRegX(reg, nr_bytes, addr_buff) | cmd_packet[2], ackbit
' Read nr_bytes from register 'reg' to address 'addr_buff'
' Some registers have quirky behavior - handle it on a case-by-case basis
    cmd_packet.byte[0] := SLAVE_WR | _addr_bit
    cmd_packet.byte[1] := reg.byte[MSB]                 'Register MSB
    cmd_packet.byte[2] := reg.byte[LSB]                 'Register LSB

    i2c.start                                           {S}
    ackbit := i2c.pwrite (@cmd_packet, 3)               {SL|W . COMMAND MSB . COMMAND LSB}
    if ackbit == i2c#NAK
        i2c.stop
        return $DEAD

    case reg                                            'Quirk handling
        core#SHT3X_READ_SERIALNUM:                      'S/N Read Needs delay before repeated start
            time.USleep (500)
            i2c.start                                   {Sr}
            ackbit := i2c.write (SLAVE_RD | _addr_bit)  {SL|R}
        core#SHT3X_MEAS_HIGHREP_STRETCH..core#SHT3X_MEAS_LOWREP_STRETCH:
            i2c.stop                                    {P}' Measurements with clock-stretching don't
            i2c.start                                   {Sr}' seem to work without this STOP condition
            ackbit := i2c.write (SLAVE_RD | _addr_bit)  {SL|R}
            i2c.stop
        OTHER:
            i2c.start
            ackbit := i2c.write (SLAVE_RD | _addr_bit)

    if ackbit == i2c#NAK
        i2c.stop                                        'No data was available,
        return -1                                       ' so do nothing

    i2c.pread (addr_buff, nr_bytes, TRUE)               {...}
    i2c.stop                                            {P}

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
'    return val'cmd_packet' >> 8
PRI compare(b1, b2)

  return b1 == b2

PRI crc8(data, len): crc | currbyte, i, j

  crc := $FF                                      'Initialize CRC with $FF
  repeat j from 0 to len-1
    currbyte := byte[data][(len-1)-j]             'Byte 'retrieval' is done reverse of the loop because bytes are organized LSB-first
    crc := crc ^ currbyte

    repeat i from 1 to 8
      if (crc & $80)
        crc := (crc << 1) ^ POLYNOMIAL
      else
        crc := (crc << 1)
  crc := crc ^ $00
  crc &= $FF

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
