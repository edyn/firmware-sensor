/**
 * @file    DOGS102.cpp
 * @brief   Device driver - DOGS102 102x64 pixel Graphic LCD display W/RTOS Support
 * @author  Tim Barr
 * @version 1.01
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
 * 07/08/15 TAB  Fixed error boundary check error in endUpdate
 */
 
#include "DOGS102.h"
#include "mbed_debug.h"
#include "rtos.h"

// macro to make sure x falls into range from low to high (inclusive)
#define CLIP(x, low, high) { if ( (x) < (low) ) x = (low); if ( (x) > (high) ) x = (high); } while (0);
 
DOGS102::DOGS102(SPI &spi, DigitalOut &lcd_cs, DigitalOut &cmnd_data)
{
    _spi =  &spi;
    _lcd_cs = &lcd_cs;
    _cmnd_data = &cmnd_data;

    DOGS102::init();
    
    return;
}
uint8_t DOGS102::setCursor(uint8_t xcur, uint8_t ycur)
{
    uint8_t ypage;
    uint8_t y_shift;

	CLIP(xcur, 0, LCDWIDTH-1);
	ypage = ycur/8;
    CLIP(ypage, 0, LCDPAGES-1);
    y_shift = ycur % 8;
    DOGS102::writeCommand(SETPGADDR,ypage);
    DOGS102::writeCommand(SETCOLADDRMSB,xcur>>4);
    DOGS102::writeCommand(SETCOLADDRLSB,xcur);
    return y_shift;
 }

void DOGS102::clearBuffer(void)
{
    memset(_lcdbuffer, 0, sizeof(_lcdbuffer));

    if (!_update_flag)
    {
    	DOGS102::sendBuffer(_lcdbuffer);
    }

}

void DOGS102::writeText(uint8_t column, uint8_t page, const uint8_t *font_address, const char *text, const uint8_t size)
{
	// Position of character data in memory array
	uint16_t pos_array;
	// temporary column, page address, and column_cnt are used
	// to stay inside display area
	uint8_t i,y, column_cnt = 0;

	// font information, needed for calculation
	uint8_t start_code, last_code, width, page_height, bytes_p_char;

	uint8_t *txtbuffer;

	start_code 	 = font_address[2];  // get first defined character
	last_code	 = font_address[3];  // get last defined character
	width		 = font_address[4];  // width in pixel of one char
	page_height  = font_address[6];  // page count per char
	bytes_p_char = font_address[7];  // bytes per char

	if(page_height + page > LCDPAGES) //stay inside display area
		page_height = LCDPAGES - page;

	// The string is displayed character after character. If the font has more then one page,
	// the top page is printed first, then the next page and so on
	for(y = 0; y < page_height; y++)
	{
		txtbuffer = &_lcdbuffer[page*LCDWIDTH + column];
		column_cnt = 0;					// clear column_cnt start point
		i = 0;
		while(( i < size) && ((column_cnt + column) < LCDWIDTH))
		{
			if(text[i] < start_code || (uint8_t)text[i] > last_code) //make sure data is valid
				i++;
			else
			{
				// calculate position of ASCII character in font array
				// bytes for header + (ASCII - startcode) * bytes per char)
				pos_array = 8 + (uint8_t)(text[i++] - start_code) * bytes_p_char;

				// get the dot pattern for the part of the char to print
				pos_array += y*width;

				// stay inside display area
				if((column_cnt + width + column) > LCDWIDTH)
					column_cnt = LCDWIDTH-width;

				// copy character data to buffer
				memcpy (txtbuffer+column_cnt,font_address+pos_array,width);
			}

			column_cnt += width;
		}
		if (!_update_flag)
		{
			setCursor(column,(page+y)*8);	// set start position x and y
			DOGS102::writeData(txtbuffer,column_cnt);
		}
	}
}

void DOGS102::writeBitmap(uint8_t column, uint8_t page, const uint8_t *bm_address)
{
	uint8_t width, page_cnt, bm_pntr;

    width = bm_address[0];
	page_cnt = (bm_address[1] + 7) / 8; //height in pages, add 7 and divide by 8 for getting the used pages (byte boundaries)

	if(width + column > LCDWIDTH) //stay inside display area
		width = LCDWIDTH - column;
	if(page_cnt + page > LCDPAGES)
		page_cnt = LCDPAGES - page;

	for (uint8_t i=0;i < page_cnt;i++ )
	{
		bm_pntr = 2+i*width;
		memcpy(_lcdbuffer+column+((i+page)*LCDWIDTH),bm_address+bm_pntr, width);
	}

	if (_update_flag == 0)
	{
		DOGS102::sendBuffer(_lcdbuffer);
	}
}

void DOGS102::startUpdate(void)
{
	_update_flag++;
}

void DOGS102::endUpdate(void)
{
	if (_update_flag != 0)
		_update_flag--;
	
	if (_update_flag == 0)
	{
		DOGS102::sendBuffer(_lcdbuffer);
	}
}

uint8_t DOGS102::getUpdateState(void)
{
	return _update_flag;
}

