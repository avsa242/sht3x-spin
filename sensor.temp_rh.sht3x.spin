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

  LOW                         = 0
  MED                         = 1
  HIGH                        = 2

  POLYNOMIAL                  = $31

OBJ

  sht3x : "core.con.sht3x"
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

  if _i2c_cog                         'Stop the I2C object, if it's already running
    Stop

  if I2C_SCL < 0 or I2C_SCL > 31 {    'Validate pin assignments and I2C bus speed
} or I2C_SDA < 0 or I2C_SDA > 31 {
} or I2C_HZ < 0 or I2C_HZ > sht3x#I2C_MAX_HZ {
} or I2C_SCL == I2C_SDA
    abort FALSE

  case I2C_ADDR
    sht3x#SLAVE_ADDR_A:                     'Factory default slave address
      SHT3X_ADDR := sht3x#SLAVE_ADDR_A
      SHT3X_WR := SHT3X_ADDR
      SHT3X_RD := SHT3X_ADDR | %1

    sht3x#SLAVE_ADDR_B:                     'Alternate slave address
      SHT3X_ADDR := sht3x#SLAVE_ADDR_B
      SHT3X_WR := SHT3X_ADDR
      SHT3X_RD := SHT3X_ADDR | %1

    OTHER:                            'Default to factory-set slave address
      SHT3X_ADDR := sht3x#SLAVE_ADDR_A
      SHT3X_WR := SHT3X_ADDR
      SHT3X_RD := SHT3X_ADDR | %1

  _scale := 100 <# 100                'Scale fixed-point math up by this factor
                                      'Calcs overflow if scaling to 1000, so limit to 100 (2 decimal places)
                                      'Makes more sense anyway, given the accuracy limits of the device

  _i2c_cog := i2c.setupx (I2C_SCL, I2C_SDA, I2C_HZ) + 1
  ifnot _i2c_cog
    i2c.terminate
    abort FALSE

  return _i2c_cog

PUB Stop

  i2c.terminate

