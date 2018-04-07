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

  _clkmode = cfg#_clkmode           'Clock settings pulled from cfg object
  _xinfreq = cfg#_xinfreq           ' (optionally change them manually)

  SCL                 = 6           'Change these to match your I2C pin configuration
  SDA                 = 5
  SLAVE               = $44         'Can be $45 if the ADDR pin is pulled high
  I2C_HZ              = 100_000     'SHT3x supports I2C FM up to 1MHz. Tested to ~530kHz

  TERM_RX             = 31          'Change these to suit your terminal settings
  TERM_TX             = 30
  TERM_BAUD           = 115_200

'Constants for demo state machine
  DISP_HELP           = 0
  DISP_TEMP_RH        = 1
  DISP_TEMP_RH_PER    = 2
  DISP_SN             = 3
  DISP_STATUS         = 4
  TOGGLE_HEATER       = 5
  CLEAR_STATUS        = 6
  RESET_SHT3X         = 7
  WAIT_STATE          = 100

  MEAS_MODE_ONESHOT   = 0
  MEAS_MODE_PERIODIC  = 1

  STATUS_RAW          = 0
  STATUS_PARSED       = 1

OBJ

  cfg   : "core.con.client.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  sht3x : "sensor.temp_rh.sht3x"

VAR

  long _ser_cog, _sht3x_cog, _keyDaemon_cog, _keyDaemon_stack[100]
  byte _demo_state, _prev_state
  long _mps
  byte _repeatability
  byte _measure_mode
  byte _disp_status_mode
  long _global_delay

PUB Main

  Setup

  repeat
    case _demo_state
      CLEAR_STATUS:       ClearStatus
      DISP_HELP:          Help
      DISP_TEMP_RH:       DisplayTempRH
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
      sht3x.SetPeriodicRead (_mps)
    1:
      _mps := 2
      sht3x.SetPeriodicRead (_mps)
    2:
      _mps := 4
      sht3x.SetPeriodicRead (_mps)
    4:
      _mps := 10
      sht3x.SetPeriodicRead (_mps)
    10:
      _mps := 0.5
      sht3x.SetPeriodicRead (_mps)
    OTHER:
      _mps := 0.5
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

PUB DisplaySN | sn

  repeat until _demo_State <> DISP_SN
    ser.Clear
    sn := sht3x.GetSN
    ser.Str (string("Sensor serial number: "))
    ser.Hex (sn, 8)
    time.MSleep (_global_delay)

