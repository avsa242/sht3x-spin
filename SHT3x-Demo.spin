{
    --------------------------------------------
    Filename: SHT3x-Demo.spin
    Author: Jesse Burt
    Description: Interactive Demo for the Sensirion SHT3x driver
    Copyright (c) 2019
    Started Mar 10, 2018
    Updated Jan 1, 2019
    See end of file for terms of use.
    --------------------------------------------
}
CON

    _clkmode        = cfg#_clkmode  'Clock settings pulled from cfg object
    _xinfreq        = cfg#_xinfreq  ' (optionally change them manually)

    SCL_PIN         = 28            'Change these to match your I2C pin configuration
    SDA_PIN         = 29
    I2C_HZ          = 400_000       'SHT3x supports I2C FM up to 1MHz. Tested to 400kHz
    ADDR_BIT        = 0             'Can be 1 if the ADDR pin is pulled high, for alternate address

    TERM_RX         = 31            'Change these to suit your terminal settings
    TERM_TX         = 30
    TERM_BAUD       = 115_200

'Constants for demo state machine
    DISP_HELP       = 0
    DISP_TEMP_RH    = 1
    DISP_TEMP_RH_ONE= 2
    DISP_TEMP_RH_PER= 3
    DISP_SN         = 4
    DISP_STATUS     = 5
    TOGGLE_HEATER   = 6
    CLEAR_STATUS    = 7
    RESET_SHT3X     = 8
    WAIT_STATE      = 100

    STATUS_RAW      = 0
    STATUS_PARSED   = 1

OBJ

    cfg   : "core.con.boardcfg.flip"
    ser   : "com.serial.terminal"
    time  : "time"
    sht3x : "sensor.temp_rh.sht3x"

VAR

    long _ser_cog, _sht3x_cog, _keyDaemon_cog, _keyDaemon_stack[50]
    byte _demo_state, _prev_state
    long _mps
    byte _repeatability
    byte _measure_mode
    byte _disp_status_mode
    long _global_delay
    long _scale

PUB Main | rh, temp, tmp, t

    Setup
'    sht3x.SetAlerts (rh_trig_hi, rh_ok_hi, rh_ok_lo, rh_trig_lo, temp_trig_hi, temp_ok_hi, temp_ok_lo, temp_trig_lo)
    sht3x.SetAlerts (45, 42, 31, 30, 24, 22, 15, 14)
    ser.NewLine
    repeat
        case _demo_state
            CLEAR_STATUS:       ClearStatus
            DISP_HELP:          Help
            DISP_TEMP_RH_PER:   DisplayTempRH_Periodic
            DISP_TEMP_RH_ONE:   DisplayTempRH_OneShot
            DISP_SN:            DisplaySN
            DISP_STATUS:        DisplayStatus
            RESET_SHT3X:        SoftReset
            TOGGLE_HEATER:      ToggleHeater
            WAIT_STATE:         Waiting

            OTHER:
                _demo_state := DISP_HELP

