{
    --------------------------------------------
    Filename:
    Author:
    Copyright (c) 20__
    See end of file for terms of use.
    --------------------------------------------
}

CON

  _clkmode = cfg#_clkmode
  _xinfreq = cfg#_xinfreq

  SHT31_DEFAULT_ADDR          = $44 << 1
  SHT31_WR                    = SHT31_DEFAULT_ADDR
  SHT31_RD                    = SHT31_DEFAULT_ADDR + 1

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

  SCL                         = 6
  SDA                         = 5
  BUS_RATE                    = 100_000'kHz/kbps

  PIX_PIN                     = 15'13
  
OBJ

  cfg   : "core.con.client.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  i2c   : "jm_i2c_fast"
  debug : "debug"
  math  : "math.float"
  fs    : "string.float"

VAR

  long err_cnt
  long trans_cnt
  long pix_array
  word temp_word
  word rh_word
  long _ackbit
  long _monitor_ack_stack[100]
  long _nak
  word _scale

PUB Main | i

  setup
  ContinuousRead (4, LOW)
  
  repeat
'    GetTempRH (LOW)
    FetchData
    read_t_rh
    ser.NewLine
    time.MSleep (100)

PUB cmd(cmd_word) | ackbit, cmd_long, cmd_byte

  if cmd_word
    cmd_long := (SHT31_WR << 16) | cmd_word
    invert (@cmd_long)
    i2c.start
    ackbit := i2c.pwrite (@cmd_long, 3)
    if ackbit
      abort FALSE
'    i2c.stop
  else
    abort FALSE '360uS

PUB invert(ptr) | i, tmp

  repeat i from 0 to 2
    tmp.byte[2-i] := byte[ptr][i]
  bytemove(ptr, @tmp, 3)

PUB compare(b1, b2)

  return b1 == b2

PUB crc8(data, len): crc | currbyte, i, j

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

PUB get_sn | read_data

  cmd(SHT31_READ_SERIALNUM)
  read_data := read6bytes
  return read_data

PUB GetTempRH(repeatability): tempword_rhword | check, read_data[2], ms_word, ms_crc, ls_word, ls_crc, meas_wait1, meas_wait2
'Get Temperature and RH data from sensor
'with repeatability level LOW, MED, HIGH
  case repeatability              'Wait x uSec for measurement to complete
    LOW:
      meas_wait1 := 0
      meas_wait2 := 2000
      repeatability := SHT31_MEAS_LOWREP
    MED:
      meas_wait1 := 1000
      meas_wait2 := 3000
      repeatability := SHT31_MEAS_MEDREP
    HIGH:
      meas_wait1 := 3000
      meas_wait2 := 9000
      repeatability := SHT31_MEAS_HIGHREP
    OTHER:                        'Default to low-repeatability
      meas_wait1 := 0
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

PUB Break
'Stop Periodic Data Acquisition Mode
  cmd(SHT31_BREAK_STOP)
  i2c.stop

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

PRI check_crc | i, ms_word, ms_crc, ls_word, ls_crc, read_data, data

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
      ser.Str (string("MSB CRC BAD! Got "))
      ser.Hex (ms_crc, 2)
      ser.Str (string(", expected "))
      ser.Hex (crc8(ms_word, 2), 2)
      ser.NewLine
      err_cnt++
      return FALSE
    OTHER:

  case compare(crc8(@ls_word, 2), ls_crc)
    FALSE:
      ser.Str (string("LSB CRC BAD! Got "))
      ser.Hex (ls_crc, 2)
      ser.Str (string(", expected "))
      ser.Hex (crc8(ls_word, 2), 2)
      ser.NewLine
      err_cnt++
      return FALSE
    OTHER:
  data := (ms_word << 16) | ls_word
  return data

PUB read_t | read_data, ttmp, temp

  ser.Str (string("Temp: "))
  temp := ((175 * (temp_word * _scale)) / 65535)-(45 * _scale)                'Integer version*scale
  ser.Dec (temp)

PUB read_rh | read_data, rhtmp, rh

  ser.Str (string("RH: "))
  rh := (100 * (rh_word * _scale))/65535                      'Integer version
  ser.Dec (rh)

