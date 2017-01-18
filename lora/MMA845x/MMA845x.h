/**
 * @file    MMA845x.h
 * @brief   Device driver - MMA845x 3-axis accelerometer IC
 * @author  Tim Barr
 * @version 1.0
 * @see     http://cache.freescale.com/files/sensors/doc/data_sheet/MMA8451Q.pdf
 * @see     http://cache.freescale.com/files/sensors/doc/data_sheet/MMA8452Q.pdf
 * @see     http://cache.freescale.com/files/sensors/doc/data_sheet/MMA8453Q.pdf
 *
 * Copyright (c) 2015
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * Forked from 
 */
 
#ifndef MMA845X_H
#define MMA845X_H

#include "mbed.h"

/** Using the Sparkfun SEN-10955
 *
 * Example:
 * @code
 *  #include "mbed.h"
 *  #include "MMA845x.h"
 *

 * 
 *  int main() 
 *  {

 *  }
 * @endcode
 */


/**
 *  @class MMA845x_DATA
 *  @brief API abstraction for the MMA845x 3-axis accelerometer IC data
 */  
class MMA845x_DATA
{      
public:
    
    volatile int16_t _x;   /*!< volatile data variable */
    volatile int16_t _y;   /*!< volatile data variable */
    volatile int16_t _z;   /*!< volatile data variable */
   
    /** Create the MMA845x_DATA object initialized to the parameter (or 0 if none)
     *  @param x - the init value of _x
     *  @param y - the init value of _y
     *  @param x - the init value of _z
     */
    MMA845x_DATA(int16_t x = 0, int16_t y = 0, int16_t z = 0) : _x(x), _y(y), _z(z) {}
    
    /** Overloaded '=' operator to allow shorthand coding, assigning objects to one another
     *  @param rhs - an object of the same type to assign ourself the same values of
     *  @return this
     */
    MMA845x_DATA &operator= (MMA845x_DATA const &rhs)
    {
        _x = rhs._x;
        _y = rhs._y;
        _z = rhs._z;
        
        return *this;
    }
    
    /** Overloaded '=' operator to allow shorthand coding, assigning objects to one another
     *  @param val - Assign each data member (_x, _y, _z) this value
     *  @return this
     */
    MMA845x_DATA &operator= (int16_t const val)
    {
        _x = _y = _z = val;
        
        return *this;
    }
    
    /** Overloaded '==' operator to allow shorthand coding, test objects to one another
     *  @param rhs - the object to compare against
     *  @return 1 if the data members are the same and 0 otherwise
     */
    bool operator== (MMA845x_DATA const &rhs) const
    {
        return ((_x == rhs._x)&&(_y == rhs._y)&&(_z == rhs._z)) ? 1 : 0;
    }
};

/**
 *  @class MMA845x
 *  @brief API abstraction for the MMA845x 3-axis accelerometer IC
 *  initial version will be polling only. Interrupt service and rtos support will
 *  be added at a later point
 */ 
class MMA845x
{  
public:
    
    /**
     *  @enum SA0
     *  @brief Possible terminations for the ADDR pin
     */ 
    enum SA0
    { 
        SA0_VSS = 0, /*!< SA0 connected to VSS */
        SA0_VDD      /*!< SA0 connected to VDD */
    };
    
    /**
     *  @enum WHO_AM_I_VAL
     *  @brief Device ID's that this class is compatible with
     */ 
    enum WHO_AM_I_VAL
    { 
        MMA8451 = 0x1a, /*!< MMA8451 WHO_AM_I register content */
        MMA8452 = 0x2a, /*!< MMA8452 WHO_AM_I register content */
        MMA8453 = 0x3a, /*!< MMA8453 WHO_AM_I register content */
    };

    /**
     * @enum SYS_MODE
     * @brief operating mode of MMA845x
     */
    enum SYS_MODE
	{
    	STANDBY = 0,
		WAKE, SLEEP
	};

