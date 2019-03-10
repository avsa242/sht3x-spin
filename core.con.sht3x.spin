{
    --------------------------------------------
    Filename: core.con.sht3x.spin
    Author: Jesse Burt
    Description: Low-level constants
    Copyright (c) 2019
    Started Nov 19, 2017
    Updated Mar 10, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_ADDR              = $44 << 1                  ' Default slave address
    I2C_DEF_FREQ            = 400_000                   ' Set a reasonable default bus frequency
    I2C_MAX_FREQ            = 1_000_000                 ' SHT3X supports I2C FM up to 1MHz

    BREAK_STOP              = $3093
    READ_SERIALNUM          = $3780
    MEAS_HIGHREP_STRETCH    = $2C06
    MEAS_MEDREP_STRETCH     = $2C0D
    MEAS_LOWREP_STRETCH     = $2C10
    ART                     = $2B32
    MEAS_HIGHREP            = $2400
    MEAS_MEDREP             = $240B
    MEAS_LOWREP             = $2416
    FETCHDATA               = $E000

    STATUS                  = $F32D
    STATUS_MASK             = $AC13
        FLD_ALERTPENDING    = 15
        FLD_HEATER          = 13
        FLD_RHALERT         = 11
        FLD_TEMPALERT       = 10
        FLD_RESET           = 4
        FLD_CMDSTAT         = 1
        FLD_CMDCRC          = 0

    CLEARSTATUS             = $3041
    SOFTRESET               = $30A2
    HEATEREN                = $306D
    HEATERDIS               = $3066

    ALERTLIM_RD_HI_SET      = $E11F
    ALERTLIM_RD_HI_CLR      = $E114
    ALERTLIM_RD_LO_CLR      = $E109
    ALERTLIM_RD_LO_SET      = $E102
    ALERTLIM_WR_HI_SET      = $611D
    ALERTLIM_WR_HI_CLR      = $6116
    ALERTLIM_WR_LO_CLR      = $610B
    ALERTLIM_WR_LO_SET      = $6100

PUB Null
'' This is not a top-level object