PUB read_t_rh | read_data, ttmp, temp, rhtmp, rh

  read_t
  ser.Char (" ")
  read_rh

PUB read3bytes | ackbit, i, read_data, data_word, data_crc, data

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
      ser.Str (string("CRC BAD! Got "))
      ser.Hex (data_crc, 2)
      ser.Str (string(", expected "))
      ser.Hex (crc8(data_word, 2), 2)
      ser.NewLine
      err_cnt++
      return FALSE
    OTHER:

  data := data_word
  return data

PUB read6bytes | ackbit, i, read_data[2], ms_word, ls_word, ms_crc, ls_crc, data

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
      ser.Str (string("MSB CRC BAD! Got "))
      ser.Hex (ms_crc, 2)
      ser.Str (string(", expected "))
      ser.Hex (crc8(ms_word, 2), 2)
      ser.NewLine
      err_cnt++
      return FALSE
    OTHER:

  case compare(crc8(@ls_word, 2), ls_crc)
    FALSE:
      ser.Str (string("LSB CRC BAD! Got "))
      ser.Hex (ls_crc, 2)
      ser.Str (string(", expected "))
      ser.Hex (crc8(ls_word, 2), 2)
      ser.NewLine
      err_cnt++
      return FALSE
    OTHER:
  data := (ms_word << 16) | ls_word
  return data

PUB setup | i2c_cog

  _scale := 100
  ser.Start (115_200)
  ser.Clear
  
  math.Start
  fs.SetPrecision (4)

  ser.Clear

  ser.Str (string("I2C Setup on SCL: "))
  ser.Dec (SCL)
  ser.Str (string(", SDA: "))
  ser.Dec (SDA)
  ser.Str (string(" at "))
  ser.Dec (BUS_RATE/1_000)
  ser.Str (string("kHz..."))
  if i2c_cog := i2c.setupx (SCL, SDA, BUS_RATE)
    ser.Str (string("started on cog "))
    ser.Dec (i2c_cog)
    ser.NewLine
  else
    ser.Str (string("failed - halting!", ser#NL))
    debug.LEDSlow (cfg#LED1)
  time.MSleep (50)

  cognew(monitor_ack, @_monitor_ack_stack)
'  check_for_sht31

PUB check_for_sht31 | status

  ser.Str (string("Checking for SHT31 at $"))
  ser.Hex (SHT31_DEFAULT_ADDR >> 1, 2)
  ser.Str (string("..."))

  status := i2c.present (SHT31_DEFAULT_ADDR)
  i2c.stop
  case status
    TRUE:
      ser.Str (string("found device with SN $"))
      ser.Hex (get_sn, 8)
      ser.NewLine
    OTHER:
      ser.Str (string("no response - halting", ser#NL))
      debug.LEDSlow (cfg#LED1)

PUB SoftReset 'UNTESTED

  cmd (SHT31_SOFTRESET)
  i2c.stop

PUB SetHeater(bool__enabled)

  case ||bool__enabled
    TRUE:
      cmd(SHT31_HEATEREN)
    FALSE:
      cmd(SHT31_HEATERDIS)
    OTHER:
      cmd(SHT31_HEATERDIS)
    
PUB GetStatus: status | ackbit, i, readback, readcrc

  cmd (SHT31_READSTATUS)
  i2c.start
  i2c.write (SHT31_RD)
  i2c.pread (@readback, 3, TRUE)
  i2c.stop
  readcrc := readback.byte[2]
  if compare (readcrc, crc8(readback >> 8))
    return status
  else
    abort FALSE

{PUB sht31_status(data) | alert, heater, rh_track, t_track, sysres, cmd_status, wr_check


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

  alert := data >> 15
  heater := data >> 13
  rh_track := data >> 11
  t_track := data >> 10
  sysres := data >> 4
  cmd_status := data >> 1
  wr_check := data & %1
}
PUB waitforkey(message)

  ser.Str (message)
  repeat until ser.CharIn

PRI monitor_ack
'' Trialling this as a background monitor for I2C NAKs
'' - Intended to run in another cog
  repeat
    if _ackbit == i2c#NAK
      _nak++
      ser.Str (string("*** NAK - "))
      ser.Dec (_nak)
      ser.Str (string("***", ser#NL))
      _ackbit := 0

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
