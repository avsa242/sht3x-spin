{
    --------------------------------------------
    Filename: sensor.temp_rh.sht3x.spin
    Author: Jesse Burt
    Description: Driver for Sensirion SHT3x series Temperature/Relative Humidity sensors
    Copyright (c) 2022
    Started Nov 19, 2017
    Updated Nov 13, 2022
    See end of file for terms of use.
    --------------------------------------------
}
#include "sensor.temp_rh.common.spinh"
CON

    { I2C }
    SLAVE_WR        = core#SLAVE_ADDR
    SLAVE_RD        = core#SLAVE_ADDR | 1
    DEF_SCL         = 28
    DEF_SDA         = 29
    DEF_HZ          = 100_000

    MSB             = 1
    LSB             = 0

' Measurement repeatability
    LOW             = 0
    MED             = 1
    HIGH            = 2

' Measurement modes
    SINGLE          = 0
    CONT            = 1

VAR

    long _reset_pin
    byte _repeatability
    byte _addr_bit
    byte _measure_mode
    byte _drate_hz

OBJ

#ifdef SHT3X_I2C_BC
    i2c : "com.i2c.nocog"                       ' BC I2C engine
#else
    i2c : "com.i2c"                             ' PASM I2C engine
#endif
    core: "core.con.sht3x"                      ' hw-specific constants
    time: "time"                                ' timekeeping methods
    crc : "math.crc"                            ' crc algorithms

PUB null{}
' This is not a top-level object

PUB start{}: status
' Start using "standard" Propeller I2C pins and 100kHz
    return startx(DEF_SCL, DEF_SDA, DEF_HZ, 0, -1)

PUB startx(SCL_PIN, SDA_PIN, I2C_HZ, ADDR_BIT, RESET_PIN): status
' Start using custom I/O settings and I2C bus speed
'   NOTE: RESET_PIN is optional; choose an invalid value to ignore (e.g., -1)
    if lookdown(SCL_PIN: 0..31) and lookdown(SDA_PIN: 0..31) and {
}   I2C_HZ =< core#I2C_MAX_FREQ                 ' validate I/O pins
        if (status := i2c.init(SCL_PIN, SDA_PIN, I2C_HZ))
            time.usleep(core#T_POR)             ' wait for device startup
            case ADDR_BIT
                0:
                    _addr_bit := 0
                other:
                    _addr_bit := 1 << 1
            if (i2c.present(SLAVE_WR | _addr_bit))
                _reset_pin := RESET_PIN
                reset{}
                clr_status{}
                return status
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE

PUB stop{}
' Stop the driver
    i2c.deinit{}
    bytefill(@_reset_pin, 0, 8)

PUB clr_status{}
' Clears the status register
    writereg(core#CLRSTATUS, 0, 0)
    time.usleep(core#T_POR)

PUB data_rate(rate): curr_rate | tmp
' Output data rate, in Hz
'   Valid values: 0_5 (0.5Hz), 1, 2, 4, 10
'   Any other value returns the current setting
'   NOTE: Applies when opmode() == CONT (continuous), only
'   NOTE: Sensirion notes that at the highest measurement rate (10Hz),
'       self-heating of the sensor might occur
    case rate
        0, 5:
            ' Measurement rate and repeatability configured in the same reg
            tmp := core#MEAS_PER_0_5 | lookupz(_repeatability:{
}           core#RPT_LO_0_5, core#RPT_MED_0_5, core#RPT_HI_0_5)
            _drate_hz := rate
        1:
            tmp := core#MEAS_PER_1 | lookupz(_repeatability:{
}           core#RPT_LO_1, core#RPT_MED_1, core#RPT_HI_1)
            _drate_hz := rate
        2:
            tmp := core#MEAS_PER_2 | lookupz(_repeatability:{
}           core#RPT_LO_2, core#RPT_MED_2, core#RPT_HI_2)
            _drate_hz := rate
        4:
            tmp := core#MEAS_PER_4 | lookupz(_repeatability:{
}           core#RPT_LO_4, core#RPT_MED_4, core#RPT_HI_4)
            _drate_hz := rate
        10:
            tmp := core#MEAS_PER_10 | lookupz(_repeatability:{
}           core#RPT_LO_10, core#RPT_MED_10, core#RPT_HI_10)
            _drate_hz := rate
        other:
            return _drate_hz
    stop_cont_meas{}                            ' Stop ongoing measurements
    writereg(tmp, 0, 0)
    _measure_mode := CONT

