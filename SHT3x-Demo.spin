{
    --------------------------------------------
    Filename: SHT3x-Demo.spin
    Author: Jesse Burt
    Description: Interactive Demo for the Sensirion SHT3x driver
    Copyright (c) 2018
    See end of file for terms of use.
    --------------------------------------------
}

CON

  _clkmode = cfg#_clkmode
  _xinfreq = cfg#_xinfreq

  SCL     = 6
  SDA     = 5
  SLAVE   = $44
  I2C_HZ  = 100_000

'Constants for demo state machine
  DISP_HELP           = 0
  DISP_TEMP_RH        = 1
  DISP_TEMP_RH_PER    = 2
  DISP_SN             = 3
  DISP_STATUS         = 4
  DISP_STATUS_PARSED  = 5
  TOGGLE_HEATER       = 6
  CLEAR_STATUS        = 7
  RESET_SHT3X         = 8
  WAIT_STATE          = 100

OBJ

  cfg   : "core.con.client.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  sht3x : "sensor.temp_rh.sht3x"

VAR

  long _keyDaemon_cog, _keyDaemon_stack[100]
  byte _demo_state, _prev_state
  long _mps
  byte _repeatability

PUB Main | t, rh, i

  Setup

  repeat
    case _demo_state
      CLEAR_STATUS:       ClearStatus
      DISP_HELP:          Help
      DISP_TEMP_RH:       DisplayTempRH_OneShot
      DISP_TEMP_RH_PER:   DisplayTempRH_Periodic
      DISP_SN:            DisplaySN
      DISP_STATUS:        DisplayStatusRaw
      DISP_STATUS_PARSED: DisplayStatusParsed
      RESET_SHT3X:        SoftReset
      TOGGLE_HEATER:      ToggleHeater
      WAIT_STATE:         Waiting

      OTHER:
        _demo_state := DISP_HELP

