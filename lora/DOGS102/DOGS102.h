/**
 * @file    DOGS102.h
 * @brief   Device driver - DOGS102 102x64 pixel Graphic LCD display W/RTOS support
 * @author  Tim Barr
 * @version 1.0
 * @see     http://www.lcd-module.com/eng/pdf/grafik/dogs102-6e.pdf
 * @see     http://www.lcd-module.com/eng/pdf/zubehoer/uc1701.pdf
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
 
#ifndef DOGS102_H
#define DOGS102_H

#include "mbed.h"

/** Using the Multitech MTDOT-EVB
 *
 * Example:
 * @code
 *  #include "mbed.h"
 *  #include "DOGS102.h"
 *

 * 
 *  int main() 
 *  {

 *  }
 * @endcode
 */

/**
 *  @class DOGS102
 *  @brief API abstraction for the DOGS102 Liquid Crystal Graphics Display
 *  initial version will be polling only. Interrupt service will
 *  be added at a later point
 */ 
#define LCDWIDTH 102
#define LCDHEIGHT 64
#define LCDPAGES  8 // LCDHEIGHT/8
/*

 Each page is 8 lines, one byte per column

         Col0
        +---+--
        | 0 |
Page 0  | 1 |
        | 2 |
        | 3 |
        | 4 |
        | 5 |
        | 6 |
        | 7 |
        +---+--
*/

class DOGS102
{  
public:

	/**
	 * @enum DATAMASKS
	 * @brief collection of data masks for commands
	 */

	enum DATAMASKS
	{
		LSBMASK = 0x01,
		WAMASK  = 0x03,
		PCMASK  = 0x07,
		LC1MASK = 0x08,
		COLMASK = 0x0F,
		SLMASK  = 0x3F,
		TCMASK  = 0x80
	};

	/**
     *  @enum COMMANDS
     *  @brief The device command register map
     */

    enum COMMANDs
    {
        SETCOLADDRLSB = 0x00,		// use COLMASK for data
        SETCOLADDRMSB = 0x10,		// use COLMASK for data
		SETPWRCTRL = 0x28,			// use PCMASK for data
		SETSCROLLLINE = 0X40,		// use SLMASK for data
		SETPGADDR = 0xB0,			// use COLMASK for data
		SETVLCDRESRATIO = 0x20,		// use PCMASK for data
		SETELECVOL = 0x81,			// double byte command use SLMASK for data
		SETALLPIXELON = 0xA4,		// use LSBMASK for data
		SETINVDISP = 0xA6,			// use LSBMASK for data
		SETDISPEN = 0xAE,			// use LSBMASK for data
		SETSEGDIR = 0xA0,			// use LSBMASK for data
		SETCOMDIR = 0xC0,			// use LC1MASK for data
		SOFTRESET = 0xE2,			// no data mask needed
		SETLCDBIAS = 0xA2,			// use LSBMASK for data
		SETAPROGCTRL = 0xFA			// Double byte command use WAMASK and TCMASK for data
    };

    /** Create the DOGS102 object
     *  @param spi - A defined SPI object
     *  @param spi_cs - a defined DigitalOut connected to CS pin of LCD
     *  @param cmnd_data - a defined Digitalout connected to Command/Data pin of LCD
     */ 
    DOGS102(SPI &spi, DigitalOut &spi_cs, DigitalOut &cmnd_data );

    /** Clears the buffer memory
     *  This commands clears the display buffer if Update flag is set
     *  it clears the display directly if Update flagis cleared
     */
    void clearBuffer(void);

    /*
     * Writes text to display using specified font table
     * @column - bit column where write starts
     * @page - Page that write starts (0-7 valid)  A page is 8 pixels vertical on display.
     * @*font_address - address pointer to font table to use
     * @*str - pointer to string array to display
     * @size - size of data in str
     */
    void writeText(uint8_t column, uint8_t page, const uint8_t *font_address, const char *str, const uint8_t size);

    /*
     *Writes text to display using specified font table
     * @column - bit column where write starts
     * @page - Page that write starts (0-7 valid). A page is 8 pixels vertical on display.
     * @*bm_address - pointer to uint8_t array with bitmap data to display
     */
    void writeBitmap(uint8_t column, uint8_t page, const uint8_t *bm_address);

    /*
     * Allows LCD buffer to be update without changing LCD
     * Each call increments the Update semaphore and required a matching endUpdate
     */
    void startUpdate(void);

    /*
     * Enables direct updates to LCD and sends buffer to LCD
     * Each call decrements the Update semephore. If the Update semaphore is cleared,
     * the LCD is updated. 
     */
    void endUpdate(void);

    /** Gets state of update semaphore
     * @return update semaphore flag state 0 = direct update of LCD >0 is update LCD buffer only
     */
    uint8_t getUpdateState(void);


private:

    SPI				*_spi;
    DigitalOut		*_lcd_cs;
    DigitalOut		*_cmnd_data;
    uint8_t			_lcdbuffer[LCDWIDTH*LCDPAGES];
    uint8_t			_update_flag;
    
    uint8_t init(void);

    void sendBuffer(const uint8_t* buffer);

    /** Write to a command register
     *  @param reg - The register to be written
     *  @param data - pointer to char data buffer
     *  @param count - size of char data buffer, default 1 if not defined
     */
    uint8_t writeCommand(uint8_t const reg, uint8_t const data = 0) const;
    
    /** Write data to LCD screen buffer (exposed for debugging reasons)
     *  @param count - Size of the char data buffer
     *  @param data - pointer to char data buffer
     *  @return The status
     */
    void writeData(const uint8_t* data, uint8_t count) const;

    /** Sets the cursor location
     *  @param xcur - x-cursor location in pixels. value is clipped if outside display size
     *  @param ycur - y-cursor location in pixels. value is clipped if outside display size
     *  @return - modulus of page that data needs to be shifted
     */
    uint8_t setCursor(uint8_t xcur, uint8_t ycur);
    
};

#endif
