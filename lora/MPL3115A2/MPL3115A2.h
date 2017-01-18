/**
 * @file    MPL3115A2.h
 * @brief   Device driver - MPL3115A2 barometric pressure sensor IC w/RTOS support
 * @author  Tim Barr
 * @version 1.0
 * @see     http://cache.freescale.com/files/sensors/doc/data_sheet/MPL3115A2.pdf
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
  */
 
#ifndef MPL3115A2_H
#define MPL3115A2_H

#include "mbed.h"

/** Using the MultiTech Systems MTDOT-EVB
 *
 * Example:
 * @code
 *  #include "mbed.h"
 *  #include "MPL3115A2.h"
 *

 * 
 *  int main() 
 *  {

 *  }
 * @endcode
 */


/**
 *  @class MPL3115A2_DATA
 *  @brief API abstraction for the MPL3115A2 barometric pressure IC data
 */  
class MPL3115A2_DATA
{      
public:
/*!< volatile data variables */
    volatile int32_t _baro;
    volatile int16_t _temp;
    volatile int32_t _minbaro;
    volatile int32_t _maxbaro;
    volatile int16_t _mintemp;
    volatile int16_t _maxtemp;
    
    /** Create the MPL3115A2_DATA object initialized to the parameter (or 0 if none)
     *  @param baro    - the init value of _baro
     *  @param temp    - the init value of _temperature
     *  @param minbaro - the init value of _minbaro
     *  @param maxbaro - the init value of _maxbaro
     *  @param mintemp - the init value of _mintemp
     *  @param maxtemp - the init value of _maxtemp
     */
    MPL3115A2_DATA(int32_t baro = 0, int16_t temp = 0, int32_t minbaro = 0, int32_t maxbaro = 0,
    		        int16_t mintemp = 0, int16_t maxtemp = 0) : _baro(baro), _temp(temp), _minbaro(minbaro),
    		        _maxbaro(maxbaro), _mintemp(mintemp), _maxtemp(maxtemp){}
    
    /** Overloaded '=' operator to allow shorthand coding, assigning objects to one another
     *  @param rhs - an object of the same type to assign ourself the same values of
     *  @return this
     */
    MPL3115A2_DATA &operator= (MPL3115A2_DATA  const &rhs)
    {
        _baro = rhs._baro;
        _temp = rhs._temp;
        _minbaro = rhs._minbaro;
        _maxbaro = rhs._maxbaro;
        _mintemp = rhs._mintemp;
        _maxtemp = rhs._maxtemp;
        
        return *this;
    }
    
    /** Overloaded '=' operator to allow shorthand coding, assigning objects to one another
     *  @param val - Assign each data member (_pressure, _temperature) this value
     *  @return this

    MPL3115A2_DATA &operator= (uint16_t   val)
    {
        _baro = _temp = val;
        
        return *this;
    }
    */
    
    /** Overloaded '==' operator to allow shorthand coding, test objects to one another
     *  @param rhs - the object to compare against
     *  @return 1 if the data members are the same and 0 otherwise
     */
    bool operator== (MPL3115A2_DATA   &rhs)
    {
        return ((_baro == rhs._baro)&&(_temp == rhs._temp)&&
        		(_minbaro == rhs._minbaro) && (_maxbaro == rhs._maxbaro)&&
				(_mintemp == rhs._mintemp) && (_maxtemp == rhs._maxtemp)) ? 1 : 0;
    }
};

/**
 *  @class MPL3115A2
 *  @brief API abstraction for the MPL3115A2 3-axis barometric sensor IC
 *  initial version will be polling only. Interrupt service and rtos support will
 *  be added at a later point
 */ 
class MPL3115A2
{  
public:
    
   /**
     *  @enum WHO_AM_I_VAL
     *  @brief Device ID's that this class is compatible with
     */ 
    enum WHO_AM_I_VAL
    { 
        I_AM_MPL3115A2 = 0xc4, /*!< MPL3115A2 WHO_AM_I register content */
    };

