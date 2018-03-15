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

  SHT3X_ADDR_A                = $44 << 1                'ADDR Pin low (default)
  SHT3X_ADDR_B                = $45 << 1                'ADDR Pin pulled high
  I2C_MAX_HZ                  = 1_000_000               'SHT3X supports I2C FM up to 1MHz

  SHT3X_BREAK_STOP            = $3093
  SHT3X_READ_SERIALNUM        = $3780
  SHT3X_MEAS_HIGHREP_STRETCH  = $2C06
  SHT3X_MEAS_MEDREP_STRETCH   = $2C0D
  SHT3X_MEAS_LOWREP_STRETCH   = $2C10
  SHT3X_ART                   = $2B32
  SHT3X_MEAS_HIGHREP          = $2400
  SHT3X_MEAS_MEDREP           = $240B
  SHT3X_MEAS_LOWREP           = $2416
  SHT3X_FETCHDATA             = $E000
  SHT3X_READSTATUS            = $F32D
  SHT3X_CLEARSTATUS           = $3041
  SHT3X_SOFTRESET             = $30A2
  SHT3X_HEATEREN              = $306D
  SHT3X_HEATERDIS             = $3066

  LOW                         = 0
  MED                         = 1
  HIGH                        = 2

  POLYNOMIAL                  = $31

OBJ

  time  : "time"
  i2c   : "jm_i2c_fast"

VAR
  byte _i2c_cog
  byte _scale
  byte _ackbit
  word _temp_word
  word _rh_word
  byte _repeatability_mode

  byte SHT3X_ADDR, SHT3X_WR, SHT3X_RD
  
PUB Null
'This is not a top-level object

PUB Start(I2C_SCL, I2C_SDA, I2C_HZ, I2C_ADDR)

  if I2C_SCL < 0 or I2C_SCL > 31 {    'Validate pin assignments and I2C bus speed
} or I2C_SDA < 0 or I2C_SDA > 31 {
} or I2C_HZ < 0 or I2C_HZ > I2C_MAX_HZ {
} or I2C_SCL == I2C_SDA
    abort FALSE

  case I2C_ADDR
    SHT3X_ADDR_A:                     'Factory default slave address
      SHT3X_ADDR := SHT3X_ADDR_A
      SHT3X_WR := SHT3X_ADDR
      SHT3X_RD := SHT3X_ADDR | %1

    SHT3X_ADDR_B:                     'Alternate slave address
      SHT3X_ADDR := SHT3X_ADDR_B
      SHT3X_WR := SHT3X_ADDR
      SHT3X_RD := SHT3X_ADDR | %1

    OTHER:                            'Default to factory-set slave address
      SHT3X_ADDR := SHT3X_ADDR_A
      SHT3X_WR := SHT3X_ADDR
      SHT3X_RD := SHT3X_ADDR | %1

  _scale := 100 <# 100                'Scale fixed-point math up by this factor
                                      'Calcs overflow if scaling to 1000, so limit to 100 (2 decimal places)
                                      'Makes more sense anyway, given the accuracy limits of the device

  _i2c_cog := i2c.setupx (I2C_SCL, I2C_SDA, I2C_HZ)
  ifnot _i2c_cog
    i2c.terminate
    abort FALSE

PUB Stop

  i2c.terminate

PUB Break
'Stop Periodic Data Acquisition Mode
' Use this when you wish to return to One-shot mode from Periodic Mode
  cmd(SHT3X_BREAK_STOP)
  i2c.stop

PUB ClearStatus
'Clears bits 15, 11, 10, and 4 in the status register
  cmd(SHT3X_CLEARSTATUS)
  i2c.stop

PUB FetchData: tempword_rhword | read_data[2], ms_word, ms_crc, ls_word, ls_crc 'UNTESTED
'Get Temperature and RH data when sensor
' in Periodic mode
'To stop Periodic mode and return to One-shot mode, call the Break method,
' then proceed with your one-shot mode calls.
  cmd (SHT3X_FETCHDATA)
  i2c.start
  _ackbit := i2c.write (SHT3X_RD)
  if _ackbit == i2c#NAK
    i2c.stop                            'No Data available, stop
    return FALSE
  i2c.pread (@read_data, 6, TRUE)
  i2c.stop
  _temp_word := (read_data.byte[0] << 8) | read_data.byte[1]
  _rh_word := (read_data.byte[3] << 8) | read_data.byte[4]
  tempword_rhword := (_temp_word << 16) | (_rh_word)

PUB GetAlertStatus: alert_pending
'Get Alert status
' 0*- No alerts
' 1 - at least one pending
  return alert_pending := ((GetStatus >> 15) & %1) * -1

PUB GetHeaterStatus: heater_enabled
'Get Heater status
' 0*- OFF
' 1 - ON
  return heater_enabled := ((GetStatus >> 13) & %1) * -1

PUB GetLastCmdStatus: lastcmd_status
'Command status
' 0*- Last command executed successfully
' 1 - Last command not processed. Invalid or failed integrated checksum
  return lastcmd_status := ((GetStatus >> 1) & %1) * -1

PUB GetLastCRCStatus: lastwritecrc_status
'Write data checksum status
' 0*- Checksum of last transfer was correct
' 1 - Checksum of last transfer write failed
  return lastwritecrc_status := (GetStatus & %1) * -1

PUB GetResetStatus: reset_detected
'Check for System Reset
' 0 - No reset since last 'clear status register'
' 1*- reset detected (hard reset, soft reset, power fail)
  return reset_detected := ((GetStatus >> 4) & %1) * -1

PUB GetRH: humidity | read_data, rhtmp, rh
'Return Relative Humidity in hundreths of a percent
  return humidity := (100 * (_rh_word * _scale)) / 65535

