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


  SHT31_DEFAULT_ADDR          = $44
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

  SCL                         = 6
  SDA                         = 7

  POLYNOMIAL                  = $31

OBJ

  cfg   : "config.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  i2c   : "jm_i2c"
  crcr  : "crc"

PUB Main | s, i, dt

  ser.Start (115_200)
  ser.Clear
  ser.Str (string("Press any key..."))
  repeat until ser.CharIn
  ser.Clear
  
  dt := $BEEF
  
  ser.Hex (crc8(@dt, 2), 2)
  repeat

  i2c.setupx (SCL, SDA)
  
  repeat
    i2c.start
    i2c.write (SHT31_DEFAULT_ADDR)
    i2c.write (SHT31_READSTATUS)
    i2c.stop
    i2c.start
    s := i2c.read (i2c#ACK)
    ser.Hex (s, 2)
    time.MSleep (500)

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