    /**
     * @enum STATUS
     * @brief flags for data overwrite and data ready
     */
    enum STATUS
	{
    	XDR   = 0x01,
		YDR   = 0x02,
		ZDR   = 0x04,
		XYZDR = 0x08,
		XOW   = 0x10,
		YOW   = 0x20,
		ZOW   = 0x40,
		XYZOW = 0x80
	};

  /**
     * @enum RANGE
     * @brief values for measurement range positive and negative
     */
    enum RANGE
	{
    	RANGE_2g = 0,
		RANGE_4g, RANGE_8g
	};
    
    /**
     * @enum RESOLUTION
     * @brief selections for resolution of data, 8 bit or maximum
     */
    enum RESOLUTION
	{
    	RES_MAX = 0,   /* Read back full resolution - normal mode*/
		RES_8BIT = 2   /* Read back 8 bit values only - fast mode*/
	};

    /**
     *  @enum LOW_NOISE
     *  @brief Low Noise mode Note: 4g max reading when on
     */
    enum LOW_NOISE
    {
        LN_OFF = 0x00, /* Low Noise mode off */
        LN_ON = 0x02  /* Low Noise mode on, 4g max readings */
    };

    /**
     *  @enum HPF_MODE
     *  @brief High Pass Filter mode
     */
    enum HPF_MODE
    {
        HPF_OFF = 0x00, /* High Pass Filter mode off */
        HPF_ON = 0x10  /* High Pass Filter mode on */
    };

     /**
     * @enum DATA_RATE
     * @brief values for normal output data rate in Hz
     */
    enum DATA_RATE
	{
    	DR_800  = 0x00,
		DR_400  = 0x08,
		DR_200  = 0x10,
		DR_100  = 0x18,
		DR_50   = 0x20,
		DR_12_5 = 0x28,
		DR_6_25 = 0x30,
		DR_1_56 = 0x38
	};
    /**
     * @enum ASLP_DATA_RATE
     * @brief values for auto_sleep mode data rate in HZ
     */
    enum ASLP_DATA_RATE
	{
    	ASLPDR_50   = 0x00,
		ALSPDR_12_5 = 0x40,
		ASLPDR_6_25 = 0x80,
		ASLPDR_1_56 = 0xB0
	};

    /**
     *  @enum OVERSAMPLE_MODE
     *  @brief sets the oversample mode, Normal, Low power and noise, High resolution, or low power
     */
    enum OVERSAMPLE_MODE
	{
    	OS_NORMAL = 0,
		OS_LO_PN, OS_HI_RES, OS_LO_POW
	};

    /**
     *  @enum REGISTER
     *  @brief The device register map
     */
    enum REGISTER
    {
        STATUS = 0x00,
        OUT_X_MSB, OUT_X_LSB, OUT_Y_MSB, OUT_Y_LSB, OUT_Z_MSB, OUT_Z_LSB,
        
        F_SETUP = 0x09, TRIG_CFG, // only available on the MMA8451 variant
        
        SYSMOD = 0x0B,
        INT_SOURCE, WHO_AM_I, XYZ_DATA_CFG, HP_FILTER_CUTOFF, PL_STATUS,
        PL_CFG, PL_COUNT, PL_BF_ZCOMP, P_L_THS_REG, FF_MT_CFG, FF_MT_SRC,
        FF_MT_THS, FF_MT_COUNT,
        
        TRANSIENT_CFG = 0x1D,
        TRANSIENT_SRC, TRANSIENT_THS, TRANSIENT_COUNT, PULSE_CFG, PULSE_SRC,
        PULSE_THSX, PULSE_THSY, PULSE_THSZ, PULSE_TMLT, PULSE_LTCY, PULSE_WIND,
        ASLP_COUNT, CTRL_REG1, CTRL_REG2, CTRL_REG3, CTRL_REG4, CTRL_REG5,
        OFF_X, OFF_Y, OFF_Z
    };
        
