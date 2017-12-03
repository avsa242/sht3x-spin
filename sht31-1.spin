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


  SHT31_DEFAULT_ADDR          = $88
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

  SCL                         = 7
  SDA                         = 6

  POLYNOMIAL                  = $31

VAR

  long _i2caddr
  long _temp, _humidity

OBJ

  cfg   : "config.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  i2c   : "jm_i2c_fast"
  crcr  : "crc"

PUB Main | t, h, s

  ser.Start (115_200)
  ser.Clear
  ser.Str (string("Press any key..."))
  repeat until ser.CharIn
  ser.Clear
  
  begin(SHT31_DEFAULT_ADDR)
  
  repeat
  
    ser.Str (string("SHT31 status: $"))
    ser.Hex (readStatus, 4)
    ser.NewLine
    
    case t := readTemperature
      FALSE:
        ser.Str (string("Failed to read temperature", ser#NL))
      OTHER:
        ser.Str (string("Temp *C = "))
        ser.Dec (t)
        ser.NewLine
      
    case h := readHumidity
      FALSE:
        ser.Str (string("Failed to read humidity", ser#NL))
      OTHER:
        ser.Str (string("Hum. % = "))
        ser.Dec (h)
        ser.NewLine
    time.MSleep (1000)

PUB begin (i2caddr)

  i2c.setupx (SCL, SDA, 40_000)
  _i2caddr := i2caddr
  reset
  return TRUE

PUB readStatus | stat

  write(SHT31_READSTATUS)
  'Wire.requestFrom(_i2caddr, (uint8_t)3);
  stat := i2c.read (i2c#ACK)
  stat <<= 8
  stat |= i2c.read (i2c#ACK)
  i2c.read (i2c#ACK)
  return stat
  
PUB reset

  write(SHT31_SOFTRESET)
  time.MSleep (10)

PUB heater(h)

  if h
    write(SHT31_HEATEREN)
  else
    write(SHT31_HEATERDIS)

PUB readTemperature

  if (!readTempHum)
    return FALSE
  else
    return _temp 'XXX

PUB readHumidity

  if (!readTempHum)
    return FALSE
  else
    return _humidity 'XXX

PUB readTempHum | readbuffer[2], i, ST, SRH, stemp, shum, temp

  write(SHT31_MEAS_HIGHREP)
  
  time.MSleep (500)
  repeat i from 1 to 6
    readbuffer.byte[i-1] := i2c.read (i2c#ACK)
    ser.Hex (readbuffer.byte[i-1], 2)

  ST := readbuffer.byte[0]
  ST <<= 8
  ST |= readbuffer.byte[1]
  
  if readbuffer.byte[2] <> crc8(readbuffer, 2)
    return false
  
  SRH := readbuffer.byte[3]
  SRH <<= 8
  SRH |= readbuffer.byte[4]
  
  if readbuffer.byte[5] <> crc8(readbuffer+3, 2)
    return false
  
  stemp := ST
  stemp *= 175
  stemp /= $ffff
  stemp := -45 + stemp
  _temp := stemp
  
  shum := SRH
  shum *= 100
  shum /= $ffff
  
  _humidity := shum
  
  return TRUE

PUB write(cmd)

  i2c.start
    i2c.write (_i2caddr)
    i2c.write (cmd >> 8)
    i2c.write (cmd & $FF)
  i2c.stop

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