PUB GetRH_Raw: word__rh

  word__rh := _rh_word

PUB GetRHTrack_Alert: rhtrack_alert
'RH Tracking Alert
' 0 - No alert
' 1 - Alert
  return rhtrack_alert := (GetStatus >> 11) & %1

PUB GetSN: long__serial_num | read_data[2], ms_word, ls_word, ms_crc, ls_crc
'Read 32bit serial number from SHT3x (not found in datasheet)
  cmd(SHT3X_READ_SERIALNUM)
  time.USleep (500)
  i2c.start
  _ackbit := i2c.write (SHT3X_RD)
  if _ackbit == i2c#NAK
    i2c.stop
    return FALSE
  i2c.pread (@read_data, 6, TRUE)
  i2c.stop

  ms_word := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF
  ms_crc := read_data.byte[2]
  ls_word := ((read_data.byte[3] << 8) | read_data.byte[4]) & $FFFF
  ls_Crc := read_data.byte[5]

  if compare(crc8(@ms_word, 2), ms_crc) AND compare(crc8(@ls_word, 2), ls_crc)
    return long__serial_num := (ms_word << 16) | ls_word
  else
    return FALSE                                    'Return implausible value if CRC check failed

PUB GetStatus: word__status | read_data, status_crc
'Read SHT3x status register
  cmd (SHT3X_READSTATUS)
  i2c.start
  _ackbit := i2c.write (SHT3X_RD)
  if _ackbit == i2c#NAK
    i2c.stop
    return FALSE
  i2c.pread (@read_data, 3, TRUE)
  i2c.stop

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

PUB GetTemp_Raw: word__temp

  return _temp_word

PUB GetTemp_RH(ptr_word__temp, ptr_word__rh)
'Return both Calculated Temperature and Humidity
  long[ptr_word__temp] := GetTempC
  long[ptr_word__rh] := GetRH

PUB GetTemp_RH_Raw: long__temp_rh
'Return both Calculated Temperature and Humidity
'Places Temperature reading in Most significant word, RH in Least significant word
  long__temp_rh.word[1] := _temp_word
  long__temp_rh.word[0] := _rh_word

PUB GetTempTrack_Alert: temptrack_alert
'Temp Tracking Alert
' 0 - No alert
' 1 - Alert
  return temptrack_alert := ((GetStatus >> 10) & %1) * -1

PUB IsPresent: status
'Polls I2C bus for SHT3x
'Returns TRUE if present.
  status := i2c.present(SHT3X_ADDR)
  return status

PUB PeriodicRead(meas_per_sec) | cmdword, mps, repeatability
'Sets number of measurements per second the sensor should take
' in Periodic Measurement mode.
'To stop Periodic mode and return to One-shot mode, call the Break method,
' then proceed with your one-shot mode calls.
'*** Sensirion notes in their datasheet that at 10mps, self-heating
'***  of the sensor might occur.
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
  cmd (cmdword)

PUB ReadTempRH: tempword_rhword | check, read_data[2], ms_word, ms_crc, ls_word, ls_crc, meas_wait1, meas_wait2, repeatability
'Get Temperature and RH data from sensor
'with repeatability level LOW, MED, HIGH
  case _repeatability_mode                          'Wait x uSec for measurement to complete
    LOW:
      meas_wait1 := 500
      meas_wait2 := 2000
      repeatability := SHT3X_MEAS_LOWREP
    MED:
      meas_wait1 := 1500
      meas_wait2 := 3000
      repeatability := SHT3X_MEAS_MEDREP
    HIGH:
      meas_wait1 := 3500
      meas_wait2 := 9000
      repeatability := SHT3X_MEAS_HIGHREP
    OTHER:                                          'Default to low-repeatability
      meas_wait1 := 500
      meas_wait2 := 2000
      repeatability := SHT3X_MEAS_LOWREP

  cmd (repeatability)
  time.USleep (meas_wait1)
  i2c.start
  repeat
    check := i2c.write (SHT3X_RD)                   'This one is actually *supposed* to NAK
  until check == i2c#NAK
  i2c.stop
  time.USleep (meas_wait2)
  i2c.start
  _ackbit := i2c.write (SHT3X_RD)
  if _ackbit == i2c#NAK
    i2c.stop
    return FALSE
  i2c.pread (@read_data, 6, TRUE)
  i2c.stop
  _temp_word := (read_data.byte[0] << 8) | read_data.byte[1]
  _rh_word := (read_data.byte[3] << 8) | read_data.byte[4]
  tempword_rhword := (_temp_word << 16) | (_rh_word)

PUB SetHeater(bool__enabled)
'Enable/Disable built-in heater
'(per SHT3x datasheet, it is for plausability checking only)
  case bool__enabled
    TRUE:
      cmd(SHT3X_HEATEREN)
    FALSE:
      cmd(SHT3X_HEATERDIS)
    OTHER:
      cmd(SHT3X_HEATERDIS)

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
  cmd (SHT3X_SOFTRESET)
  i2c.stop
  time.MSleep (50)

PRI cmd(cmd_word) | cmd_long, cmd_byte

  if cmd_word
    cmd_long := (SHT3X_WR << 16) | cmd_word
    invert (@cmd_long)
    i2c.start
    _ackbit := i2c.pwrite (@cmd_long, 3)
    if _ackbit == i2c#NAK
      i2c.stop
      return FALSE
  else
    return FALSE

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

PRI invert(ptr) | i, tmp

  repeat i from 0 to 2
    tmp.byte[2-i] := byte[ptr][i]
  bytemove(ptr, @tmp, 3)

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
