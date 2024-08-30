{
----------------------------------------------------------------------------------------------------
    Filename:       SHT3x-ThreshIntDemo.spin
    Description:    Demo of the SHT3x driver
        * Threshold interrupt functionality
    Author:         Jesse Burt
    Started:        Nov 19, 2017
    Updated:        Aug 29, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

' Uncomment the two lines below to use the bytecode-based I2C engine in the driver
'#define SHT3X_I2C_BC
'#pragma exportdef(SHT3X_I2C_BC)

CON

    _clkmode        = xtal1+pll16x
    _xinfreq        = 5_000_000

' -- User-modifiable constants
    INT1            = 25                        ' ALERT pin (active high)
' --


OBJ

    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    sensor: "sensor.temp_rh.sht3x" | SCL=28, SDA=29, I2C_FREQ=400_000, I2C_ADDR=0, RST=24


VAR

    long _isr_stack[50]                         ' stack for ISR core
    long _intflag                               ' interrupt flag


PUB main() | dr, temp, rh

    setup()

    dr := 2                                     ' data rate: 0 (0.5), 1, 2, 4, 10Hz

    sensor.temp_scale(sensor.C)                 ' C, F
    sensor.rh_int_hi_thresh(25)                 ' RH hi/lo thresholds
    sensor.rh_int_lo_thresh(5)
    sensor.rh_int_hi_hyst(24)                   ' hi/lo thresh hysteresis
    sensor.rh_int_lo_hyst(6)

    sensor.temp_int_hi_thresh(30)               ' temp hi/lo thresholds
    sensor.temp_int_lo_thresh(10)
    sensor.temp_int_hi_hyst(29)                 ' hi/lo thresh hysteresis
    sensor.temp_int_lo_hyst(7)

    ser.strln(@"Set thresholds:")
    ser.printf2(@"RH Set low: %d  hi: %d\n\r",  sensor.rh_int_lo_thresh(), ...
                                                sensor.rh_int_hi_thresh())

    ser.printf2(@"RH Clear low: %d  hi: %d\n\r",    sensor.rh_int_lo_hyst(), ...
                                                    sensor.rh_int_hi_hyst())

    ser.printf2(@"Temp Set low: %d  hi: %d\n\r",    sensor.temp_int_lo_thresh(), ...
                                                    sensor.temp_int_hi_thresh())

    ser.printf2(@"Temp Clear low: %d  hi: %d\n\r",  sensor.temp_int_lo_hyst(), ...
                                                    sensor.temp_int_hi_hyst())

    repeat
        if ( dr > 0 )
            time.msleep(1000/dr)
        else
            time.msleep(2000)

        temp := sensor.temperature()
        rh := sensor.rh()

        ser.pos_xy(0, 10)

        ser.printf2(@"Temperature: %3.3d.%02.2d\n\r", (temp / 100), ||(temp // 100))
        ser.printf2(@"Relative humidity: %3.3d.%02.2d%%\n\r", (rh / 100), (rh // 100))

        if ( _intflag )
            ser.pos_xy(0, 12)
            ser.str(@"Interrupt")
        else
            ser.pos_xy(0, 12)
            ser.clear_line()


PRI isr()
' Interrupt service routine
    dira[INT1] := 0                             ' INT1 as input
    repeat
        waitpeq(|< INT1, |< INT1, 0)            ' wait for INT1 (active high)
        _intflag := 1                           '   set flag
        waitpne(|< INT1, |< INT1, 0)            ' now wait for it to clear
        _intflag := 0                           '   clear flag


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( sensor.start() )
        ser.strln(@"SHT3x driver started")
    else
        ser.strln(@"SHT3x driver failed to start - halting")
        repeat

    cognew(isr(), @_isr_stack)                  ' start ISR in another core


DAT
{
Copyright 2024 Jesse Burt

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