PUB heater_ena(state): curr_state
' Enable/Disable built-in heater
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value polls the chip and returns the current setting
'   NOTE: Per SHT3x datasheet, this is for plausability checking only
    case ||(state)
        0, 1:
            state := lookupz(||(state): core#HEATERDIS, core#HEATEREN)
            writereg(state, 0, 0)
        other:
            curr_state := 0
            readreg(core#STATUS, 3, @curr_state)
            curr_state >>= 8                    ' Chop off CRC
            return ((curr_state >> core#HEATER) & 1) == 1


PUB last_cmd_ok{}: flag
' Flag indicating last command executed without error
'   Returns: TRUE (-1) if no error, FALSE (0) otherwise
    flag := 0
    readreg(core#STATUS, 2, @flag)
    return (((flag >> 1) & 1) == 0)

PUB last_crc_ok{}: flag
' Flag indicating CRC of last command was good
'   Returns: TRUE (-1) if CRC was good, FALSE (0) otherwise
    flag := 0
    readreg(core#STATUS, 2, @flag)
    return ((flag & 1) == 0)

PUB measure{}
' dummy method

PUB opmode(mode): curr_mode
' Set device operating mode
'   Valid values
'      *SINGLE (0): single-shot measurements
'       CONT (1): continuously measure
'   Any other value returns the current setting
    case mode
        SINGLE:
            stop_cont_meas{}
        CONT:
            stop_cont_meas{}
            data_rate(_drate_hz)
        other:
            return _measure_mode

    _measure_mode := mode

PUB repeatability(level): curr_lvl
' Set measurement repeatability/stability
'   Valid values: LOW (0), MED (1), HIGH (2)
'   Any other value returns the current setting
    case level
        LOW, MED, HIGH:
            _repeatability := level
        other:
            return _repeatability

PUB reset{}
' Perform Soft Reset
    case _reset_pin
        0..31:
            outa[_reset_pin] := 1
            dira[_reset_pin] := 1
            outa[_reset_pin] := 0
            time.usleep(1)
            outa[_reset_pin] := 1
        other:
            writereg(core#SOFTRESET, 0, 0)
    time.usleep(core#T_POR)

PUB rh_data{}: rh_adc | tmp[2]
' Read relative humidity ADC data
'   Returns: u16
    tmp := 0
    case _measure_mode
        SINGLE:
            one_shot_meas(@tmp)
            _last_temp := tmp.word[1]
            _last_rh := tmp.word[0]
        CONT:
            poll_measure(@tmp)
            ' update last temp and RH measurement vars
            _last_temp := (tmp.byte[5] << 8) | tmp.byte[4]
            _last_rh := (tmp.byte[2] << 8) | tmp.byte[1]
    return _last_rh

PUB rh_int_hi_hyst(level): curr_lvl
' High RH interrupt: clear level, in percent
'   Valid values: 0..100
'   Any other value polls the chip and returns the current setting, in hundredths of a percent
    curr_lvl := 0
    readreg(core#ALERTLIM_RD_HI_CLR, 2, @curr_lvl)
    case level
        0..100:
            level := rhpct_7bit(level)
        other:
            return rh7bit_pct(curr_lvl)

    level := (curr_lvl & core#ALERTLIM_RH_MASK) | level
    writereg(core#ALERTLIM_WR_HI_CLR, 2, @level)

PUB rh_int_hi_thresh(level): curr_lvl
' High RH interrupt: trigger level, in percent
'   Valid values: 0..100
'   Any other value polls the chip and returns the current setting, in hundredths of a percent
    curr_lvl := 0
    readreg(core#ALERTLIM_RD_HI_SET, 2, @curr_lvl)
    case level
        0..100:
            level := rhpct_7bit(level)
        other:
            return rh7bit_pct(curr_lvl)

    level := (curr_lvl & core#ALERTLIM_RH_MASK) | level
    writereg(core#ALERTLIM_WR_HI_SET, 2, @level)

PUB rh_int_lo_hyst(level): curr_lvl
' Low RH interrupt: clear level, in percent
'   Valid values: 0..100
'   Any other value polls the chip and returns the current setting, in hundredths of a percent
    curr_lvl := 0
    readreg(core#ALERTLIM_RD_LO_CLR, 2, @curr_lvl)
    case level
        0..100:
            level := rhpct_7bit(level)
        other:
            return rh7bit_pct(curr_lvl)

    level := (curr_lvl & core#ALERTLIM_RH_MASK) | level
    writereg(core#ALERTLIM_WR_LO_CLR, 2, @level)

PUB rh_int_lo_thresh(level): curr_lvl
' Low RH interrupt: trigger level, in percent
'   Valid values: 0..100
'   Any other value polls the chip and returns the current setting, in hundredths of a percent
    curr_lvl := 0
    readreg(core#ALERTLIM_RD_LO_SET, 2, @curr_lvl)
    case level
        0..100:
            level := rhpct_7bit(level)
        other:
            return rh7bit_pct(curr_lvl)

    level := (curr_lvl & core#ALERTLIM_RH_MASK) | level
    writereg(core#ALERTLIM_WR_LO_SET, 2, @level)

PUB rh_word2pct(rh_word): rh
' Convert RH ADC word to percent
'   Returns: relative humidity, in hundredths of a percent
    return (100 * (rh_word * 100)) / core#ADC_MAX

PUB serial_num(ptr_sn)
' Get serial number
'   ptr_sn: pointer to copy serial number to (4 bytes)
    readreg(core#READ_SN, 4, ptr_sn)

PUB temp_data{}: temp_adc | tmp[2]
' Read temperature ADC data
'   Returns: s16
    tmp := 0
    case _measure_mode
        SINGLE:
            one_shot_meas(@tmp)
            _last_temp := tmp.word[1]
            _last_rh := tmp.word[0]
        CONT:
            poll_measure(@tmp)
            ' update last temp and RH measurement vars
            _last_temp := (tmp.byte[5] << 8) | tmp.byte[4]
            _last_rh := (tmp.byte[2] << 8) | tmp.byte[1]

    return _last_temp

PUB temp_int_hi_hyst(level): curr_lvl
' High temperature interrupt: clear level, in degrees C
'   Valid values: -45..130
'   Any other value polls the chip and returns the current setting, in hundredths of a degree C
    curr_lvl := 0
    readreg(core#ALERTLIM_RD_HI_CLR, 2, @curr_lvl)
    case level
        -45..130:
            level := tempc_9bit(level)
        other:
            return temp9bit_c(curr_lvl & $1ff)

    level := (curr_lvl & core#ALERTLIM_TEMP_MASK) | level
    writereg(core#ALERTLIM_WR_HI_CLR, 2, @level)

PUB temp_int_hi_thresh(level): curr_lvl
' High temperature interrupt: trigger level, in degrees C
'   Valid values: -45..130
'   Any other value polls the chip and returns the current setting, in hundredths of a degree C
    curr_lvl := 0
    readreg(core#ALERTLIM_RD_HI_SET, 2, @curr_lvl)
    case level
        -45..130:
            level := tempc_9bit(level)
        other:
            return temp9bit_c(curr_lvl & $1ff)

    level := (curr_lvl & core#ALERTLIM_TEMP_MASK) | level
    writereg(core#ALERTLIM_WR_HI_SET, 2, @level)

PUB temp_int_lo_hyst(level): curr_lvl
' Low temperature interrupt: clear level, in degrees C
'   Valid values: -45..130
'   Any other value polls the chip and returns the current setting, in hundredths of a degree C
    curr_lvl := 0
    readreg(core#ALERTLIM_RD_LO_CLR, 2, @curr_lvl)
    case level
        -45..130:
            level := tempc_9bit(level)
        other:
            return temp9bit_c(curr_lvl & $1ff)

    level := (curr_lvl & core#ALERTLIM_TEMP_MASK) | level
    writereg(core#ALERTLIM_WR_LO_CLR, 2, @level)

PUB temp_int_lo_thresh(level): curr_lvl
' Low temperature interrupt: trigger level, in degrees C
'   Valid values: -45..130
'   Any other value polls the chip and returns the current setting, in hundredths of a degree C
    curr_lvl := 0
    readreg(core#ALERTLIM_RD_LO_SET, 2, @curr_lvl)
    case level
        -45..130:
            level := tempc_9bit(level)
        other:
            return temp9bit_c(curr_lvl & $1ff)

    level := (curr_lvl & core#ALERTLIM_TEMP_MASK) | level
    writereg(core#ALERTLIM_WR_LO_SET, 2, @level)

PUB temp_word2deg(temp_word): temp
' Convert temperature ADC word to temperature
'   Returns: temperature, in hundredths of a degree, in chosen scale
    case _temp_scale
        C:
            return ((175 * (temp_word * 100)) / core#ADC_MAX)-(45 * 100)
        F:
            return ((315 * (temp_word * 100)) / core#ADC_MAX)-(49 * 100)
        other:
            return FALSE

PRI one_shot_meas(ptr_buff)
' Perform single-shot measurement
    case _repeatability
        LOW, MED, HIGH:
            readreg(lookupz(_repeatability: core#MEAS_LOWREP_CS,{
}           core#MEAS_MEDREP_CS, core#MEAS_HIGHREP_CS), 6, ptr_buff)
        other:
            return

PRI poll_measure(ptr_buff)
' Poll for measurement when sensor is in continuous measurement mode
    readreg(core#FETCHDATA, 6, ptr_buff)

PRI rhpct_7bit(rh_pct): rh7bit
' Converts Percent RH to 7-bit value, for use with alert threshold setting
'   Valid values: 0..100
'   Any other value is ignored
'   NOTE: Value is left-justified in MSB of word
    case rh_pct
        0..100:
            return (((rh_pct * 100) / 100 * core#ADC_MAX) / 100) & $FE00
        other:
            return

PRI rh7bit_pct(rh_7b): rhpct
' Converts 7-bit value to Percent RH, for use with alert threshold settings
'   Valid values: $02xx..$FExx (xx = 00)
'   NOTE: Value must be left-justified in MSB of word
    rh_7b &= $FE00                              ' Mask off temperature
    rh_7b *= 10000                              ' Scale up
    return rh_7b /= core#ADC_MAX                ' Scale to %

PRI stop_cont_meas{}
' Stop continuous measurement mode
    writereg(core#BREAK_STOP, 0, 0)

PRI tempc_9bit(temp_c): temp9b | scale
' Converts degrees C to 9-bit value, for use with alert threshold settings
'   Valid values: -45..130
    case temp_c
        -45..130:
            scale := 10_000                     ' Fixed-point scale
            temp9b := ((((temp_c * scale) + (45 * scale)) / 175 * core#ADC_MAX)) / scale
            return (temp9b >> 7) & $001FF
        other:
            return

PRI temp9bit_c(temp_9b): tempc | scale
' Converts raw 9-bit value to temperature in degrees C
'   Valid values: 0..511
'   Returns: hundredths of a degree C -4500..12966 (-45.00C..129.66C)
'   Any other value is ignored
    scale := 100
    case temp_9b
        0..511:
            tempc := (temp_9b << 7)
            return ((175 * (tempc * scale)) / core#ADC_MAX)-(45 * scale)
        other:
            return

PRI readreg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, r_tmp, t_tmp, crc_r
' Read nr_bytes from the slave device into ptr_buff
    case reg_nr                                 ' validate register num
        core#MEAS_HIGHREP_CS..core#MEAS_LOWREP_CS:
            cmd_pkt.byte[0] := (SLAVE_WR | _addr_bit)
            cmd_pkt.byte[1] := reg_nr.byte[MSB]
            cmd_pkt.byte[2] := reg_nr.byte[LSB]
            r_tmp := t_tmp := 0

            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 3)

            i2c.start{}
            i2c.write(SLAVE_RD | _addr_bit)
            i2c.rdblock_msbf(@t_tmp, 3, i2c#ACK)
            i2c.rdblock_msbf(@r_tmp, 3, i2c#NAK)
            i2c.stop{}

            crc_r := t_tmp.byte[0]              ' crc read with data
            t_tmp >>= 8                         ' chop it off the data
            if crc.sensirion_crc8(@t_tmp, 2) == crc_r
                word[ptr_buff][1] := t_tmp      ' copy temp
            else
                return

            crc_r := r_tmp.byte[0]
            r_tmp >>= 8
            if crc.sensirion_crc8(@r_tmp, 2) == crc_r
                word[ptr_buff][0] := r_tmp      ' copy RH
            else
                return

        core#READ_SN, core#STATUS, core#FETCHDATA, {
}       core#ALERTLIM_RD_LO_SET..core#ALERTLIM_RD_HI_SET:
            cmd_pkt.byte[0] := (SLAVE_WR | _addr_bit)
            cmd_pkt.byte[1] := reg_nr.byte[MSB]
            cmd_pkt.byte[2] := reg_nr.byte[LSB]

            i2c.start{}
            i2c.wrblock_lsbf(@cmd_pkt, 3)

            i2c.start{}
            i2c.write(SLAVE_RD | _addr_bit)
            i2c.rdblock_msbf(ptr_buff, nr_bytes, i2c#NAK)
            i2c.stop{}

        other:
            return

PRI writereg(reg_nr, nr_bytes, ptr_buff) | cmd_pkt, chk
' Write nr_bytes to the slave device from ptr_buff
    chk := 0
    case reg_nr
        core#MEAS_HIGHREP..core#MEAS_LOWREP, core#CLRSTATUS, core#HEATEREN, {
}       core#HEATERDIS, core#SOFTRESET, core#BREAK_STOP, {
}       core#MEAS_P_HI_0_5, core#MEAS_P_MED_0_5, core#MEAS_P_LO_0_5, {
}       core#MEAS_P_HI_1, core#MEAS_P_MED_1, core#MEAS_P_LO_1, {
}       core#MEAS_P_HI_2, core#MEAS_P_MED_2, core#MEAS_P_LO_2, {
}       core#MEAS_P_HI_4, core#MEAS_P_MED_4, core#MEAS_P_LO_4, {
}       core#MEAS_P_HI_10, core#MEAS_P_MED_10, core#MEAS_P_LO_10:

        core#ALERTLIM_WR_LO_SET..core#ALERTLIM_WR_HI_SET:
            ' calc CRC for interrupt threshold set command (required)
            chk := crc.sensirion_crc8(ptr_buff, 2)
        other:
            return

    cmd_pkt.byte[0] := (SLAVE_WR | _addr_bit)
    cmd_pkt.byte[1] := reg_nr.byte[MSB]
    cmd_pkt.byte[2] := reg_nr.byte[LSB]

    i2c.start{}
    i2c.wrblock_lsbf(@cmd_pkt, 3)

    if chk                                      ' write params and CRC
        i2c.wrblock_msbf(ptr_buff, nr_bytes)
        i2c.write(chk)
    i2c.stop{}
    time.usleep(500)

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
