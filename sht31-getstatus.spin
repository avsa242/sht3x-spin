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
  BUS_RATE                    = 100_000'108_150'kHz/kbps

  REDLED                      = 14'15
  GREENLED                    = 13'14
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

PUB Main | i

  setup

  i2c.stop

  repeat
    ser.Hex (get_status, 6)
    ser.NewLine
    time.MSleep (500)

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
    debug.LEDSlow (REDLED)
  
  check_for_sht31

PUB check_for_sht31 | status

  ser.Str (string("Checking for SHT31 at $"))
  ser.Hex ( SHT31_DEFAULT_ADDR, 2)
  ser.Str (string("..."))

  status := i2c.present ( SHT31_DEFAULT_ADDR)
  i2c.stop
  case status
    TRUE:
      ser.Str (string("found"))
      ser.NewLine
    OTHER:
      ser.Str (string("no response - halting", ser#NL))
      debug.LEDSlow ( REDLED)

PUB get_status: status | ackbit, i, readback, readcrc

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
