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
  WRITE_BIT                   = %0000_0000
  READ_BIT                    = %0000_0001
  SHT31_WR                    = SHT31_DEFAULT_ADDR | WRITE_BIT
  SHT31_RD                    = SHT31_DEFAULT_ADDR | READ_BIT

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
  BUS_RATE                    = 100_000'108_150'kHz/kbps

OBJ

  cfg   : "config.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  i2c   : "jm_i2c_fast"
  debug : "debug"

PUB Main | i

  setup

  repeat
    get_sn
    ser.NewLine
    time.MSleep (333)

PUB compare(b1, b2)

  return b1 == b2

PUB setup | i2c_cog

  ser.Start (115_200)
  ser.Clear
  
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

PUB cmd(cmd_word) | ackbit

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
    return FALSE

PUB start_read | ackbit

  i2c.start
  ackbit := i2c.write (SHT31_RD)
  i2c.stop

  if ackbit
    return FALSE

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

PUB get_sn | ackbit, i, snh, snl, read_data[2], crch, crcl

  cmd(CMD_READ_SERIALNBR)
  read_data := read6bytes
  ser.Hex (read_data, 8)

PUB crc8(ptr_data, len): crc | currbyte, i, j

  crc := $FF                                      'Initialize CRC with $FF
  repeat j from 0 to len-1
    currbyte := byte[ptr_data][(len-1)-j]             'Byte 'retrieval' is done reverse of the loop because bytes are organized LSB-first
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