    /**
     * @enum SYS_MODE
     * @brief operating mode of MPL3115A2
     */
    enum SYS_MODE
	{
    	STANDBY = 0,
		ACTIVE
	};

    /**
     * @enum DR_STATUS_VALS
     * @brief flags for data overwrite and data ready
     */
    enum DR_STATUS_VALS
	{
    	TDR   = 0x02,
		PDR   = 0x04,
		PTDR  = 0x08,
		TOW   = 0x20,
		POW   = 0x40,
		PTOW  = 0x80
	};

  /**
     * @enum OUTPUT_MODE
     * @brief Select whether data is raw or post-processed
     */
    enum OUTPUT_MODE
	{
    	DATA_NORMAL = 0x00,
		DATA_RAW    = 0x40
	};
    
     /**
     *  @enum DATA_MODE
     *  @brief Sets the pressure measurement post- processing mode for the sensor
     */
    enum DATA_MODE
    {
        DM_BAROMETER = 0x00,
		DM_ALTIMETER = 0x80
    };

     /**
     * @enum OVERSAMPLE_RATIO
     * @brief values for oversample ratio
     * Note: sample time is 2.5 msec * ratio# i.e. OR_8 -> 2.5 * 8 = 20 msec
     */
    enum OVERSAMPLE_RATIO
	{
    	OR_1   = 0x00,
		OR_2   = 0x08,
		OR_4   = 0x10,
		OR_8   = 0x18,
		OR_16  = 0x20,
		OR_32  = 0x28,
		OR_64  = 0x30,
		OR_128 = 0x38
	};

    /**
    * @enum ACQUISITION_TIMER
    * @brief in active mode this sets time between samples in seconds
    */
   enum ACQUISITION_TIMER
	{
    	AT_1 = 0x00,
		AT_2, AT_4, AT_8, AT_16, AT_32, AT_64, AT_128, AT_256,
		AT_512, AT_1024, AT_2048, AT_4096, AT_8192, AT_16384, AT_32768
	};

    /**
     *  @enum REGISTER
     *  @brief The device register map
     */
    enum REGISTER
    {
        STATUS = 0x0,
        OUT_P_MSB, OUT_P_CSB, OUT_P_LSB, OUT_T_MSB, OUT_T_LSB, DR_STATUS,
        OUT_P_DELTA_MSB, OUT_P_DELTA_CSB, OUT_P_DELTA_LSB, OUT_T_DELTA_MSB, OUT_T_DELTA_LSB,
		WHO_AM_I, F_STATUS, F_DATA, F_SETUP, TIME_DLY, SYSMOD, INT_SOURCE,
		PT_DATA_CFG, BAR_IN_MSB, BAR_IN_LSB, P_ARM_MSB, P_ARM_LSB, T_ARM,
		P_ARM_WND_MSB, P_ARM_WND_LSB, T_ARM_WND,
		P_MIN_MSB, P_MIN_CSB, P_MIN_LSB, T_MIN_MSB, T_MIN_LSB,
		P_MAX_MSB, P_MAX_CSB, P_MAX_LSB, T_MAX_MSB, T_MAX_LSB,
		CTRL_REG1, CTRL_REG2, CTRL_REG3, CTRL_REG4, CTRL_REG5,
        OFF_P, OFF_T, OFF_H
    };
        
    /** Create the MPL3115A2 object
     *  @param i2c - A defined I2C object
     *  @param int1 - A defined InterruptIn object pointer. Default NULL for polling mode
     *  @param int2 - A defined InterruptIn object pointer. Default NULL for polling mode
     *  TODO - Need to add interrupt support
     */ 
    MPL3115A2(I2C &i2c, InterruptIn* int1 = NULL, InterruptIn* int2 = NULL);
    
    /** Test the Who am I register for valid ID
     *  @return Boolean true if valid device
     */
    bool testWhoAmI(void)  ;