uint8_t DOGS102::init(void)
{
    uint8_t result = 0;
    
    __disable_irq();
    _spi->frequency(4000000);
    _spi->format(8,3);		// 8bit transfers, SPI mode 3
    __enable_irq();
    _lcd_cs->write(1);		// initialize chip select pin
    _cmnd_data->write(1);	// initialize command/data pin
    _update_flag = 0;		// initialize update semaphore
    
    // Reset all registers to POR values
//    result = DOGS102::writeCommand(SOFTRESET);
    osDelay(50);

    // send initial setup commands to power up the display
    result |= DOGS102::writeCommand(SETSCROLLLINE,0x00);	// set scroll line to 0
    result |= DOGS102::writeCommand(SETSEGDIR,0x01);		// set reverse seg direction
    result |= DOGS102::writeCommand(SETCOMDIR,0x00);		// set normal com direction
    result |= DOGS102::writeCommand(SETALLPIXELON,0x00);	// disable all pixel on mode
    result |= DOGS102::writeCommand(SETINVDISP,0x00);		// Turn display inverse off
    result |= DOGS102::writeCommand(SETLCDBIAS,0x00);		// set bias ratio to 1/9
    result |= DOGS102::writeCommand(SETPWRCTRL,0x07);		// turn on booster,regulator and follower
    result |= DOGS102::writeCommand(SETVLCDRESRATIO,0x07);	// Set resistor ratio tomax
    result |= DOGS102::writeCommand(SETELECVOL,0x10);		// set contrast to 32 out of 63
    result |= DOGS102::writeCommand(SETAPROGCTRL,0x83);		// enable wrap around bits
    result |= DOGS102::writeCommand(SETDISPEN,0x01);		// set display enable bit

    DOGS102::clearBuffer();

    if(result != 0)
    {
        debug("%s %d: ILS29011:init failed\n\r", __FILE__, __LINE__);
    }
    
     return result;
}

uint8_t DOGS102::writeCommand(uint8_t const reg, uint8_t const data) const
{
    uint8_t buf;
    uint8_t result = 0;

    switch (reg)		// setup data byte for specific command register write
    {
    case SETCOLADDRLSB :
    	// use COLMASK for data
   		buf = SETCOLADDRLSB | (data & COLMASK);
   		break;
    case SETCOLADDRMSB :
    	// use COLMASK for data
   		buf = SETCOLADDRMSB | (data & COLMASK);
    	break;
    case SETPWRCTRL :
    	// use PCMASK for data
    	buf = SETPWRCTRL | (data & PCMASK);
    	break;
    case SETSCROLLLINE :
    	// use SLMASK for data
    	buf = SETSCROLLLINE | (data & SLMASK);
    	break;
    case SETPGADDR :
    	// use COLMASK for data
   		buf = SETPGADDR | (data & COLMASK);
    	break;
    case SETVLCDRESRATIO :
    	// use PCMASK for data
   		buf = SETVLCDRESRATIO | (data & PCMASK);
    	break;
    case SETELECVOL :
    	// double byte command use SLMASK for data
   		buf = data & SLMASK;
    	break;
    case SETALLPIXELON :
		// use LSBMASK for data
   		buf = SETALLPIXELON | (data & LSBMASK);
		break;
    case SETINVDISP :
		// use LSBMASK for data
   		buf = SETINVDISP | (data & LSBMASK);
		break;
    case SETDISPEN :
		// use LSBMASK for data
   		buf = SETDISPEN | (data & LSBMASK);
		break;
    case SETSEGDIR :
		// use LSBMASK for data
   		buf = SETSEGDIR | (data & LSBMASK);
		break;
    case SETLCDBIAS :
		// use LSBMASK for data
   		buf = SETLCDBIAS | (data & LSBMASK);
		break;
    case SETCOMDIR :
    	// use LC1MASK for data
   		buf = SETCOMDIR | ((data << 3) & COLMASK);
    	break;
    case SOFTRESET :
    	// no data mask needed
   		buf = SOFTRESET;
    	break;
    case SETAPROGCTRL :
    	// Double byte command use WAMASK and TCMASK for data
   		buf = data & (COLMASK | TCMASK);
    	break;
    default :
    	debug("Command Register not valid\n\r");
    	result = 1;
    }

    if (result == 0)
    {
	__disable_irq();
        _spi->frequency(4000000);
        _spi->format(8,3);		// 8bit transfers, SPI mode 3
	__enable_irq();

        _lcd_cs->write (0);			// enable LCD SPI interface
    	_cmnd_data->write(0);		// set to command mode

    	switch (reg)				// send first byte of double byte command for these register
    	{
    	case SETELECVOL :
    	case SETAPROGCTRL :
		__disable_irq();
        	_spi->write(reg);
		__enable_irq();
        	break;
        }

	__disable_irq();
    	_spi->write(buf);			// send command register
	__enable_irq();

    	_cmnd_data->write(1);		// set back to data mode
    	_lcd_cs->write(1);			// disable LCD SPI Interface

    }
    
    if(result != 0)
    {
        debug("DOGS102:writeCommand failed\n\r");
    }
    
    return result;
}

void DOGS102::writeData(const uint8_t* data, uint8_t count) const
{
    uint8_t result = 0;
    uint8_t i;
    
    __disable_irq();
    _spi->frequency(4000000);
    _spi->format(8,3);		// 8bit transfers, SPI mode 3
    __enable_irq();

    _lcd_cs->write(0);			// enable LCD SPI interface
	i = 0;						// initialize transfer counter

    do
    {
	__disable_irq();
        _spi->write(data[i]);
	__enable_irq();
        i++;
    } while ((result == 0) && (i <= count)) ;

	_lcd_cs->write(1);			// disable LCD SPI interface
    
    return;
}

void DOGS102::sendBuffer(const uint8_t* buffer)
{
    //debug("Sending LCD Buffer\n");
    for (int i=0; i<LCDPAGES; i++)
    {
    	DOGS102::setCursor(0,i*8);
    	DOGS102::writeData(buffer + i*LCDWIDTH, LCDWIDTH);
    }
}

