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

  CMD_READ_SERIALNBR          = $3780
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

  SCL                         = 8
  SDA                         = 7
  BUS_RATE                    = 112_400'kHz/kbps

  PIX_PIN                     = 12'13
  
OBJ

  cfg   : "config.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  i2c   : "jm_i2c_fast"
  debug : "debug"
  math  : "math.float"
  fs    : "string.float"

VAR

  byte err_cnt
  long pix_array
  word temp_word
  word rh_word

PUB Main | i

  setup
  
  repeat
'    i2c.wait ( SHT31_WR)
    read_t_rh
    ser.NewLine
    time.MSleep (333)

PUB cmd(cmd_word) | ackbit, cmd_long, cmd_byte

{
  if cmd_word
    cmd_long := (SHT31_WR << 16) | cmd_word
    i2c.start
    repeat cmd_byte from 2 to 0
      i2c.write (cmd_long.byte[cmd_byte])
      ackbit := i2c.write (cmd_long.byte[cmd_byte])
      if ackbit
        return FALSE
    i2c.stop
  else
    return FALSE '564uS w/ACK, 544uS w/o ACK
}

  if cmd_word
    i2c.start
    ackbit := i2c.write (SHT31_WR)
    if ackbit
      return FALSE
    ackbit := i2c.write (cmd_word >> 8)
    if ackbit
      return FALSE
    ackbit := i2c.write (cmd_word  & $FF)
    if ackbit
      return FALSE
    i2c.stop
  else
    return FALSE '530uS

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

  cmd(CMD_READ_SERIALNBR)
  read_data := read6bytes
  ser.Hex (read_data, 8)

PUB get_t_rh | read_data, ttmp, rhtmp, temp, rh

  cmd(SHT31_MEAS_HIGHREP)
  read_data := read6bytes
  temp_word := (read_data.byte[3] << 8) | read_data.byte[2]
  rh_word := (read_data.byte[1] << 8) | read_data.byte[0]

  return read_data

PUB read_t | read_data, ttmp, temp

  get_t_rh

  ser.Str (string("Temp: "))
  't := -45 + 175 * ttmp / 65535                'Integer version
  'ser.Dec (t)
  '175.0f * (ft)rawValue / 65535.0f - 45.0f;

  temp := math.MulF (175.0, math.FloatF (temp_word))    'FP version
  temp := math.DivF (temp, 65535.0)
  temp := math.SubF (temp, 45.0)
  temp := fs.FloatToString (temp)

  ser.Str (temp)

PUB read_rh | read_data, rhtmp, rh

  get_t_rh

  ser.Str (string("RH: "))
  'rh := (100*rhtmp)/65535                      'Integer version
  'ser.Dec (rh)
  rh := math.MulF (100.0, math.FloatF (rh_word))  'FP version
  rh := math.DivF (rh, 65535.0)
  rh := fs.FloatToString (rh)
  ser.Str (rh)
  ser.NewLine

PUB read_t_rh | read_data, ttmp, temp, rhtmp, rh

  get_t_rh
  ser.Str (string("Temp: "))
  't := -45 + 175 * ttmp / 65535                'Integer version
  'ser.Dec (t)

  temp := math.MulF (175.0, math.FloatF (temp_word))    'FP version
  temp := math.DivF (temp, 65535.0)
  temp := math.AddF (temp, -45.0)
  temp := fs.FloatToString (temp)

  ser.Str (temp)

  rhtmp := (read_data.byte[1] << 8) | read_data.byte[0]

  ser.Str (string(" RH: "))
  'rh := (100*rhtmp)/65535                      'Integer version
  'ser.Dec (rh)
  rh := math.MulF (100.0, math.FloatF (rh_word))  'FP version
  rh := math.DivF (rh, 65535.0)
  rh := fs.FloatToString (rh)
  ser.Str (rh)

PUB read6bytes | ackbit, i, read_data[2], ms_word, ls_word, ms_crc, ls_crc, data

  start_read

  i2c.pread (@read_data, 6, TRUE)
  i2c.stop

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
  case compare(crc8(@ms_word, 2), ms_crc)
    FALSE:
      ser.Str (string("MSB CRC BAD! Got "))
      ser.Hex (ms_crc, 2)
      ser.Str (string(", expected "))
      ser.Hex (crc8(ms_word, 2), 2)
      ser.NewLine
      return FALSE
    OTHER:

  case compare(crc8(@ls_word, 2), ls_crc)
    FALSE:
      ser.Str (string("LSB CRC BAD! Got "))
      ser.Hex (ls_crc, 2)
      ser.Str (string(", expected "))
      ser.Hex (crc8(ls_word, 2), 2)
      ser.NewLine
      return FALSE
    OTHER:

  data := (ms_word << 16) | ls_word
  return data

PUB setup | i2c_cog

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

PUB start_read | ackbit

  i2c.start
  ackbit := i2c.write (SHT31_RD)
  i2c.stop

  if ackbit
    return FALSE

PUB check_for_sht31 | status

  ser.Str (string("Checking for SHT31 at $"))
  ser.Hex ( SHT31_DEFAULT_ADDR, 2)
  ser.Str (string("..."))

'  status := i2c.present ( SHT31_DEFAULT_ADDR)
'  i2c.stop
  status:=TRUE
  case status
    TRUE:
      ser.Str (string("found device with SN $"))
      ser.Hex (read_sn, 6)
      ser.NewLine
    OTHER:
      ser.Str (string("no response - halting", ser#NL))
      debug.LEDSlow ( cfg#LED1)

PUB read_sn : sn | i

  i2c.start
  i2c.write ( SHT31_WR)
  i2c.write ( CMD_READ_SERIALNBR >> 8)
  i2c.write ( CMD_READ_SERIALNBR & $FF)
  i2c.stop
  
  i2c.start
  i2c.write ( SHT31_RD)

{ 
  repeat i from 0 to 2
    sn.byte[2-i] := i2c.read (FALSE)
  i2c.stop
}
  sn := read_reg3
  return

PUB read_reg3 | ackbit, reg, reg_byte

    i2c.start
    ackbit := i2c.write (SHT31_RD)
  
    if ackbit
      i2c.stop
      return FALSE
    
    repeat reg_byte from 0 to 2
      reg.byte[2-reg_byte] := i2c.read (FALSE)
    i2c.stop
    
    return reg

PUB read_reg6 | ackbit, reg, reg_byte

    i2c.start
    ackbit := i2c.write (SHT31_RD)
  
    if ackbit
      i2c.stop
      return FALSE
    
    repeat reg_byte from 0 to 5
      reg.byte[5-reg_byte] := i2c.read (FALSE)
    i2c.stop
    
    return reg

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

PUB sht31_status : status | ackbit, i, readback, readcrc

  i2c.start
  i2c.write (SHT31_WR)
  i2c.write (SHT31_READSTATUS >> 8)
  i2c.write (SHT31_READSTATUS & $FF)
  i2c.stop
  
  i2c.start
  i2c.write (SHT31_RD)
'  i2c.stop
  
  repeat i from 0 to 2
    status.byte[2-i] := i2c.read (FALSE)
  i2c.stop
  
  return status
'  ser.Hex (readback, 6)
'  ser.NewLine
'  ser.Hex (readback >> 8, 4)
'  ser.NewLine
'  ser.CharIn
{  readcrc := crc8(readback >> 8, 2)
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
'  waitforkey (string("Press any key", ser#NL))
}

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
