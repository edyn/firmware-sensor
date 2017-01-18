/**
 * @file    MPL3115A2.cpp
 * @brief   Device driver - MPL3115A2 barometric pressure IC w/RTOS support
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

#include "MPL3115A2.h"
#include "mbed_debug.h"
#include "rtos.h"

MPL3115A2::MPL3115A2( I2C &i2c, InterruptIn* int1, InterruptIn* int2)
{
    _i2c =  &i2c;
    _int1 = int1;
    _int2 = int2;

    MPL3115A2::init();

    return;
}

bool MPL3115A2::testWhoAmI(void)
{
    char reg_val[1];

    reg_val[0] = 0x00;
    MPL3115A2::readRegister(WHO_AM_I,reg_val);

    return (reg_val[0] == I_AM_MPL3115A2);

}

uint8_t MPL3115A2::init(void)
{
    uint8_t result = 0;
    uint8_t i = 0;
    char reg_val[1];

    __disable_irq();
    _i2c->frequency(400000);
    __enable_irq();

    // Reset all registers to POR values
    reg_val[0] = 0x04;
    result = MPL3115A2::writeRegister(CTRL_REG1, reg_val);
    if (result == 0) {
        do {
            // wait for the reset bit to clear. readRegister may error out so we re-try 10 times
            osDelay(200);
            reg_val[0] = 0x40;
            result = MPL3115A2::readRegister(CTRL_REG1,reg_val);
            reg_val[0] = reg_val[0] & 0x04;
            i++;
        } while(((reg_val[0] != 0) || (result != 0)) && (i<=10));
    }

    if ((result == 0) && (MPL3115A2::testWhoAmI() == true)) {

        if ((_int1 == NULL) && (_int2 == NULL)) {
            _polling_mode = true;
            reg_val[0] = 0x07;
            result |= MPL3115A2::writeRegister(PT_DATA_CFG,reg_val);
        } else _polling_mode = false;
    } else {
        debug ("Device not supported by this library!\n\r");
        result = 1;
    }

    if(result != 0) {
        debug("MPL3115A2:init failed\n\r");
    }

    return result;
}

uint8_t MPL3115A2::setParameters(OUTPUT_MODE out_mode, DATA_MODE data_mode, OVERSAMPLE_RATIO os_ratio,
                                 ACQUISITION_TIMER measure_time)
{
    uint8_t result = 0;
    char datain[4];
    char dataout[4];

    result |= MPL3115A2::readRegister(SYSMOD, datain); // Make sure MPL3115A2 is in Stand-By mode
    if ((datain[0] & 0x01) != 0 ) {
        debug ("MPL3115A2 not in STAND BY mode\n\f");
        debug("MPL3115A2:setParameters failed\n\r");
        result = 1;
        return result;
    }

    result |= MPL3115A2::readRegister(CTRL_REG1, datain, 2);
    dataout[0] = (datain[0] & 0x07) | os_ratio | out_mode | data_mode;
    dataout[1] = (datain[1] & 0xF0) | measure_time;
    result |= MPL3115A2::writeRegister(CTRL_REG1, dataout, 2);

    if(result != 0) {
        debug("MPL3115A2:setParameters failed\n\r");
    }

    return result;
}

uint8_t MPL3115A2::enableFIFO(void)
{
    uint8_t result = 0;
    return result;
}

uint8_t MPL3115A2::activeMode(void)
{
    uint8_t result = 0;
    char datain[1];
    char dataout[1];

    result |= MPL3115A2::readRegister(CTRL_REG1, datain , 2);
    dataout[0] = (datain[0] & 0xFE) | 0x01 ;
    result |= MPL3115A2::writeRegister(CTRL_REG1, dataout);        // Set to active mode

    return result;
}
uint8_t MPL3115A2::standbyMode(void)
{
    uint8_t result = 0;
    char datain[1];
    char dataout[1];

    result |= MPL3115A2::readRegister(CTRL_REG1, datain);
    dataout[0] = (datain[0] & 0xFE);
    result |= MPL3115A2::writeRegister(CTRL_REG1, dataout);        // Set to standby mode

    return result;
}

uint8_t MPL3115A2::triggerOneShot(void)
{
    uint8_t result = 0;
    char datain[1];
    char dataout[1];

    result |= MPL3115A2::readRegister(CTRL_REG1, datain);
    dataout[0] = ((datain[0] & 0xFD) | 0x02);
    result |= MPL3115A2::writeRegister(CTRL_REG1, dataout);        // Trigger a measurement

    return result;
}

uint8_t MPL3115A2::setAltitudeCalib(int16_t alti_calib)
{
    uint8_t result = 0;
    char dataout[1];

    dataout[0] = alti_calib ;
    result |= MPL3115A2::writeRegister(CTRL_REG1, dataout);        // set msb of calibration value

    return result;
}

uint8_t MPL3115A2::clearMinMaxRegs(void)
{
    uint8_t result = 0;
    char datain[10];

    memset(datain, 0, 10);
    result = MPL3115A2::writeRegister(P_MIN_MSB, datain, 10);

    return result;
}

uint8_t MPL3115A2::getStatus(void)
{
    char datain[1];
    uint8_t dataout;

    MPL3115A2::readRegister(DR_STATUS, datain);
    dataout = datain[0];

    return dataout;
}

int32_t MPL3115A2::getBaroData(void)
{
    if (_polling_mode) {
        char datain[3];
        MPL3115A2::readRegister(OUT_P_MSB, datain, 3);
        /* data is 20 bit signed/unsigned with 4 LSB = 0 Need to shift to 32 bits to preserve sign bit
         * Altitude is 16 bit signed and pressure is 18 bit unsigned
         */
        _data._baro = ((datain[0] << 24) | (datain[1] << 16) | (datain[2]<<8));
    }
    return _data._baro;
}