    /** Setup the MPL3115A2 for standard barometric sensor read mode
	 *  @out_mode - Turns Data post processing ON/OFF using the OUTPUT_MODE enum
	 *  @data_mode - Sets Pressure or Altitude mode using the DATA_MODE enum
	 *  @os_ratio - Sets the Oversample ration using the OVERSAMPLE_RATIO enum
	 *  @measure_time - Sets the Aquisition time for Active mode using the ACQUISITION_TIMER enum
     *  @return status of command
     *
     *  This sets the resolution, range, data rate, oversample
     *  mode, hi and lo pass filter.
     */
    uint8_t setParameters(OUTPUT_MODE out_mode, DATA_MODE data_mode, OVERSAMPLE_RATIO os_ratio,
    						ACQUISITION_TIMER measure_time)  ;

    uint8_t enableFIFO(void)  ;

    /** Put the MPL3115A2 in the Standby mode
     *  @return status of command
     *  TODO - need to implement function
     */
    uint8_t standbyMode(void)  ;

    /** Put the MPL3115A2 in the active mode
     *  @return status of command
     */
    uint8_t activeMode(void)  ;

    /** Triggers the MPL3115A2 to take one measurement in Active or Standby mode
     *  @return status of command
     */
    uint8_t triggerOneShot(void)  ;

    /** Set the sea level equivalent pressure for Altitude mode
     *  @alti_calib - Value is Equivalent sea level pressure for measurement location (2 Pa resolution) 
     *  @return status byte
     */
     uint8_t setAltitudeCalib(int16_t alti_calib)  ;

    /** Clears all minimum and maximum data registers
     *  @return status of command
     */
    uint8_t clearMinMaxRegs(void)  ;

    /** Check the MPL3115A2 status register
     *  @return status byte
     */
    uint8_t getStatus(void)  ;

    /** Get the Pressure or Altitude data
     *  @return The last valid pressure based reading from the barometric sensor
     */
    int32_t getBaroData(void);
    
    /** Get the Temperature data
     *  @return The last valid temperature reading from the barometric sensor
     */
    int16_t getTempData(void);

    /** Get the Minimum Pressure or Altitude data
     *  @param Boolean TRUE clears the register after reading
     *  @return The Minimum Pressure or Altitude read since last cleared
     */
    int32_t getMinBaro(bool   clear_data);

    /** Get the Maximum Pressure or Altitude data
     *  @param Boolean true clears the register after reading
     *  @return The Maximum Pressure or Altitude read since last cleared
     */
    int32_t getMaxBaro(bool   clear_data);

    /** Get the Minimum Temperature data
       *  @param Boolean true clears the register after reading
       *  @return The Minimum temperature read since last cleared
       */
    int16_t getMinTemp(bool   clear_data);
    
    /** Get the Maximum Temperature data
     *  @param Boolean true clears the register after reading
     *  @return The Maximum temperature read since last cleared
     */
    int16_t getMaxTemp(bool   clear_data);

    /** Get the MP3115A2 data structure
     *  @param Boolean true clears all MIN/MAX registers after reading
     *  @return MPL3115A2_DATA structure
     */
    MPL3115A2_DATA getAllData(bool   clear_data);
    
 /* 
  * Need to add interrupt support code here when I get the chance
  */

    
private:
    
    I2C         			*_i2c;
    InterruptIn 			*_int1;
    InterruptIn				*_int2;
    MPL3115A2_DATA			_data;
    bool					_polling_mode;
    uint8_t static const 	_i2c_addr = (0x60 <<1);
    
    uint8_t init(void);
    
    /** Write to a register
     *  Note: most writes are only valid in stop mode
     *  @param reg - The register to be written
     *  @param data - The data to be written
     *  @param count - number of bytes to send, assumes 1 byte if not specified
     *  @return - status of command
     */
    uint8_t writeRegister(uint8_t reg, char* data, uint8_t count = 1);
    
    /** Read from a register
     *  @param reg - The register to read from
     *  @param data - buffer of data to be read
     *  @param count - number of bytes to send, assumes 1 byte if not specified
     *  @return - status of command
     */
    uint8_t readRegister(uint8_t reg, char* data, uint8_t count = 1);

};

#endif
