{
    --------------------------------------------
    Filename: sensor.temp_rh.sht31.spin
    Author: Jesse Burt
    Description: Driver for Sensirion's SHT31 Temperature/RH Sensor
    Copyright (c) 2018
    See end of file for terms of use.
    --------------------------------------------
}

CON

  SHT31_ADDR_A                = $44 << 1                'ADDR Pin low (default)
  SHT31_ADDR_B                = $45 << 1                'ADDR Pin pulled high
  I2C_MAX_HZ                  = 1_000_000               'SHT31 supports I2C FM up to 1MHz

  SHT31_BREAK_STOP            = $3093
  SHT31_READ_SERIALNUM        = $3780
  SHT31_MEAS_HIGHREP_STRETCH  = $2C06
  SHT31_MEAS_MEDREP_STRETCH   = $2C0D
  SHT31_MEAS_LOWREP_STRETCH   = $2C10
  SHT31_ART                   = $2B32
  SHT31_MEAS_HIGHREP          = $2400
  SHT31_MEAS_MEDREP           = $240B
  SHT31_MEAS_LOWREP           = $2416
  SHT31_FETCHDATA             = $E000
  SHT31_READSTATUS            = $F32D
  SHT31_CLEARSTATUS           = $3041
  SHT31_SOFTRESET             = $30A2
  SHT31_HEATEREN              = $306D
  SHT31_HEATERDIS             = $3066

  LOW                         = 0
  MED                         = 1
  HIGH                        = 2

  POLYNOMIAL                  = $31

OBJ

  time  : "time"
  i2c   : "jm_i2c_fast"

VAR

  long err_cnt
  long trans_cnt
  word temp_word
  word rh_word
  long _ackbit
  long _nak
  word _scale
  long _i2c_cog
  long _i2c_scl, _i2c_sda, _i2c_addr, _reset, _alert
  byte SHT31_ADDR, SHT31_WR, SHT31_RD
  
PUB Null
'This is not a top-level object

PUB Start(I2C_SCL, I2C_SDA, I2C_HZ, I2C_ADDR, RESET, ALERT)

  if I2C_SCL < 0 or I2C_SCL > 31 {    'Validate pin assignments and I2C bus speed
} or I2C_SDA < 0 or I2C_SDA > 31 {
} or I2C_HZ < 0 or I2C_HZ > I2C_MAX_HZ {
} or I2C_SCL == I2C_SDA {
} or RESET < -1 or RESET > 31 {       'Specify -1 for these last two if you aren't using them
} or ALERT < -1 or ALERT > 31 
    abort FALSE

  case I2C_ADDR
    SHT31_ADDR_A:                     'Factory default slave address
      SHT31_ADDR := SHT31_ADDR_A
      SHT31_WR := SHT31_ADDR
      SHT31_RD := SHT31_ADDR | %1

    SHT31_ADDR_B:                     'Alternate slave address
      SHT31_ADDR := SHT31_ADDR_B
      SHT31_WR := SHT31_ADDR
      SHT31_RD := SHT31_ADDR | %1

    OTHER:                            'Default to factory-set slave address
      SHT31_ADDR := SHT31_ADDR_A
      SHT31_WR := SHT31_ADDR
      SHT31_RD := SHT31_ADDR | %1

  _scale := 100 <# 100                'Scale fixed-point math up by this factor
                                      'Calcs overflow if scaling to 1000, so limit to 100 (2 decimal places)
                                      'Makes more sense anyway, given the accuracy limits of the device

  _i2c_cog := i2c.setupx (I2C_SCL, I2C_SDA, I2C_HZ)
  ifnot _i2c_cog
    i2c.terminate
    abort FALSE

PUB Break
'Stop Periodic Data Acquisition Mode
  cmd(SHT31_BREAK_STOP)
  i2c.stop

PUB check_for_sht31 | status

'  status := i2c.present (SHT31_ADDR)
'  i2c.stop
  status := i2c.write (SHT31_ADDR)
  case status
    TRUE:
      return TRUE
    OTHER:
      abort FALSE

PUB ContinuousRead(mps, repeatability) | cmdword 'UNTESTED

  case mps
    0:
      mps := $20
      case repeatability
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
      case repeatability
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
      case repeatability
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
      case repeatability
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
      case repeatability
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
      case repeatability
        LOW:
          repeatability := $29
        MED:
          repeatability := $22
        HIGH:
          repeatability := $34
        OTHER:
          repeatability := $29
  cmdword := (mps << 16) | repeatability
  cmd (cmdword)