    /** Create the MMA845x object
     *  @param i2c - A defined I2C object
     *  @param int1 - A defined InterruptIn object pointer. Default NULL for polling mode
     *  @param int2 - A defined InterruptIn object pointer. Default NULL for polling mode
     *  @param i2c_addr - state of pin SA0
     *  TODO - need to add interrupt support
     */ 
    MMA845x(I2C &i2c, SA0 const i2c_addr = SA0_VSS, InterruptIn* int1 = NULL, InterruptIn* int2 = NULL);
    
    /** Get the X data
     *  @return The last valid X-axis reading from the accelerometer
     */
    int16_t getX(void);
    
    /** Get the Y data
     *  @return The last valid Y-axis reading from the accelerometer
     */
    int16_t getY(void);
    
    /** Get the Z data
     *  @return The last Z-axis valid reading from the accelerometer
     */
    int16_t getZ(void);
    
    /** Get the XYZ data structure
     *  @return The last valid X, Y, and Z-axis readings from the accelerometer
     */
    MMA845x_DATA getXYZ(void);
    
    /** Get the XYZ data structure
     *  @return accelerometer ID code. Test versus the WHO_AM_I_VAL enum
     */
    char getWhoAmI(void) const;

    /** Setup the MMA845x for standard accelerometer read mode
     *  @range - set the measurement range using RANGE enum
     *  @resolution - set the ADC resolution using the RESOLUTION enum
     *  @lo_noise - Set the Low-Noise mode using the LOW_NOISE enum
     *  @data_rate - set the aquisition rate using the DATA_RATE enum
     *  @os_mode - Set the Over sample mode suing the OVERSAMPLE_MODE enum
     *  @hpf_mode - Set the Hi pass filter mode using the HPF_MOSE enum
     *  @return status of command
     *
     *  This sets the resolution, range, data rate, oversample
     *  mode, hi and lo pass filter.
     */
    uint8_t setCommonParameters(RANGE range, RESOLUTION resolution, LOW_NOISE lo_noise,
    							DATA_RATE data_rate, OVERSAMPLE_MODE os_mode, HPF_MODE hpf_mode ) const;

    /** Ebnable Motion detect mode and interrupt handler
     *  @return status of command
     *  TODO - need to implement function
     */
    uint8_t enableMotionDetect(void) const;

    /** Enable Pulse Detect mode and interrupt handler
     *  @return status of command
     *  TODO - need to implement function
     */
    uint8_t enablePulseDetect(void) const;

    /** Enable Orientation mode and interrupt handler
     *  @return status of command
     *  TODO - need to implement function
     */
    uint8_t enableOrientationDetect(void) const;

    /** Enable Transient detect mode and interrupt handler
     *  @return status of command
     *  TODO - need to implement function
     */
    uint8_t enableTransientDetect(void) const;

    /** Enable Autosleep function and interrupt handler
     *  @return status of command
     *  TODO - need to implement function
     */
    uint8_t enableAutoSleep(void) const;

    /** Enbale FIFO function and interrupt handler
     *  @return status of command
     *  TODO - need to implement function
     */
    uint8_t enableFIFO(void) const;
    
    /** Put the MMA845x in the Standby mode
     *  @return status of command
     */
    uint8_t standbyMode(void) const;
 
    /** Put the MMA845x in the active mode
     *  @return status of command
     */
    uint8_t activeMode(void) const;
    
    /** Check the MMA845x status register
         *  @return status byte
         */
    uint8_t getStatus(void) const;

    
private:
    
    I2C         *_i2c;
    InterruptIn *_int1;
    InterruptIn *_int2;
    uint8_t      _i2c_addr;
    char         _who_am_i;
    MMA845x_DATA _data;
    bool         _polling_mode;
    
    uint8_t init(void);
    
    /** Write to a register (exposed for debugging reasons)
     *  Note: most writes are only valid in stop mode
     *  @param reg - The register to be written
     *  @param data - The data to be written
     */
    uint8_t writeRegister(uint8_t const reg, uint8_t const data) const;
    
    /** Read from a register (exposed for debugging reasons)
     *  @param reg - The register to read from
     *  @return The register contents
     */
    uint8_t readRegister(uint8_t const reg, uint8_t count, char* data) const;
    

};

#endif
