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

  SHT31_DEFAULT_ADDR          = $44 << 1
  SHT31_WR                    = SHT31_DEFAULT_ADDR
  SHT31_RD                    = SHT31_DEFAULT_ADDR + 1

  CMD_READ_SERIALNBR          = $3780
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

  POLYNOMIAL                  = $31

  SCL                         = 8
  SDA                         = 7
  BUS_RATE                    = 100_000'108_150'kHz/kbps

OBJ

  cfg   : "config.propboe"
  ser   : "com.serial.terminal"
  time  : "time"
  i2c   : "jm_i2c_fast"
  debug : "debug"
  math  : "math.float"
  fs    : "string.float"

VAR

  byte err_cnt

PUB Main | i

  setup

  i2c.stop

  repeat
    get_t_rh
    time.MSleep (500)

PUB sht31_cmd(cmd) | ackbit

  if cmd
    i2c.start
    ackbit := i2c.write (SHT31_WR)
    if ackbit
      return FALSE
    ackbit := i2c.write (cmd >> 8)
    if ackbit
      return FALSE
    ackbit := i2c.write (cmd & $FF)
    if ackbit
      return FALSE
  else
    return FALSE

PUB setup | i2c_cog

  ser.Start (115_200)
  ser.Clear
  
  math.Start
  fs.SetPrecision (4)

  ser.Clear

  ser.Str (string("I2C Setup on SCL: "))
  ser.Dec (SCL)
  ser.Str (string(", SDA: "))
  ser.Dec (SDA)
  ser.Str (string(" at "))
  ser.Dec (BUS_RATE/1_000)
  ser.Str (string("kHz..."))
  if i2c_cog := i2c.setupx (SCL, SDA, BUS_RATE)
    ser.Str (string("started on cog "))
    ser.Dec (i2c_cog)
    ser.NewLine
  else
    ser.Str (string("failed - halting!", ser#NL))
    debug.LEDSlow ( cfg#LED1)
  
'  check_for_sht31

PUB check_for_sht31 | status

  ser.Str (string("Checking for SHT31 at $"))
  ser.Hex ( SHT31_DEFAULT_ADDR, 2)
  ser.Str (string("..."))

  status := i2c.present ( SHT31_DEFAULT_ADDR)
  i2c.stop
  case status
    TRUE:
      ser.Str (string("found"))
      ser.NewLine
    OTHER:
      ser.Str (string("no response - halting", ser#NL))
      debug.LEDSlow ( cfg#LED1)

PUB get_t_rh | ackbit, i, readback[2], temp, ttmp, read_t_crc, expected_t_crc, rh, rhtmp, read_rh_crc, expected_rh_crc

  i2c.start
  ackbit := i2c.write ( SHT31_WR)
  ackbit := i2c.write ( SHT31_MEAS_HIGHREP >> 8)
  ackbit := i2c.write ( SHT31_MEAS_HIGHREP & $FF)
  i2c.stop

  i2c.start
  ackbit := i2c.write ( SHT31_RD)
  i2c.stop

  if ackbit                                       'Don't bother reading if there's
    return FALSE                                  ' no data ready from the sensor

  repeat i from 0 to 5
    readback.byte[i] := i2c.read (FALSE)
  i2c.stop

  ttmp := (readback.byte[0] << 8) | readback.byte[1]
  read_t_crc := readback.byte[2]
  expected_t_crc := crc8(@ttmp, 2)

  rhtmp := (readback.byte[3] << 8) | readback.byte[4]
  read_rh_crc := readback.byte[5]
  expected_rh_crc := crc8(@rhtmp, 2)

  ser.Str (string(" Temp: "))
  't := -45 + 175 * ttmp / 65535                'Integer version
  'ser.Dec (t)

  temp := math.MulF (175.0, math.FloatF (ttmp))    'FP version
  temp := math.DivF (temp, 65535.0)
  temp := math.AddF (temp, -45.0)
  temp := fs.FloatToString (temp)
  
  ser.Str (temp)
  ser.Str (string("  RH: "))
  'rh := (100*rhtmp)/65535                      'Integer version
  'ser.Dec (rh)
  rh := math.MulF (100.0, math.FloatF (rhtmp))  'FP version
  rh := math.DivF (rh, 65535.0)
  rh := fs.FloatToString (rh)
  ser.Str (rh)
  ser.NewLine

PUB compare(b1, b2) | c

  return b1 == b2

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
  crc &= $FF

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