int16_t MPL3115A2::getTempData(void)
{
    if (_polling_mode) {
        char datain[2];
        MPL3115A2::readRegister(OUT_T_MSB, datain, 2);
        /* data is 12 bit signed with 4 LSB = 0 Need to shift first to 16 bits to preserve sign bit then
         *  divide by 16 to remove LSBs
         */
        _data._temp = ((datain[0] << 8) | datain[1]);
        _data._temp /= 16;
    }
    return _data._temp;
}

int32_t MPL3115A2::getMinBaro(bool clear_data)
{
    if (_polling_mode) {
        char datain[3];
        MPL3115A2::readRegister(P_MIN_MSB, datain, 3);
        /* data is 20 bit signed/unsigned with 4 LSB = 0 Need to shift to 32 bits to preserve sign bit
         * Altitude is 16 bit signed and pressure is 18 bit unsigned
         */
        _data._minbaro = ((datain[0] << 24) | (datain[1] << 16) | (datain[2] << 8));

        if (clear_data) {
            memset(datain, 0, 3);
            MPL3115A2::writeRegister(P_MIN_MSB, datain, 3);
        }
    }

    return _data._minbaro;
}

int32_t MPL3115A2::getMaxBaro(bool   clear_data)
{
    if (_polling_mode) {
        char datain[3];

        MPL3115A2::readRegister(P_MAX_MSB, datain, 3);
        /* data is 20 bit signed/unsigned with 4 LSB = 0 Need to shift to 32 bits to preserve sign bit
         * Altitude is 16 bit signed and pressure is 18 bit unsigned
         */
        _data._maxbaro = ((datain[0] << 24) | (datain[1] << 16) | (datain[2] << 8));

        if (clear_data) {
            memset(datain, 0, 3);
            MPL3115A2::writeRegister(P_MAX_MSB, datain, 3);
        }
    }

    return _data._maxbaro;
}

int16_t MPL3115A2::getMinTemp(bool   clear_data)
{
    if (_polling_mode) {
        char datain[2];
        MPL3115A2::readRegister(T_MIN_MSB, datain, 2);
        /* data is 12 bit signed with 4 LSB = 0 Need to shift first to 16 bits to preserve sign bit then
         *  divide by 16 to remove LSBs
         */
        _data._mintemp = ((datain[0] << 8) | datain[1] );
        _data._mintemp /= 16;

        if (clear_data) {
            memset(datain, 0, 2);
            MPL3115A2::writeRegister(T_MIN_MSB, datain, 2);
        }
    }

    return _data._mintemp;
}

