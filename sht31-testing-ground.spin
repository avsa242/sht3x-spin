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
  SHT31_MEAS_HIGHREP_STRETCH  = $2C06
  SHT31_MEAS_MEDREP_STRETCH   = $2C0D
  SHT31_MEAS_LOWREP_STRETCH   = $2C10
  SHT31_MEAS_HIGHREP          = $2400
  SHT31_MEAS_MEDREP           = $240B
  SHT31_MEAS_LOWREP           = $2416
  SHT31_READSTATUS            = $F32D
  SHT31_CLEARSTATUS           = $3041
  SHT31_SOFTRESET             = $30A2
  SHT31_HEATEREN              = $306D
  SHT31_HEATERDIS             = $3066

  POLYNOMIAL                  = $31

  SCL                         = 7
  SDA                         = 6
  BUS_RATE                    = 100_000'108_150'kHz/kbps

  RED                         = 15
  GREEN                       = 14
  BLUE                        = 13
  YELLOW                      = 12
  
OBJ

  cfg   : "config.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  i2c   : "jm_i2c_fast"
  debug : "debug"

VAR

  byte err_cnt

PUB Main | i

  setup
  
  check_for_sht31
  
'  waitforkey (string("sht31_clearstatus", ser#NL))

'  sht31_cmd( SHT31_CLEARSTATUS)
  i2c.stop

'  waitforkey(string("Press key to reset...", ser#NL))
'  sht31_soft_reset

'  waitforkey (string("sht31_status", ser#NL))

'  repeat i from 1 to 3
'    ser.Dec (i)
'    ser.Str (string(" status read"))
'  if sht31_status
'    ser.Str (string("NAK"))
'    debug.LEDSlow (RED)

'  time.MSleep (100)
'  i2c.stop
'  waitforkey(string("Press key to start reading...", ser#NL))
  
  repeat
    sht31_bare
    time.MSleep (250)

PUB sht31_cmd(cmd) | ackbit

  if cmd
    i2c.start
    ackbit := i2c.write (SHT31_WR)
    if ackbit
      return FALSE
    ackbit := i2c.write (cmd >> 8)
    if ackbit
      return FALSE
    ackbit := i2c.write (cmd & $FF)
    if ackbit
      return FALSE
  else
    return FALSE

PUB setup | i2c_cog

  ser.Start (115_200)
  ser.Clear
  
  dira[YELLOW..RED] := 1
  outa[YELLOW..RED] := 0

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
    debug.LEDSlow (RED)

PUB check_for_sht31 | status

  ser.Str (string("Checking for SHT31 at $"))
  ser.Hex ( SHT31_DEFAULT_ADDR, 2)
  ser.Str (string("..."))

  status := i2c.present ( SHT31_DEFAULT_ADDR)
  i2c.stop
  case status
    TRUE:
      ser.Str (string("found", ser#NL))
    OTHER:
      ser.Str (string("no response - halting", ser#NL))
      debug.LEDSlow ( RED)

PUB sht31_bare | ackbit, i, readback[2], t, ttmp, read_t_crc, expected_t_crc, rh, rhtmp, read_rh_crc, expected_rh_crc

'  i2c.wait ( SHT31_WR)
  i2c.start
  ackbit := i2c.write ( SHT31_WR)
  ackbit := i2c.write ( SHT31_MEAS_HIGHREP >> 8)
  ackbit := i2c.write ( SHT31_MEAS_HIGHREP & $FF)
  i2c.stop

  i2c.start
  ackbit := i2c.write ( SHT31_RD)
  i2c.stop

  if ackbit
    return FALSE 'Don't bother reading if there's no data ready from the sensor

'  i2c.start
'  ackbit := i2c.write ( SHT31_RD)
'  i2c.stop

'  if ackbit
'    return FALSE 'Don't bother reading if there's no data ready from the sensor

  repeat i from 0 to 5
    readback.byte[i] := i2c.read (FALSE)
  i2c.stop
  
  ttmp := (readback.byte[0] << 8) | readback.byte[1]
  read_t_crc := readback.byte[2]
  expected_t_crc := crc8(@ttmp, 2)

  rhtmp := (readback.byte[3] << 8) | readback.byte[4]
  read_rh_crc := readback.byte[5]
  expected_rh_crc := crc8(@rhtmp, 2)

  repeat i from 0 to 5
    ser.Hex (readback.byte[i], 2)
    ser.Char (" ")

  ser.Str (string(" Temp: "))
  t := -45 + 175 * ttmp / 65535
  ser.Dec (t)
  ser.Str (string("  RH: "))
  rh := (100*rhtmp)/65535
  ser.Dec (rh)
  ser.NewLine
    
  case compare(read_t_crc, expected_t_crc)
    FALSE:
      err
      err_cnt++
      ser.Str (string("Bad Temp CRC - Got "))
      ser.Hex (read_t_crc, 2)
      ser.Str (string(", expected "))
      ser.Hex (expected_t_crc, 2)
      ser.NewLine
    OTHER:
      good

  case compare(read_rh_crc, expected_rh_crc)
    FALSE:
      err
      err_cnt++
      ser.Str (string("Bad RH CRC - Got "))
      ser.Hex (read_rh_crc, 2)
      ser.Str (string(", expected "))
      ser.Hex (expected_rh_crc, 2)
      ser.NewLine
    OTHER:
      good

  if err_cnt >50
    err_cnt := 0
    ser.Str (string("Too many errors - soft reset", ser#NL))
    sht31_soft_reset
    time.MSleep (1000)

PUB sht31_soft_reset | ackbit

  i2c.start
  ackbit := i2c.write ( SHT31_WR)
  if ackbit
    return false
  ackbit := i2c.write ( SHT31_SOFTRESET >> 8)
  if ackbit
    return false
  ackbit := i2c.write ( SHT31_SOFTRESET & $FF)
  if ackbit
    return false
  i2c.stop

PUB sht31_status | ackbit, i, readback, readcrc

  i2c.start
  ackbit := i2c.write (SHT31_WR)
  if ackbit
    return FALSE
  ackbit := i2c.write (SHT31_READSTATUS >> 8)
  if ackbit
    return FALSE
  ackbit := i2c.write (SHT31_READSTATUS & $FF)
  if ackbit
    return FALSE
  i2c.stop
  
  i2c.start
  ackbit := i2c.write (SHT31_RD)
  if ackbit
    return FALSE
  i2c.stop
  
  repeat i from 0 to 2
    readback.byte[2-i] := i2c.read (FALSE)
  i2c.stop
  ser.Hex (readback, 6)
  ser.NewLine
'  waitforkey (string("Read 3 bytes...", ser#NL))
  
  readcrc := crc8({readback >> 8}$0040 , 2)
  if readcrc == readback.byte[0]
    ser.Str (string("CRC GOOD - "))
  else
    ser.Str (string("CRC BAD - "))
  ser.Hex (readcrc, 2)
  ser.Char ("/")
  ser.Hex (readback.byte[0], 2)
  ser.Str (string(": "))
  ser.Hex (readback, 6)
  ser.NewLine
  waitforkey (string("Press any key", ser#NL))

PUB sht31_read

  i2c.start
  i2c.write (SHT31_RD)
  i2c.stop

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
PUB compare(b1, b2) | c

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

PUB err

  dira[GREEN]~~
  outa[GREEN]~
  dira[RED]~~
  outa[RED]~~
  
PUB good

  dira[RED]~~
  outa[RED]~
  dira[GREEN]~~
  outa[GREEN]~~

PUB waitforkey(message)

  ser.Str (message)
  repeat until ser.CharIn

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
