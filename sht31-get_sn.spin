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
  time.MSleep (50)
'  i2c.stop

  repeat
    get_sn
    ser.NewLine
    time.MSleep (333)
    
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
  
PUB get_sn | ackbit, i, readback, readcrc, sn
'00A4185F
  i2c.start
  ackbit := i2c.write (SHT31_WR)
  if ackbit
    return FALSE
  ackbit := i2c.write (CMD_READ_SERIALNBR >> 8)
  if ackbit
    return FALSE
  ackbit := i2c.write (CMD_READ_SERIALNBR & $FF)
  if ackbit
    return FALSE
  i2c.stop
  
  i2c.start
  ackbit := i2c.write (SHT31_RD)
  i2c.stop

  if ackbit
    return FALSE
    
{  repeat i from 0 to 3
    sn.byte[3-i] := i2c.read (FALSE)
    'ackbit := ser.Hex (i2c.read(FALSE), 2)
    ser.NewLine
    ser.Str (string("ackbit: "))
    ser.Dec (ackbit)
    if ackbit
      abort
}
  sn.byte[3] := i2c.read (FALSE)
  sn.byte[2] := i2c.read (FALSE)
  i2c.read (FALSE)
  sn.byte[1] := i2c.read (FALSE)
  sn.byte[0] := i2c.read (FALSE)
  i2c.read (TRUE)
  i2c.stop
 
  ser.NewLine
  ser.Hex (sn, 8)
  ser.NewLine
'  return sn

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