int16_t MPL3115A2::getMaxTemp(bool   clear_data)
{
    if (_polling_mode) {
        char datain[2];
        MPL3115A2::readRegister(T_MIN_MSB, datain, 2);
        /* data is 12 bit signed with 4 LSB = 0 Need to shift first to 16 bits to preserve sign bit then
         *  divide by 16 to remove LSBs
         */
        _data._maxtemp = ((datain[0] << 8) | datain[1] );
        _data._maxtemp /= 16;

        if (clear_data) {
            memset(datain, 0, 2);
            MPL3115A2::writeRegister(T_MAX_MSB, datain, 2);
        }
    }

    return _data._maxtemp;
}

MPL3115A2_DATA MPL3115A2::getAllData(bool clear_data)
{

    if (_polling_mode) {
        char datain[10];
        MPL3115A2::readRegister(OUT_P_MSB, datain, 5);
        /* data is 20 bit signed/unsigned with 4 LSB = 0 Need to shift to 32 bits to preserve sign bit
         * Altitude is 16 bit signed and pressure is 18 bit unsigned
         */
        _data._baro = ((datain[0] << 24) | (datain[1] << 16) | (datain[2]<<8));

        /* data is 12 bit signed with 4 LSB = 0 Need to shift first to 16 bits to preserve sign bit then
         *  divide by 16 to remove LSBs
         */
        _data._temp = ((datain[3] << 8) | datain[4]);
        _data._temp /= 16;

        MPL3115A2::readRegister(P_MIN_MSB, datain, 10);
        /* data is 20 bit signed/unsigned with 4 LSB = 0 Need to shift to 32 bits to preserve sign bit
         * Altitude is 16 bit signed and pressure is 18 bit unsigned
         *  temperature data is 12 bit signed with 4 LSB = 0 Need to shift first to 16 bits to preserve sign bit then
         *  divide by 16 to remove LSBs
         */
        _data._minbaro = ((datain[0] << 24) | (datain[1] << 16) | (datain[2] << 8));
        _data._mintemp = ((datain[3] << 8) | datain[4] );
        _data._mintemp /= 16;
        _data._maxbaro = ((datain[5] << 24) | (datain[6] << 16) | (datain[7] << 8));
        _data._maxtemp = ((datain[8] << 8) | datain[9] );
        _data._maxtemp /= 16;

        if (clear_data) {
            MPL3115A2::clearMinMaxRegs();
        }
    }

    return _data;
}

uint8_t MPL3115A2::writeRegister(uint8_t reg, char* data, uint8_t count)
{
    char buf[11];
    uint8_t result = 0;

    buf[0] = reg;
    memcpy(buf+1,data,count);

    __disable_irq(); // Tickers and other timebase events can jack up the I2C bus for some devices
    result |= _i2c->write(_i2c_addr, buf, (count + 1));
    __enable_irq();  // Just need to block during the transaction

    if(result != 0) {
        debug("MPL3115A2:writeRegister failed\n\r");
    }

    return result;
}

uint8_t MPL3115A2::readRegister(uint8_t reg, char* data, uint8_t count)
{
    uint8_t result = 0;
    char reg_out[1];

    reg_out[0] = reg;
    __disable_irq(); // Tickers and other timebase events can jack up the I2C bus for some devices
    result |= _i2c->write(_i2c_addr,reg_out,1,true);
     __enable_irq();  // Just need to block during the transaction

    if(result != 0) {
        debug("MPL3115A2::readRegister failed write\n\r");
        return result;
    }

      __disable_irq(); // Tickers and other timebase events can jack up the I2C bus for some devices
    result |= _i2c->read(_i2c_addr,data,count,false);
      __enable_irq();  // Just need to block during the transaction

    if(result != 0) {
        debug("MPL3115A2::readRegister failed read\n\r");
    }

    return result;
}