PUB FetchData: tempword_rhword | read_data[2], ms_word, ms_crc, ls_word, ls_crc 'UNTESTED
'Get Temperature and RH data from sensor
'with repeatability level LOW, MED, HIGH
  cmd (SHT31_FETCHDATA)
  i2c.start
  _ackbit := i2c.write (SHT31_RD)
  if _ackbit == i2c#NAK
    i2c.stop                            'No Data available, stop
    abort FALSE
  i2c.pread (@read_data, 6, TRUE)
  i2c.stop
  temp_word := (read_data.byte[0] << 8) | read_data.byte[1]
  rh_word := (read_data.byte[3] << 8) | read_data.byte[4]
  tempword_rhword := (temp_word << 16) | (rh_word)

PUB GetRH: humidity | read_data, rhtmp, rh
'Return Relative Humidity in hundreths of a percent
  return humidity := (100 * (rh_word * _scale)) / 65535

PUB GetSN: long__serial_num | read_data[2], ms_word, ls_word, ms_crc, ls_crc 'UNTESTED

  cmd(SHT31_READ_SERIALNUM)
  time.USleep (500)
  i2c.start
  i2c.write (SHT31_RD)
  i2c.pread (@read_data, 6, TRUE)
  i2c.stop

  ms_word := ((read_data.byte[0] << 8) | read_data.byte[1]) & $FFFF
  ms_crc := read_data.byte[2]
  ls_word := ((read_data.byte[3] << 8) | read_data.byte[4]) & $FFFF
  ls_Crc := read_data.byte[5]

  if compare(crc8(@ms_word, 2), ms_crc) AND compare(crc8(@ls_word, 2), ls_crc)
    return long__serial_num := (ms_word << 16) | ls_word

PUB led(pin)

  dira[pin] := 1
  repeat
    !outa[pin]
    time.MSleep (100)

PUB GetStatus: status | ackbit, i, readback, readcrc

  cmd (SHT31_READSTATUS)
  i2c.start
  i2c.write (SHT31_RD)
  i2c.pread (@readback, 3, TRUE)
  i2c.stop

  readcrc := readback.byte[2]
  if compare (readcrc, crc8(readback >> 8, 3))
    return status
  else
    abort FALSE

{
Bit - Field Description

15  - Alert
      0*- No alerts
      1 - at least one pending
14  - Reserved

13  - Heater status
      0*- OFF
      1 - ON
12  - Reserved

11  - RH Tracking alert
      0*- No alert
      1 - alert

10  - T Tracking alert
      0*- No alert
      1 - alert

9:5 - Reserved (xxxxx)

4   - System Reset Detected
      0 - No reset since last 'clear status register'
      1*- reset detected (hard reset, soft reset, power fail)

3:2 - Reserved (00)

1   - Command status
      0*- Last command executed successfully
      1 - Last command not processed. Invalid or failed integrated checksum

0   - Write data checksum status
      0*- Checksum of last transfer was correct
      1 - Checksum of last transfer write failed
}


PUB GetStatus_Alert: alert_pending

  return alert_pending := (GetStatus >> 15) & %1
  
PUB GetStatus_Heater: heater_status

  return heater_status := (GetStatus >> 13) & %1

PUB GetStatus_RHT_Alert: rhtrack_alert

  return rhtrack_alert := (GetStatus >> 11) & %1

PUB GetStatus_TT_Alert: temptrack_alert

  return temptrack_alert := (GetStatus >> 10) & %1

PUB GetStatus_Reset: reset_detected

  return reset_detected := (GetStatus >> 4) & %1

PUB GetStatus_Cmd: lastcmd_status

  return lastcmd_status := (GetStatus >> 1) & %1

PUB GetStatus_CRCStatus: lastwritecrc_status

  return lastwritecrc_status := (GetStatus & %1)

PUB GetTemp_RH(ptr_temp, ptr_rh)
'Return both Temperature and Humidity
  long[ptr_temp] := GetTempC
  long[ptr_rh] := GetRH

PUB GetTempC: temperature | read_data, ttmp, temp
'Return temperature in hundreths of a degree Celsius
  return temperature := ((175 * (temp_word * _scale)) / 65535)-(45 * _scale)

