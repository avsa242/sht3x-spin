{
    --------------------------------------------
    Filename: core.con.sht3x.spin
    Author: Jesse Burt
    Copyright (c) 2019
    Started Nov 19, 2017
    Updated Jan 1, 2019
    See end of file for terms of use.
    --------------------------------------------
}

CON

    SLAVE_ADDR                  = $44 << 1                  ' Default slave address
    I2C_DEF_FREQ                = 400_000                   ' Set a reasonable default bus frequency
    I2C_MAX_FREQ                = 1_000_000                 ' SHT3X supports I2C FM up to 1MHz

    SHT3X_BREAK_STOP            = $3093
    SHT3X_READ_SERIALNUM        = $3780
    SHT3X_MEAS_HIGHREP_STRETCH  = $2C06
    SHT3X_MEAS_MEDREP_STRETCH   = $2C0D
    SHT3X_MEAS_LOWREP_STRETCH   = $2C10
    SHT3X_ART                   = $2B32
    SHT3X_MEAS_HIGHREP          = $2400
    SHT3X_MEAS_MEDREP           = $240B
    SHT3X_MEAS_LOWREP           = $2416
    SHT3X_FETCHDATA             = $E000
    SHT3X_READSTATUS            = $F32D
        SHT3X_STATUS_ALERT      = 15
        SHT3X_STATUS_HEATER     = 13
        SHT3X_STATUS_RHALERT    = 11
        SHT3X_STATUS_TEMPALERT  = 10
        SHT3X_STATUS_RESET      = 4
        SHT3X_STATUS_CMDSTAT    = 1
        SHT3X_STATUS_CMDCRC     = 0
    SHT3X_CLEARSTATUS           = $3041
    SHT3X_SOFTRESET             = $30A2
    SHT3X_HEATEREN              = $306D
    SHT3X_HEATERDIS             = $3066

    SHT3X_ALERTLIM_RD_HI_SET    = $E11F
    SHT3X_ALERTLIM_RD_HI_CLR    = $E114
    SHT3X_ALERTLIM_RD_LO_CLR    = $E109
    SHT3X_ALERTLIM_RD_LO_SET    = $E102
    SHT3X_ALERTLIM_WR_HI_SET    = $611D
    SHT3X_ALERTLIM_WR_HI_CLR    = $6116
    SHT3X_ALERTLIM_WR_LO_CLR    = $610B
    SHT3X_ALERTLIM_WR_LO_SET    = $6100

PUB Null
'' This is not a top-level object