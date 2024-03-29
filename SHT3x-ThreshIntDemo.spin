{
    --------------------------------------------
    Filename: SHT3x-ThreshIntDemo.spin
    Author: Jesse Burt
    Description: Demo of the SHT3x driver
        Threshold interrupt functionality
    Copyright (c) 2022
    Started Jan 8, 2022
    Updated Nov 13, 2022
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode        = cfg#_clkmode
    _xinfreq        = cfg#_xinfreq

' -- User-modifiable constants
    LED1            = cfg#LED1
    SER_BAUD        = 115_200

    { I2C configuration }
    SCL_PIN         = 28 
    SDA_PIN         = 29
    I2C_FREQ        = 1_000_000                 ' max is 1_000_000
    ADDR_BIT        = 0                         ' 0, 1: opt. I2C address bit

    RESET_PIN       = 24                        ' optional (-1 to disable)
    INT1            = 25                        ' ALERT pin (active high)
' --

' Temperature scale
    C               = 0
    F               = 1

OBJ

    cfg     : "boardcfg.flip"
    ser     : "com.serial.terminal.ansi"
    sht3x   : "sensor.temp_rh.sht3x"
    time    : "time"

VAR

    long _isr_stack[50]                         ' stack for ISR core
    long _intflag                               ' interrupt flag

PUB main{} | dr, temp, rh

    setup{}

    dr := 2                                     ' data rate: 0 (0.5), 1, 2, 4, 10Hz

    sht3x.temp_scale(C)
    sht3x.rh_int_hi_thresh(25)                  ' RH hi/lo thresholds
    sht3x.rh_int_lo_thresh(5)
    sht3x.rh_int_hi_hyst(24)                    ' hi/lo thresh hysteresis
    sht3x.rh_int_lo_hyst(6)

    sht3x.temp_int_hi_thresh(30)                ' temp hi/lo thresholds
    sht3x.temp_int_lo_thresh(10)
    sht3x.temp_int_hi_hyst(29)                  ' hi/lo thresh hysteresis
    sht3x.temp_int_lo_hyst(7)

    ser.strln(string("Set thresholds:"))
    ser.printf2(string("RH Set low: %d  hi: %d\n\r"), sht3x.rh_int_lo_thresh(-2), {
}                                                     sht3x.rh_int_hi_thresh(-2))

    ser.printf2(string("RH Clear low: %d  hi: %d\n\r"), sht3x.rh_int_lo_hyst(-2), {
}                                                       sht3x.rh_int_hi_hyst(-2))

    ser.printf2(string("Temp Set low: %d  hi: %d\n\r"), sht3x.temp_int_lo_thresh(-256), {
}                                                       sht3x.temp_int_hi_thresh(-256))

    ser.printf2(string("Temp Clear low: %d  hi: %d\n\r"), sht3x.temp_int_lo_hyst(-256), {
}                                                         sht3x.temp_int_hi_hyst(-256))

    repeat
        if (dr > 0)
            time.msleep(1000/dr)
        else
            time.msleep(2000)

        temp := sht3x.temperature{}
        rh := sht3x.rh{}

        ser.pos_xy(0, 10)

        ser.printf2(string("Temperature: %3.3d.%02.2d\n\r"), (temp / 100), ||(temp // 100))
        ser.printf2(string("Relative humidity: %3.3d.%02.2d%%\n\r"), (rh / 100), (rh // 100))

        if (_intflag)
            ser.pos_xy(0, 12)
            ser.str(string("Interrupt"))
        else
            ser.pos_xy(0, 12)
            ser.clear_line{}

PRI isr{}
' Interrupt service routine
    dira[INT1] := 0                             ' INT1 as input
    repeat
        waitpeq(|< INT1, |< INT1, 0)            ' wait for INT1 (active high)
        _intflag := 1                           '   set flag
        waitpne(|< INT1, |< INT1, 0)            ' now wait for it to clear
        _intflag := 0                           '   clear flag

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))

    if sht3x.startx(SCL_PIN, SDA_PIN, I2C_FREQ, ADDR_BIT, RESET_PIN)
        ser.strln(string("SHT3x driver started"))
    else
        ser.strln(string("SHT3x driver failed to start - halting"))
        repeat

    cognew(isr{}, @_isr_stack)                  ' start ISR in another core

DAT
{
Copyright 2022 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}