PUB GetTempRH(repeatability): tempword_rhword | check, read_data[2], ms_word, ms_crc, ls_word, ls_crc, meas_wait1, meas_wait2
'Get Temperature and RH data from sensor
'with repeatability level LOW, MED, HIGH
  case repeatability              'Wait x uSec for measurement to complete
    LOW:
      meas_wait1 := 500
      meas_wait2 := 2000
      repeatability := SHT31_MEAS_LOWREP
    MED:
      meas_wait1 := 1500
      meas_wait2 := 3000
      repeatability := SHT31_MEAS_MEDREP
    HIGH:
      meas_wait1 := 3500
      meas_wait2 := 9000
      repeatability := SHT31_MEAS_HIGHREP
    OTHER:                        'Default to low-repeatability
      meas_wait1 := 500
      meas_wait2 := 2000
      repeatability := SHT31_MEAS_LOWREP

  cmd (repeatability)
  time.USleep (meas_wait1)
  i2c.start
  repeat
    check := i2c.write (SHT31_RD)
  until check
  i2c.stop
  time.USleep (meas_wait2)
  i2c.start
  _ackbit := i2c.write (SHT31_RD)
  i2c.pread (@read_data, 6, TRUE)
  i2c.stop
  temp_word := (read_data.byte[0] << 8) | read_data.byte[1]
  rh_word := (read_data.byte[3] << 8) | read_data.byte[4]
  tempword_rhword := (temp_word << 16) | (rh_word)

PUB SetHeater(bool__enabled) 'UNTESTED

  case ||bool__enabled
    TRUE:
      cmd(SHT31_HEATEREN)
    FALSE:
      cmd(SHT31_HEATERDIS)
    OTHER:
      cmd(SHT31_HEATERDIS)

PUB SoftReset 'UNTESTED

  cmd (SHT31_SOFTRESET)
  i2c.stop
  time.MSleep (50)

PRI cmd(cmd_word) | ackbit, cmd_long, cmd_byte

  if cmd_word
    cmd_long := (SHT31_WR << 16) | cmd_word
    invert (@cmd_long)
    i2c.start
    ackbit := i2c.pwrite (@cmd_long, 3)
    if ackbit
      abort FALSE
  else
    abort FALSE '360uS

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

PRI read3bytes | ackbit, i, read_data, data_word, data_crc, data

  i2c.start
  ackbit := i2c.write (SHT31_RD)
  if ackbit
    return FALSE
  i2c.pread (@read_data, 3, TRUE)
  i2c.stop

  trans_cnt++
  repeat i from 0 to 2
    case i
      0..1:                           'Word
        data_word.byte[1-i] := read_data.byte[i]
      2:                              'CRC of word
        data_crc := read_data.byte[i]

  case compare(crc8(@data_word, 2), data_crc)
    FALSE:
'      ser.Str (string("CRC BAD! Got "))
'      ser.Hex (data_crc, 2)
'      ser.Str (string(", expected "))
'      ser.Hex (crc8(data_word, 2), 2)
'      ser.NewLine
      err_cnt++
      return FALSE
    OTHER:

  data := data_word
  return data

PRI read6bytes | ackbit, i, read_data[2], ms_word, ls_word, ms_crc, ls_crc, data

  i2c.start
  ackbit := i2c.write (SHT31_RD)
  if ackbit
    return FALSE
  i2c.pread (@read_data, 6, TRUE)
  i2c.stop
  trans_cnt++
  repeat i from 0 to 5
    case i
      0..1:                           'MSB
        ms_word.byte[1-i] := read_data.byte[i]
      2:                              'CRC of MSB
        ms_crc := read_data.byte[i]
      3..4:                           'LSB
        ls_word.byte[4-i] := read_data.byte[i]
      5:                              'CRC of LSB
        ls_crc := read_data.byte[i]
  ms_word &= $FFFF
  ls_word &= $FFFF
  case compare(crc8(@ms_word, 2), ms_crc)
    FALSE:
'      ser.Str (string("MSB CRC BAD! Got "))
'      ser.Hex (ms_crc, 2)
'      ser.Str (string(", expected "))
'      ser.Hex (crc8(ms_word, 2), 2)
'      ser.NewLine
      err_cnt++
      return FALSE
    OTHER:

  case compare(crc8(@ls_word, 2), ls_crc)
    FALSE:
'      ser.Str (string("LSB CRC BAD! Got "))
'      ser.Hex (ls_crc, 2)
'      ser.Str (string(", expected "))
'      ser.Hex (crc8(ls_word, 2), 2)
'      ser.NewLine
      err_cnt++
      return FALSE
    OTHER:
  data := (ms_word << 16) | ls_word
  return data

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
