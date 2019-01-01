{
    --------------------------------------------
    Filename: SHT3x-OLED128-Demo.spin
    Author: Jesse Burt
    Description: Simple thermometer/hygrometer demo
     on a 4DSystems uOLED-128-G2 display
    Copyright (c) 2019
    Started Jan 1, 2019
    Updated Jan 1, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode  'Clock settings pulled from cfg object
    _xinfreq    = cfg#_xinfreq  ' (optionally change them manually)

    SCL         = 28            'Change these to match your I2C pin configuration
    SDA         = 29
    SLAVE       = 0             'Can be 1 if the SHT3x ADDR pin is pulled high
    I2C_HZ      = 400_000       'SHT3x supports I2C FM up to 1MHz. Tested to 400kHz

    TERM_RX     = 31            'Change these to suit your terminal settings
    TERM_TX     = 30
    TERM_BAUD   = 115_200

    OLED_RX     = 6             'Change these to match your uOLED-128-g2 pin configuration
    OLED_TX     = 7
    OLED_RST    = 9
    OLED_BAUD   = 115_200

    FAHRENHEIT  = 0
    CELSIUS     = 1
    MODE        = FAHRENHEIT
'    MODE        = CELSIUS

OBJ

    ser     : "com.serial.terminal"
    cfg     : "core.con.client.parraldev"
    time    : "time"
    sht3x   : "sensor.temp_rh.sht3x"
    oled    : "oled-128-g2_v2.1"
    math    : "tiny.math.float"
    fs      : "string.float"

VAR

    long _ser_cog, _sht3x_cog
    long _rndseed

PUB Main | temp[2], rh[2], x, y, c, i, sn

    Setup
    sht3x.SetRepeatability (sht3x#HIGH)
    oled.ClearScreen

    repeat
        x := RND(4)
        y := RND(6)

        oled.TextWidth (2)
        oled.TextHeight (2)
        oled.TextBackgroundColor (oled.RGB (0, 0, 0))
        oled.TextForegroundColor (oled.RGB (rnd(255), rnd(255), rnd(255)))
        repeat i from 0 to 100
            sht3x.ReadTempRH
            case MODE
                CELSIUS:
                    temp := math.FDiv (math.FFloat (sht3x.GetTempC), 100.0)
                    oled.placestring (x, y, fs.FloatToString (temp), 4)
                    oled.char ("C", x+4, y)
                OTHER:
                    temp := math.FDiv (math.FFloat (sht3x.GetTempF), 100.0)
                    oled.placestring (x, y, fs.FloatToString (temp), 4)
                    oled.char ("F", x+4, y)

            rh := math.FDiv (math.FFloat (sht3x.GetRH), 100.0)
            oled.placestring (x, y + 1, fs.FloatToString (rh), 4)
            oled.char ("%", x+4, y+1)
            time.MSleep (100)
        oled.placestring (x, y, string("     "), 0)
        oled.placestring (x, y + 1, string("     "), 0)

PUB RND(upperlimit) | i
' Random method based on code by Rayman
    i := ?_rndseed
    i >>= 16
    i *= (upperlimit+1)
    i >>= 16
    return i

PUB Setup

    repeat until _ser_cog := ser.StartRxTx (TERM_RX, TERM_TX, 0, TERM_BAUD)
    ser.Clear
    ser.Str (string("Serial terminal started on cog "))
    ser.Dec (_ser_cog-1)
    ser.NewLine
    oled.start (OLED_RX, OLED_TX, OLED_RST, OLED_BAUD)
    ser.Str (string("OLED object started", ser#NL))

    ifnot _sht3x_cog := sht3x.StartX (SCL, SDA, I2C_HZ, SLAVE)
        ser.Str (string("SHT3x object failed to start...halting"))
        sht3x.Stop
        repeat
    else
        ser.Str (string("SHT3x object (S/N "))
        ser.Hex (sht3x.SerialNum, 8)
        ser.Str (string(") started on cog "))
        ser.Dec (_sht3x_cog-1)
        ser.NewLine
    
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