PUB Help

  ser.Clear
  ser.Str (string("Keys: ", ser#NL, ser#NL))
  ser.Str (string("/, ?:    This help screen", ser#NL))
  ser.Str (string("h, H:    Toggle Sensor built-in heater", ser#NL))
  ser.Str (string("c, C:    Clear Status register", ser#NL))
  ser.Str (string("n, N:    Display Sensor Serial Number", ser#NL))
  ser.Str (string("r, R:    Send SHT3x Soft-Reset command", ser#NL))
  ser.Str (string("s, S:    Display Status Register (toggle between raw/parsed)", ser#NL))
  ser.Str (string("t, T:    Display Temperature/Relative Humidity", ser#NL))

  repeat until _demo_state <> DISP_HELP

PUB Setup

  ser.Start (115_200)
  sht3x.Start (SCL, SDA, I2C_HZ, SLAVE)
  _keyDaemon_cog := cognew(keyDaemon, @_keyDaemon_stack)
  _repeatability := sht3x#LOW
  sht3x.SetRepeatability (_repeatability)
  _mps := 0.5

PUB ClearStatus

  time.MSleep (333)
  sht3x.ClearStatus
  ser.Str (string(ser#NL, "Status register cleared", ser#NL))
  _demo_state := WAIT_STATE

PUB CycleMPS

  case _mps
    0.5:
      _mps := 1
      sht3x.PeriodicRead (_mps)
    1:
      _mps := 2
      sht3x.PeriodicRead (_mps)
    2:
      _mps := 4
      sht3x.PeriodicRead (_mps)
    4:
      _mps := 10
      sht3x.PeriodicRead (_mps)
    10:
      _mps := 0.5
      sht3x.PeriodicRead (_mps)
    OTHER:
      _mps := 0.5
      sht3x.PeriodicRead (_mps)

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

PUB DisplaySN | sn

  repeat until _demo_State <> DISP_SN
    ser.Clear
    sn := sht3x.GetSN
    ser.Str (string("Sensor serial number: "))
    ser.Hex (sn, 8)
    time.MSleep (333)

PUB DisplayStatusParsed | status_word

  repeat until _demo_state <> DISP_STATUS_PARSED
    ser.Clear
    ser.Str (string("Status register (parsed):", ser#NL, ser#NL))
    ser.Str (string("Pending Alerts       : "))
    case sht3x.GetAlertStatus
      FALSE:  ser.Str (string("           NO"))
      TRUE:   ser.Str (string("          YES"))
    ser.NewLine
    ser.Str (string("Heater status        : "))
    case sht3x.GetHeaterStatus
      FALSE:  ser.Str (string("          OFF"))
      TRUE:   ser.Str (string("           ON"))
    ser.NewLine
    ser.Str (string("RH Tracking Alert    : "))
    case sht3x.GetRHTrack_Alert
      FALSE:  ser.Str (string("           NO"))
      TRUE:   ser.Str (string("          YES"))
    ser.NewLine
    ser.Str (string("T Tracking Alert     : "))
    case sht3x.GetTempTrack_Alert
      FALSE:  ser.Str (string("           NO"))
      TRUE:   ser.Str (string("          YES"))
    ser.NewLine
    ser.Str (string("System Reset Detected: "))
    case sht3x.GetResetStatus
      FALSE:  ser.Str (string("           NO"))
      TRUE:   ser.Str (string("          YES"))
    ser.NewLine
    ser.Str (string("Command Status       : "))
    case sht3x.GetLastCmdStatus
      FALSE:  ser.Str (string("   SUCCESSFUL"))
      TRUE:   ser.Str (string("NOT PROCESSED"))
    ser.NewLine
    ser.Str (string("Last write CRC status: "))
    case sht3x.GetLastCRCStatus
      FALSE:  ser.Str (string("  CRC CORRECT"))
      TRUE:   ser.Str (string("CRC INCORRECT"))
    ser.NewLine
    time.MSleep (333)

PUB DisplayStatusRaw | status_word

  repeat until _demo_state <> DISP_STATUS
    ser.Clear
    status_word := sht3x.GetStatus
    ser.Str (string("Status word: "))
    ser.Hex (status_word, 4)
    time.MSleep (333)

PUB DisplayTempRH_OneShot | t, rh, tw, tf, rhw, rhf

  repeat until _demo_state <> DISP_TEMP_RH
    ser.Clear
    ser.Str (string("Temperature/Humidity Display (One-shot measurement mode)", ser#NL))
    ser.Str (string("Hotkeys:", ser#NL))
    ser.Str (string("b, B: Cycle through repeatability modes", ser#NL))
    ser.Str (string("t, T: Switch measurement mode to Periodic", ser#NL, ser#NL))
    ser.Str (string("Measurement repeatability mode: "))
    case _repeatability
      sht3x#LOW: ser.Str (string("LOW", ser#NL))
      sht3x#MED: ser.Str (string("MED", ser#NL))
      sht3x#HIGH: ser.Str (string("HIGH", ser#NL))
    sht3x.ReadTempRH
    ser.Str (string("Temp: "))
    DecimalDot (sht3x.GetTempC)
    ser.Str (string("C   RH: "))
    DecimalDot (sht3x.GetRH)
    ser.Char ("%")
    time.MSleep (333)

PUB DisplayTempRH_Periodic

  sht3x.PeriodicRead (_mps)

  repeat until _demo_state <> DISP_TEMP_RH_PER
    ser.Clear
    ser.Str (string("Temperature/Humidity Display (Periodic measurement mode)", ser#NL))
    ser.Str (string("Hotkeys:", ser#NL))
    ser.Str (string("b, B: Cycle through repeatability modes", ser#NL))
    ser.Str (string("m, M: Cycle through 0.5, 1, 2, 4, 10 measurements per second", ser#NL))
    ser.Str (string("t, T: Switch measurement mode to One-shot", ser#NL, ser#NL))
    ser.Str (string("Measurements per second: "))
    case _mps
      0.5: ser.Str (string("0.5", ser#NL))
      OTHER:
        ser.Dec (_mps)
        ser.NewLine
    ser.Str (string("Measurement repeatability mode: "))

    case _repeatability
      sht3x#LOW: ser.Str (string("LOW", ser#NL))
      sht3x#MED: ser.Str (string("MED", ser#NL))
      sht3x#HIGH: ser.Str (string("HIGH", ser#NL))

    sht3x.FetchData
    if _repeatability == sht3x#HIGH and _mps == 10
      ser.Str (string("*** NOTE: At the current settings, some self-heating of the sensor may occur, per Sensirion data sheet.", ser#NL))
    ser.Str (string("Temp: "))
    DecimalDot (sht3x.GetTempC)
    ser.Str (string("C   RH: "))
    DecimalDot (sht3x.GetRH)
    ser.Char ("%")
    time.MSleep (100)
  sht3x.Break               'Tell the sensor to break out of periodic mode

PUB DecimalDot(hundreths) | whole, frac

  whole := hundreths/100
  frac := hundreths-(whole*100)
  ser.Dec (whole)
  ser.Char (".")
  if frac < 10
    ser.Dec (0)
  ser.Dec (frac)

PUB SoftReset

  time.MSleep (333)
  sht3x.SoftReset
  ser.Str (string("Sent soft-reset to SHT3x", ser#NL))
  _demo_state := WAIT_STATE

PUB ToggleHeater

  time.MSleep (333)
  case sht3x.GetHeaterStatus
    FALSE:
      sht3x.SetHeater (TRUE)
      ser.Str (string(ser#NL, "Heater enabled", ser#NL))
    OTHER:
      sht3x.SetHeater (FALSE)
      ser.Str (string(ser#NL, "Heater disabled", ser#NL))
  _demo_state := WAIT_STATE

PUB Waiting

  ser.Str (string(ser#NL, "Press any key to continue (ESC to return to previous demo)..."))
  repeat until _demo_state <> WAIT_STATE

PUB keyDaemon | key_cmd, prev_state

  repeat
    repeat until key_cmd := ser.CharIn
    case key_cmd
      "/", "?": _demo_state := DISP_HELP
      "m", "M":
        case _demo_state
          DISP_TEMP_RH_PER:
            CycleMPS
          OTHER:
      "b", "B":
        case _demo_state
          DISP_TEMP_RH, DISP_TEMP_RH_PER:
            CycleRepeatability
          OTHER:
      "t", "T":
        case _demo_state
          DISP_TEMP_RH: _demo_state := DISP_TEMP_RH_PER
          OTHER:        _demo_state := DISP_TEMP_RH
      "n", "N": _demo_state := DISP_SN
      "r", "R":
        _prev_state := _demo_state
        _demo_state := RESET_SHT3X
      "s", "S":
        case _demo_state
          DISP_STATUS:  _demo_state := DISP_STATUS_PARSED
          OTHER:        _demo_state := DISP_STATUS
      "c", "C":
        _prev_state := _demo_state
        _demo_state := CLEAR_STATUS
      "h", "H":
        _prev_state := _demo_state
        _demo_state := TOGGLE_HEATER
      27: _demo_state := _prev_state
      OTHER   : _demo_state := DISP_HELP

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
