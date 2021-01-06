{
    --------------------------------------------
    Filename: SHT3x-Demo.spin
    Author: Jesse Burt
    Description: Demo of the SHT3x driver
    Copyright (c) 2021
    Started Mar 10, 2018
    Updated Jan 6, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode        = cfg#_clkmode
    _xinfreq        = cfg#_xinfreq

' -- User-modifiable constants
    LED             = cfg#LED1
    SER_BAUD        = 115_200

    SCL_PIN         = 28
    SDA_PIN         = 29
    ADDR_BIT        = 0                         ' 0, 1: opt. slave address
    I2C_HZ          = 1_000_000                 ' max is 1_000_000
' --

' Temperature scale
    C               = 0
    F               = 1

OBJ

    cfg     : "core.con.boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    sht3x   : "sensor.temp_rh.sht3x.i2c"
    int     : "string.integer"
    time    : "time"

PUB Main{} | temp, rh

    setup{}

    sht3x.tempscale(C)

    repeat
        ser.position(0, 3)

        ser.str(string("Temperature: "))
        decimal(sht3x.temperature{}, 100)
        ser.newline{}

        ser.str(string("Relative humidity: "))
        decimal(sht3x.humidity{}, 100)
        ser.newline{}

        time.msleep (1000)

PRI Decimal(scaled, divisor) | whole[4], part[4], places, tmp, sign
' Display a scaled up number as a decimal
'   Scale it back down by divisor (e.g., 10, 100, 1000, etc)
    whole := scaled / divisor
    tmp := divisor
    places := 0
    part := 0
    sign := 0
    if scaled < 0
        sign := "-"
    else
        sign := " "

    repeat
        tmp /= 10
        places++
    until tmp == 1
    scaled //= divisor
    part := int.deczeroed(||(scaled), places)

    ser.char(sign)
    ser.dec(||(whole))
    ser.char(".")
    ser.str(part)

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if sht3x.startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BIT)
        ser.strln(string("SHT3x driver started"))
    else
        ser.strln(string("SHT3x driver failed to start - halting"))
        repeat

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
