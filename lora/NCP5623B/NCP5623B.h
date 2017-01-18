/**
 * @file    NCP5623B.h
 * @brief   Device driver - NCP5623B Triple LED Driver IC w/RTOS support
 * @author  Tim Barr
 * @version 1.0
 * @see     http://www.onsemi.com/pub/Collateral/NCP5623B-D.PDF
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
 *
 */
 
#ifndef NCP5623B_H
#define NCP5623B_H

#include "mbed.h"

/** Using the Multitech MTDOT-EVB
 *
 * Example:
 * @code
 *  #include "mbed.h"
 *  #include "NCP5623B.h"
 *

 * 
 *  int main() 
 *  {

 *  }
 * @endcode
 */

/**
 *  @class NCP5623B
 *  @brief API abstraction for the NCP5623B Triple LED Driver IC
 *  initial version will be polling only. Interrupt service and rtos support will
 *  be added at a later point
 */ 
class NCP5623B
{  
public:

    /**
     * @static DATAMASK
     * @brief Data mask
     */
    uint8_t static const DATAMASK = 0x1F;

    /**
     *  @enum LEDNUM
     *  @brief LED number for indexing
     */
    enum LEDNUM
    {
        LED_1 = 0x00,  /* LED 1 device pin 5  */
        LED_2,         /* LED 2 device pin 4 */
		LED_3          /* LED 3 device pin 3 */
    };

     /**
     * @enum DIMDIRECTIO
     * @brief Setting Dim direction for Dimming function
     */
    enum DIMDIRECTION
	{
    	DIMDWN = 0x00,	/* Set dimmer direction to down */
		DIMUP			/* Set dimmer direction to up*/
	};

	/**
     *  @enum REGISTER
     *  @brief The device register map using upper 3 bits
     */
    enum REGISTER
    {
        SHUTDWN		= 0x00,
        LEDCURR		= 0x20,
		PWMLED1		= 0x40,
		PWMLED2		= 0x60,
		PWMLED3		= 0x80,
		DIMUPSET	= 0xA0,
		DIMDWNSET	= 0xC0,
		DIMTIME		= 0xE0
    };
        
    /** Create the NCP5623B object
     *  @param i2c - A defined I2C object
     */ 
    NCP5623B(I2C &i2c);
    
    /** Shutdown LEDS
     *  @return status of command
     */
    uint8_t shutdown(void) const;

    /** Set static LED Current
     *  @data - value of current draw for all LEDs range 0-31 
     *  @return status of command
     */
    uint8_t setLEDCurrent(uint8_t data) const;

    /** Set PWM mode for specific LED
     *  @lednum - selects LED
     *  @data - PWM value to set  range 0-31 0-100% Pulse width
     *  @return status of command
     */
    uint8_t setPWM(LEDNUM lednum, int8_t data ) const;

    /** Set Dimming mode for all LEDs
     *  @dimdir - direction of dimming
     *  @endstep - ending step of ramp up or ramp down range 0-31
     *  @steptime - time per step range 0-31 in 8 msec multiples
     *  @return status of command
     */
    uint8_t setDimming(DIMDIRECTION dimdir, uint8_t endstep, uint8_t time) const;

private:
    
    I2C						*_i2c;
    uint8_t static const	_i2c_addr = (0x38 << 1);
    
    uint8_t init(void);

  /** Write to a register (exposed for debugging reasons)
   *  @param reg - The register to be written
   *  @param data - The data to be written
   */
  uint8_t writeRegister(REGISTER const reg, uint8_t const data) const;
};

#endif