PUB ClearStatus

    time.MSleep (_global_delay)
    sht3x.ClearStatus
    ser.Str (string(ser#NL, "Status register cleared", ser#NL))
    _demo_state := WAIT_STATE

PUB CycleMPS

    case _mps
        0.5:
            _mps := 1
        1:
            _mps := 2
        2:
            _mps := 4
        4:
            _mps := 10
        10:
            _mps := 0.5
        OTHER:
            _mps := 0.5

    if _demo_state == DISP_TEMP_RH_PER
        sht3x.SetPeriodicRead (_mps)

PUB CycleRepeatability

    case _repeatability
        sht3x#LOW:
            _repeatability := sht3x#MED
            sht3x.SetRepeatability (_repeatability)
        sht3x#MED:
            _repeatability := sht3x#HIGH
            sht3x.SetRepeatability (_repeatability)
        sht3x#HIGH:
            _repeatability := sht3x#LOW
            sht3x.SetRepeatability (_repeatability)
        OTHER:
            _repeatability := sht3x#LOW
            sht3x.SetRepeatability (_repeatability)

    if _demo_state == DISP_TEMP_RH_PER
        sht3x.SetPeriodicRead (_mps)

PUB DisplaySN | sn

    ser.Clear
    ser.Str (string("Sensor serial number: "))
    sn := sht3x.SerialNum
    ser.Hex (sn, 8)
    _demo_state := WAIT_STATE

PUB DisplayStatus | status_word, col

    ser.Clear
    ser.Str (string("Pending Alerts:", ser#NL))
    ser.Str (string("Heater status:", ser#NL))
    ser.Str (string("RH Tracking Alert:", ser#NL))
    ser.Str (string("T Tracking Alert:", ser#NL))
    ser.Str (string("System Reset Detected:", ser#NL))
'                    |    |    |    |    |    |
'col                 0....5....10...15...20...25
    col := 23
    repeat until _demo_state <> DISP_STATUS
        case sht3x.Alert
            FALSE:
                ser.Position (col, 0)
                ser.Str (string("NO"))
            TRUE:
                ser.Position (col, 0)
                ser.Str (string("YES"))

        case sht3x.Heater (-2)
            FALSE:
                ser.Position (col, 1)
                ser.Str (string("OFF"))
            TRUE:
                ser.Position (col, 1)
                ser.Str (string("ON"))

        case sht3x.Alert_RH
            FALSE:
                ser.Position (col, 2)
                ser.Str (string("NO"))
            TRUE:
                ser.Position (col, 2)
                ser.Str (string("YES"))

        case sht3x.Alert_Temp
            FALSE:
                ser.Position (col, 3)
                ser.Str (string("NO"))
            TRUE:
                ser.Position (col, 3)
                ser.Str (string("YES"))

        case sht3x.ResetDetected
            FALSE:
                ser.Position (col, 4)
                ser.Str (string("NO"))
            TRUE:
                ser.Position (col, 4)
                ser.Str (string("YES"))

        time.MSleep (_global_delay)

PUB DisplayTempRH_Periodic | col, t, rh, tw, tf, rhw, rhf

    sht3x.SetPeriodicRead (_mps)
    ser.Clear
'col                 0....5....10...15...20...25...30...35...40...45...50...55...60...65...
'                    |    |    |    |    |    |    |    |    |    |    |    |    |    |
    ser.Str (string("Temperature/Humidity Display (Periodic measurement mode)", ser#NL))    '0
    ser.Str (string("Hotkeys:", ser#NL))                                                    '1
    ser.Str (string("b, B: Cycle through repeatability modes", ser#NL))                     '2
    ser.Str (string("m, M: Cycle through 0.5, 1, 2, 4, 10 measurements per second", ser#NL))'3
    ser.Str (string("t, T: Switch measurement mode to One-shot", ser#NL))                   '4
    ser.Str (string(" (NOTE: At 10mps and high repeatability mode,", ser#NL,{               '5
                 }"  self-heating of the sensor may occur)", ser#NL, ser#NL))               '6
    ser.Str (string("Measurements per second:", ser#NL))                                    '8
    ser.Str (string("RH Alert pending?:", ser#NL))                                          '9
    ser.Str (string("Temp Alert pending?:", ser#NL))                                        '10
    ser.Str (string("Measurement repeatability mode:", ser#NL))                             '11
    ser.Str (string("Temp: 00.00C  00.00F  RH: 00.00%"))                                    '12
'                    |    |    |    |    |    |    |    |    |    |    |    |    |    |
'col                 0....5....10...15...20...25...30...35...40...45...50...55...60...65...
    col := 32
    repeat until _demo_state <> DISP_TEMP_RH_PER
        case _mps
            0.5:
                ser.Position (col, 8)
                ser.Str (string("0.5", ser#NL))
            OTHER:
                ser.Position (col, 8)
                ser.Dec (_mps)
                ser.Chars (32, 2)

        case sht3x.Alert_RH
            TRUE:
                ser.Position (col, 9)
                ser.Str (string("YES"))
            FALSE:
                ser.Position (col, 9)
                ser.Str (string("NO "))

        case sht3x.Alert_Temp
            TRUE:
                ser.Position (col, 10)
                ser.Str (string("YES"))
            FALSE:
                ser.Position (col, 10)
                ser.Str (string("NO "))

        ser.Position (col, 11)
        case _repeatability
            sht3x#LOW:  ser.Str (string("LOW "))
            sht3x#MED:  ser.Str (string("MED "))
            sht3x#HIGH: ser.Str (string("HIGH"))

        sht3x.FetchData
        ser.Position (6, 12)
        DecimalDot (sht3x.GetTempC)
        ser.Position (14, 12)
        DecimalDot (sht3x.GetTempF)
        ser.Position (26, 12)
        DecimalDot (sht3x.GetRH)
        time.MSleep (_global_delay)
    sht3x.Break               'Tell the sensor to break out of periodic mode
    _prev_state := DISP_TEMP_RH_PER

PUB DisplayTempRH_OneShot | col

    ser.Clear
'                    0....5....10...15...20...25...30...35...40...45...50...55...60...65...
'                    |    |    |    |    |    |    |    |    |    |    |    |    |    |
    ser.Str (string("Temperature/Humidity Display (One-shot measurement mode)", ser#NL))    '0
    ser.Str (string("Hotkeys:", ser#NL))                                                    '1
    ser.Str (string("b, B: Cycle through repeatability modes", ser#NL))                     '2
    ser.Str (string("t, T: Switch measurement mode to Periodic", ser#NL, ser#NL))           '3
    ser.Str (string("Measurement repeatability mode:", ser#NL))                             '5
    ser.Str (string("Temp: 00.00C  00.00F  RH: 00.00%"))                                    '6
'                    |    |    |    |    |    |    |    |    |    |    |    |    |    |
'col                 0....5....10...15...20...25...30...35...40...45...50...55...60...65...
    col := 32
    repeat until _demo_state <> DISP_TEMP_RH_ONE
        ser.Position (col, 5)
        case _repeatability
            sht3x#LOW: ser.Str (string("LOW", ser#NL))
            sht3x#MED: ser.Str (string("MED", ser#NL))
            sht3x#HIGH: ser.Str (string("HIGH", ser#NL))

        sht3x.ReadTempRH
        ser.Position (6, 6)
        DecimalDot (sht3x.GetTempC)
        ser.Position (14, 6)
        DecimalDot (sht3x.GetTempF)
        ser.Position (26, 6)
        DecimalDot (sht3x.GetRH)
        time.MSleep (_global_delay)

PUB Help

    ser.Clear
    ser.Str (@_help_screen)
    _demo_state := WAIT_STATE

PUB SoftReset

    time.MSleep (_global_delay)
    sht3x.SoftReset
    ser.Str (string("Sent soft-reset to SHT3x", ser#NL))
    _demo_state := WAIT_STATE

PUB ToggleHeater

    time.MSleep (_global_delay)
    case sht3x.Heater (-2)
        FALSE:
            sht3x.Heater (TRUE)
            ser.Str (string(ser#NL, "Heater enabled", ser#NL))
        OTHER:
            sht3x.Heater (FALSE)
            ser.Str (string(ser#NL, "Heater disabled", ser#NL))
    _demo_state := WAIT_STATE

PUB DecimalDot(hundredths) | whole, frac

    whole := hundredths/100
    frac := hundredths-(whole*100)
    ser.Dec (whole)
    ser.Char (".")
    if frac < 10
        ser.Dec (0)
    ser.Dec (frac)

PUB keyDaemon | key_cmd, prev_state

    repeat
        repeat until key_cmd := ser.CharIn
        case key_cmd
            "b", "B":
                case _demo_state
                    DISP_TEMP_RH_ONE..DISP_TEMP_RH_PER:
                        CycleRepeatability
                    OTHER:
            "c", "C":
                _prev_state := _demo_state
                _demo_state := CLEAR_STATUS
            "h", "H":
                _prev_state := _demo_state
                _demo_state := TOGGLE_HEATER
            "m", "M":
                case _demo_state
                    DISP_TEMP_RH_PER:
                        CycleMPS
                    OTHER:
            "n", "N":
                _prev_state := _demo_state
                _demo_state := DISP_SN
            "r", "R":
                _prev_state := _demo_state
                _demo_state := RESET_SHT3X
            "s", "S":
                _prev_state := _demo_state
                _demo_state := DISP_STATUS
            "t", "T":
                case _demo_state
                    DISP_TEMP_RH_PER:
                        _prev_state := _demo_state
                        _demo_state := DISP_TEMP_RH_ONE
                    DISP_TEMP_RH_ONE:
                        _prev_state := _demo_state
                        _demo_state := DISP_TEMP_RH_PER
                    OTHER:
                        _prev_state := _demo_state
                        _demo_state := DISP_TEMP_RH_ONE
            27:
                _demo_state := _prev_state
            OTHER:
                _prev_state := _demo_state
                _demo_state := DISP_HELP

PUB Setup

    repeat until _ser_cog := ser.StartRxTx (TERM_RX, TERM_TX, 0, TERM_BAUD)
    ser.Clear
    ser.Str (string("Serial terminal started"))
    ser.NewLine

    if _sht3x_cog := sht3x.Startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BIT)
        ser.Str (string("SHT3x object (S/N "))
        ser.Hex (sht3x.SerialNum, 8)
        ser.Str (string(") started"))
        ser.NewLine
    else
        ser.Str (string("SHT3x object failed to start - halting"))
        sht3x.Stop
        time.MSleep (500)
        ser.Stop
        flash(cfg#LED1)

    _keyDaemon_cog := cognew(keyDaemon, @_keyDaemon_stack)

    '' Establish some initial settings
    _global_delay := 100
    _mps := 0.5
    _repeatability := sht3x#LOW
    sht3x.SetRepeatability (_repeatability)
    _demo_state := WAIT_STATE

PUB Waiting

    ser.Str (string(ser#NL, "Press any key to continue (ESC to return to previous demo)..."))
    repeat until _demo_state <> WAIT_STATE

PUB flash(led_pin)

    dira[led_pin] := 1
    repeat
        !outa[led_pin]
        time.MSleep (500)

DAT

    _help_screen    byte "Keys:", ser#NL
                    byte "h, H:   Toggle Sensor built-in heater", ser#NL
                    byte "c, C:   Clear Status register", ser#NL
                    byte "n, N:   Display Sensor Serial Number", ser#NL
                    byte "r, R:   Send SHT3x Soft-Reset command", ser#NL
                    byte "s, S:   Display Status Register", ser#NL
                    byte "t, T:   Display Temperature/Relative Humidity", ser#NL
                    byte "Others: This help screen", 0

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
