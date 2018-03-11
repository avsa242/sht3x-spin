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

  SCL     = 6
  SDA     = 5
  SLAVE   = $44
  RESET   = -1
  ALERT   = -1
  I2C_HZ  = 100_000

OBJ

  cfg   : "core.con.client.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  sht31 : "sensor.temp_rh.sht31"

VAR


PUB Main

  ser.Start (115_200)
  sht31.Start (SCL, SDA, I2C_HZ, SLAVE, RESET, ALERT)'I2C_SCL, I2C_SDA, I2C_ADDR, RESET, ALERT)

  ser.Clear
  repeat
    ser.Str (string("SN "))
    ShowSN
    ser.Str (string(": "))
    ShowTempRH
    ser.NewLine
    time.MSleep (333)

PUB ShowSN | sn

  sn := sht31.GetSN
  ser.Hex (sn, 8)

PUB ShowTempRH | t, rh, tw, tf, rhw, rhf

  sht31.GetTempRH (sht31#LOW)
  t := sht31.GetTempC
  rh := sht31.GetRH
  DecimalDot (t)
  ser.Str (string("C  "))
  DecimalDot (rh)
  ser.Char ("%")

PUB DecimalDot(hundreths) | whole, frac

  whole := hundreths/100
  frac := hundreths-(whole*100)
  ser.Dec (whole)
  ser.Char (".")
  ser.Dec (frac)

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