PUB Break
'Stop Periodic Data Acquisition Mode
' Use this when you wish to return to One-shot mode from Periodic Mode
  cmd(sht3x#SHT3X_BREAK_STOP)
  i2c.stop

PUB ClearStatus
'Clears bits 15, 11, 10, and 4 in the status register
  cmd(sht3x#SHT3X_CLEARSTATUS)
  i2c.stop

PUB ConvertTempRaw16_Raw9(word__temp): temp_9bit

  return temp_9bit := (ConvertTempC_Raw (word__temp) >> 7) & $001FF

PUB ConvertTempRaw9_Raw16(temp_9bit): word__temp

  return word__temp := temp_9bit << 7

PUB ConvertTempC_Raw(temp_c): temp_raw

  return temp_raw := (((temp_c * _scale) + (45 * _scale)) / 175 * 65535) / _scale

PUB ConvertTempRaw_C(temp_raw): temp_c

  return temp_c := ((175 * (temp_raw * _scale)) / 65535)-(45 * _scale)

PUB ConvertRHRaw16_Raw7(word__rh): rh_7bit

  return rh_7bit := ConvertRHPct_Raw (word__rh) & $FE00

PUB ConvertRHRaw7_Raw16(rh_7bit): word__rh

  return word__rh := rh_7bit << 8

PUB ConvertRHPct_Raw(rh_pct): rh_raw

  return rh_raw := ((rh_pct * _scale) / 100 * 65535) / _scale

PUB ConvertRHRaw_Pct(rh_raw): rh_pct

  return rh_pct := (100 * (rh_raw * _scale)) / 65535

PUB FetchData: tempword_rhword | read_data[2], ms_word, ms_crc, ls_word, ls_crc
'Get Temperature and RH data when sensor is in Periodic mode
'To stop Periodic mode and return to One-shot mode, call the Break method,
' then proceed with your one-shot mode calls.
  cmd (sht3x#SHT3X_FETCHDATA)
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
'Read 32bit serial number from SHT3x (not found in datasheet)
  cmd(sht3x#SHT3X_READ_SERIALNUM)
  time.USleep (500)                                 'Must wait a bit, otherwise no/invalid data may be returned
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
  cmd (sht3x#SHT3X_READSTATUS)
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
      repeatability := sht3x#SHT3X_MEAS_LOWREP
    MED:
      meas_wait1 := 1500
      meas_wait2 := 3000
      repeatability := sht3x#SHT3X_MEAS_MEDREP
    HIGH:
      meas_wait1 := 3500
      meas_wait2 := 9000
      repeatability := sht3x#SHT3X_MEAS_HIGHREP
    OTHER:                                          'Default to low-repeatability
      meas_wait1 := 500
      meas_wait2 := 2000
      repeatability := sht3x#SHT3X_MEAS_LOWREP

  cmd (repeatability)
  time.USleep (meas_wait1)
  i2c.start
'  repeat
  check := i2c.write (SHT3X_RD)                   'This one is actually *supposed* to NAK
  ifnot check
    return FALSE
'  until check == i2c#NAK
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

PUB GetAlertHighSet: word__hilimit_set| read_crc, read_data

  cmd(sht3x#SHT3X_ALERTLIM_RD_HI_SET)
  i2c.start
  i2c.write (SHT3X_RD)
  i2c.pread (@read_data, 3, TRUE)
  i2c.stop

  read_crc := read_data.byte[2]
  word__hilimit_set := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

  if compare(crc8(@word__hilimit_set, 2), read_crc)
    return word__hilimit_set
  else
    return FALSE

PUB GetAlertHighSetRH: word__rh_hilimit_set

  return (GetAlertHighSet & $FE00) >> 8

PUB GetAlertHighSetTemp: word__temp_hilimit_set

  return (GetAlertHighSet & $1FF)

PUB GetAlertHighClear: word__hilimit_clear| read_crc, read_data

  cmd(sht3x#SHT3X_ALERTLIM_RD_HI_CLR)
  i2c.start
  i2c.write (SHT3X_RD)
  i2c.pread (@read_data, 3, TRUE)
  i2c.stop

  read_crc := read_data.byte[2]
  word__hilimit_clear := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

  if compare(crc8(@word__hilimit_clear, 2), read_crc)
    return word__hilimit_clear
  else
    return FALSE

PUB GetAlertHighClearRH: word__rh_hilimit_clear

  return (GetAlertHighClear & $FE00) >> 8

PUB GetAlertHighClearTemp: word__temp_hilimit_clear

  return (GetAlertHighClear & $1FF)

PUB GetAlertLowClear: word__lolimit_clear| read_crc, read_data

  cmd(sht3x#SHT3X_ALERTLIM_RD_LO_CLR)
  i2c.start
  i2c.write (SHT3X_RD)
  i2c.pread (@read_data, 3, TRUE)
  i2c.stop

  read_crc := read_data.byte[2]
  word__lolimit_clear := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

  if compare(crc8(@word__lolimit_clear, 2), read_crc)
    return word__lolimit_clear
  else
    return FALSE

PUB GetAlertLowClearRH: word__rh_lolimit_clear

  return (GetAlertLowClear & $FE00) >> 8

PUB GetAlertLowClearTemp: word__temp_lolimit_clear

  return (GetAlertLowClear & $1FF)

PUB GetAlertLowSet: word__lolimit_set| read_crc, read_data

  cmd(sht3x#SHT3X_ALERTLIM_RD_LO_SET)
  i2c.start
  i2c.write (SHT3X_RD)
  i2c.pread (@read_data, 3, TRUE)
  i2c.stop

  read_crc := read_data.byte[2]
  word__lolimit_set := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF

  if compare(crc8(@word__lolimit_set, 2), read_crc)
    return word__lolimit_set
  else
    return FALSE

PUB GetAlertLowSetRH: word__rh_lolimit_set

  return (GetAlertLowSet & $FE00) >> 8

PUB GetAlertLowSetTemp: word__temp_lolimit_set

  return (GetAlertLowSet & $1FF)

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

PUB SetAlertHigh_Set(rh_set, temp_set) | rht, tt, wt, crct, write_data

  rht := ConvertRHRaw16_Raw7 (rh_set)'ConvertRHPct_Raw (rh_set) & $FE00
  tt := ConvertTempRaw16_Raw9 (temp_set)'(ConvertTempC_Raw (temp_set) >> 7) & $001FF
  write_data := (rht | tt) & $FFFF
  crct := crc8(@write_data, 2)
  if cmd(sht3x#SHT3X_ALERTLIM_WR_HI_SET)
    i2c.stop
    return $DEADC0DE

  _ackbit := i2c.write (write_data.byte[1])
  if _ackbit == i2c#NAK
    i2c.stop
    return $DEAD0001

  _ackbit := i2c.write (write_data.byte[0])
  if _ackbit == i2c#NAK
    i2c.stop
    return $DEAD0000

  _ackbit := i2c.write (crct)
  if _ackbit == i2c#NAK
    i2c.stop
    return ($DEAD << 16) | crct

  i2c.stop
  return write_data

PUB SetAlertHigh_Clr(rh_clr, temp_clr) | rht, tt, write_data, crct

  rht := ConvertRHPct_Raw (rh_clr) & $FE00
  tt := (ConvertTempC_Raw (temp_clr) >> 7) & $001FF
  write_data := (rht | tt) & $FFFF
  crct := crc8(@write_data, 2)
  if cmd(sht3x#SHT3X_ALERTLIM_WR_HI_CLR)
    i2c.stop
    return $DEADC0DE

  _ackbit := i2c.write (write_data.byte[1])
  if _ackbit == i2c#NAK
    i2c.stop
    return $DEAD0001

  _ackbit := i2c.write (write_data.byte[0])
  if _ackbit == i2c#NAK
    i2c.stop
    return $DEAD0000

  _ackbit := i2c.write (crct)
  if _ackbit == i2c#NAK
    i2c.stop
    return ($DEAD << 16) | crct

  i2c.stop
  return write_data

PUB SetAlertLow_Clr(rh_clr, temp_clr) | rht, tt, write_data, crct

  rht := ConvertRHPct_Raw (rh_clr) & $FE00
  tt := (ConvertTempC_Raw (temp_clr) >> 7) & $001FF
  write_data := (rht | tt) & $FFFF
  crct := crc8(@write_data, 2)
  if cmd(sht3x#SHT3X_ALERTLIM_WR_LO_CLR)
    i2c.stop
    return $DEADC0DE

  _ackbit := i2c.write (write_data.byte[1])
  if _ackbit == i2c#NAK
    i2c.stop
    return $DEAD0001

  _ackbit := i2c.write (write_data.byte[0])
  if _ackbit == i2c#NAK
    i2c.stop
    return $DEAD0000

  _ackbit := i2c.write (crct)
  if _ackbit == i2c#NAK
    i2c.stop
    return ($DEAD << 16) | crct

  i2c.stop
  return write_data

PUB SetAlertLow_Set(rh_set, temp_set) | rht, tt, write_data, crct

  rht := ConvertRHPct_Raw (rh_set) & $FE00
  tt := (ConvertTempC_Raw (temp_set) >> 7) & $001FF
  write_data := (rht | tt) & $FFFF
  crct := crc8(@write_data, 2)
  if cmd(sht3x#SHT3X_ALERTLIM_WR_LO_SET)
    i2c.stop
    return $DEADC0DE

  _ackbit := i2c.write (write_data.byte[1])
  if _ackbit == i2c#NAK
    i2c.stop
    return $DEAD0001

  _ackbit := i2c.write (write_data.byte[0])
  if _ackbit == i2c#NAK
    i2c.stop
    return $DEAD0000

  _ackbit := i2c.write (crct)
  if _ackbit == i2c#NAK
    i2c.stop
    return ($DEAD << 16) | crct

  i2c.stop
  return write_data


PUB SetHeater(bool__enabled)
'Enable/Disable built-in heater
'(per SHT3x datasheet, it is for plausability checking only)
  case bool__enabled
    TRUE:
      cmd(sht3x#SHT3X_HEATEREN)
    FALSE:
      cmd(sht3x#SHT3X_HEATERDIS)
    OTHER:
      cmd(sht3x#SHT3X_HEATERDIS)

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
  cmd (cmdword)

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
  cmd (sht3x#SHT3X_SOFTRESET)
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