PUB DisplayStatus | status_word

  repeat until _demo_state <> DISP_STATUS
    case _disp_status_mode
      STATUS_PARSED:
        ser.Clear
        ser.Str (string("Status register (parsed):", ser#NL, ser#NL))
        ser.Str (string("Pending Alerts       : "))
        case sht3x.IsAlertPending
          FALSE:  ser.Str (string("           NO"))
          TRUE:   ser.Str (string("          YES"))
        ser.NewLine
        ser.Str (string("Heater status        : "))
        case sht3x.GetHeaterStatus
          FALSE:  ser.Str (string("          OFF"))
          TRUE:   ser.Str (string("           ON"))
        ser.NewLine
        ser.Str (string("RH Tracking Alert    : "))
        case sht3x.IsRHTrack_Alert
          FALSE:  ser.Str (string("           NO"))
          TRUE:   ser.Str (string("          YES"))
        ser.NewLine
        ser.Str (string("T Tracking Alert     : "))
        case sht3x.IsTempTrack_Alert
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
        time.MSleep (_global_delay)
      STATUS_RAW:
        ser.Clear
        status_word := sht3x.GetStatus
        ser.Str (string("Status word: "))
        ser.Hex (status_word, 4)
        time.MSleep (_global_delay)
      OTHER:
        _disp_status_mode := STATUS_RAW

PUB DisplayTempRH | t, rh, tw, tf, rhw, rhf

  repeat until _demo_state <> DISP_TEMP_RH
    case _measure_mode
      MEAS_MODE_PERIODIC:
        sht3x.SetPeriodicRead (_mps)
        repeat until _measure_mode <> MEAS_MODE_PERIODIC OR _demo_state <> DISP_TEMP_RH
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
          if sht3x.IsRHTrack_Alert
            ser.Str (string("*** Alert Pending: Humidity *** ", ser#NL))
          if sht3x.IsTempTrack_Alert
            ser.Str (string("*** Alert Pending: Temperature *** ", ser#NL))

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
          ser.Str (string("C   "))
          DecimalDot (sht3x.GetTempF)
          ser.Str (string("F   RH: "))
          DecimalDot (sht3x.GetRH)
          ser.Char ("%")
          time.MSleep (100)
        sht3x.Break               'Tell the sensor to break out of periodic mode

      OTHER:
        repeat until _measure_mode <> MEAS_MODE_ONESHOT OR _demo_state <> DISP_TEMP_RH
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
          ser.Str (string("C   "))
          DecimalDot (sht3x.GetTempF)
          ser.Str (string("F   RH: "))
          DecimalDot (sht3x.GetRH)
          ser.Char ("%")
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
  case sht3x.GetHeaterStatus
    FALSE:
      sht3x.SetHeater (TRUE)
      ser.Str (string(ser#NL, "Heater enabled", ser#NL))
    OTHER:
      sht3x.SetHeater (FALSE)
      ser.Str (string(ser#NL, "Heater disabled", ser#NL))
  _demo_state := WAIT_STATE

PRI DecimalDot(hundredths) | whole, frac

  whole := hundredths/100
  frac := hundredths-(whole*100)
  ser.Dec (whole)
  ser.Char (".")
  if frac < 10
    ser.Dec (0)
  ser.Dec (frac)

PRI keyDaemon | key_cmd, prev_state

  repeat
    repeat until key_cmd := ser.CharIn
    case key_cmd
      "b", "B":
        case _demo_state
          DISP_TEMP_RH:
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
          DISP_TEMP_RH:
            CycleMPS
          OTHER:
      "n", "N":
        _prev_state := _demo_state
        _demo_state := DISP_SN
      "r", "R":
        _prev_state := _demo_state
        _demo_state := RESET_SHT3X
      "s", "S":
        case _demo_state
          DISP_STATUS:  _disp_status_mode ^= 1      'Flip status reg display mode
          OTHER:
            _prev_state := _demo_state
            _demo_state := DISP_STATUS
      "t", "T":
        case _demo_state
          DISP_TEMP_RH: _measure_mode ^= 1          'Flip measurement mode
          OTHER:
            _prev_state := _demo_state
            _demo_state := DISP_TEMP_RH
      27:
        _demo_state := _prev_state
      OTHER   :
        _prev_state := _demo_state
        _demo_state := DISP_HELP

PRI Setup

  _ser_cog := ser.StartRxTx (TERM_RX, TERM_TX, 0, TERM_BAUD)

  ser.Str (string("Serial IO started on cog "))
  ser.Dec (_ser_cog-1)
  ser.NewLine

  ifnot _sht3x_cog := \sht3x.Start (SCL, SDA, I2C_HZ, SLAVE)
    ser.Str (string("SHT3x object failed to start...halting"))
    sht3x.Stop
    repeat
  else
    ser.Str (string("SHT3x object started on cog "))
    ser.Dec (_sht3x_cog-1)
    ser.NewLine

  _keyDaemon_cog := cognew(keyDaemon, @_keyDaemon_stack)
  ser.Str (string("Terminal input daemon started on cog "))
  ser.Dec (_keyDaemon_cog)
  ser.NewLine

'' Establish some initial settings
  _global_delay := 333
  _measure_mode := MEAS_MODE_ONESHOT
  _mps := 0.5
  _repeatability := sht3x#LOW
  sht3x.SetRepeatability (_repeatability)

PRI Waiting

  ser.Str (string(ser#NL, "Press any key to continue (ESC to return to previous demo)..."))
  repeat until _demo_state <> WAIT_STATE

DAT

  _help_screen  byte "Keys:", ser#NL
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
