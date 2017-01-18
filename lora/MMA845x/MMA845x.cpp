/**
 * @file    MMA845x.cpp
 * @brief   Device driver - MMA845X 3-axis accelerometer IC W/RTOS support
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
 *
 * 5/5/2015 Forked from https://developer.mbed.org/users/sam_grove/code/MMA845x/
 *
 * 6/20/2015 TAB Added setup functions and polling data capability. Also added RTOS calls
 * TODO Still need to add interrupt support for other Accelerometer mode support
 */

#include "MMA845x.h"
#include "mbed_debug.h"
#include "rtos.h"

MMA845x::MMA845x(I2C &i2c, SA0 const i2c_addr, InterruptIn* int1, InterruptIn* int2)
{
    _i2c =  &i2c;
    _int1 = int1;
    _int2 = int2;

    _i2c_addr = (0x1c | i2c_addr) << 1;

    MMA845x::init();

    return;
}

uint8_t MMA845x::init(void)
{
    uint8_t result = 0;
    uint8_t i = 0;
    char reg_val[1];

    __disable_irq();
    _i2c->frequency(100000);
    __enable_irq();
    _who_am_i = 0x00;

    // Reset all registers to POR values
    result = MMA845x::writeRegister(CTRL_REG2, 0xFF);        //REG 0x2B
    if (result == 0) {

        do {
            // wait for the reset bit to clear. readRegister may error out so we re-try 10 times
            osDelay(200);
            reg_val[0] = 0x40;
            result = MMA845x::readRegister(CTRL_REG2,1,reg_val);
            reg_val[0] = reg_val[0] & 0x40;
            i++;
        } while(((reg_val[0] != 0)||( result != 0)) && (i<=10));
    }

    if (result == 0) {
        result = MMA845x::readRegister(WHO_AM_I,1,reg_val);
    }

    switch (reg_val[0]) {
        case MMA8451:
        case MMA8452:
        case MMA8453:
            _who_am_i= reg_val[0];
            if ((_int1 == NULL) && (_int2 == NULL))
                _polling_mode = true;
            else _polling_mode = false;
            break;
        default:
            debug ("Device not supported by this library!\n\r");
            result = 1;
    }

    if(result != 0) {
        debug("MMA845x:init failed\n\r");
    }


    return result;
}

uint8_t MMA845x::setCommonParameters(RANGE range, RESOLUTION resolution, LOW_NOISE lo_noise,
                                     DATA_RATE data_rate, OVERSAMPLE_MODE os_mode, HPF_MODE hpf_mode) const
{
    uint8_t result = 0;
    char datain[1];
    uint8_t dataout = 0;

    result |= MMA845x::readRegister(SYSMOD,1,datain); // Make sure MMA845x is in Stand-By mode
    if ((datain[0] & 0x03) != 0 ) {
        debug ("MMA845x not in STAND BY mode\n\f");
        debug("MMA845x:setCommonParameters failed\n\r");
        result = 1;
        return result;
    }

    result |= MMA845x::readRegister(CTRL_REG1, 1, datain);
    dataout = (datain[0] & 0xB1) | resolution | lo_noise | data_rate;
    result |= MMA845x::writeRegister(CTRL_REG1, dataout);        // Set resolution, Low Noise mode, and data rate

    result |= MMA845x::readRegister(CTRL_REG2,1, datain);
    dataout = (datain[0] & 0xFB) | os_mode;
    result |= MMA845x::writeRegister(CTRL_REG2, dataout);        // Set Oversample mode

    result |= MMA845x::readRegister(XYZ_DATA_CFG,1, datain);
    dataout = range | hpf_mode;
    result |= MMA845x::writeRegister(XYZ_DATA_CFG, dataout);     //Set HPF mode and range

//    result |= MMA845x::readRegister(HP_FILTER_CUTOFF,1, datain);
//    result |= MMA845x::writeRegister(HP_FILTER_CUTOFF, dataout); //REG 0xF HPF settings

    if(result != 0) {
        debug("MMA845x:setParameters failed\n\r");
    }

    return result;

}

uint8_t MMA845x::enableMotionDetect(void) const
{
    uint8_t result = 0;
    return result;
}

uint8_t MMA845x::enablePulseDetect(void) const
{
    uint8_t result = 0;
    return result;
}

uint8_t MMA845x::enableOrientationDetect(void) const
{
    uint8_t result = 0;

    if(_who_am_i != MMA8451) {
        debug("%s %d: Feature not compatible with the connected device.\n", __FILE__, __LINE__);
        result = 1;
    }

    return result;
}

uint8_t MMA845x::enableTransientDetect(void) const
{
    uint8_t result = 0;
    return result;
}

uint8_t MMA845x::enableAutoSleep(void) const
{
    uint8_t result = 0;
    return result;
}

uint8_t MMA845x::enableFIFO(void) const
{
    uint8_t result = 0;

    if(_who_am_i != MMA8451) {
        debug("%s %d: Feature not compatible with the connected device.\n", __FILE__, __LINE__);
        result = 1;
    }

    return result;
}

uint8_t MMA845x::activeMode(void) const
{
    uint8_t result = 0;
    char datain[1];
    uint8_t dataout;

    result |= MMA845x::readRegister(CTRL_REG1,1, datain);
    dataout = (datain[0] & 0xFE) | 0x01 ;
    result |= MMA845x::writeRegister(CTRL_REG1, dataout);        // Set to active mode

    return result;
}
uint8_t MMA845x::standbyMode(void) const
{
    uint8_t result = 0;
    char datain[1];
    uint8_t dataout;

    result |= MMA845x::readRegister(CTRL_REG1,1, datain);
    dataout = (datain[0] & 0xFE);
    result |= MMA845x::writeRegister(CTRL_REG1, dataout);        // Set to standby mode

    return result;
}

uint8_t MMA845x::getStatus(void) const
{
    uint8_t result = 0;
    char datain[1];
    uint8_t dataout;

    result = MMA845x::readRegister(STATUS,1, datain);

    if (result != 0)
        dataout = result;
    else
        dataout = datain[0];

    return dataout;
}

int16_t MMA845x::getX(void)
{
    char datain[2];

    if (_polling_mode) {
        MMA845x::readRegister(OUT_X_MSB,2, datain);
        _data._x = ((datain[0] << 8) | datain[1]);  /* data is 14 bit signed with 2 LSB = 0 */
        _data._x /= 4;        /* need to shift first to preserve sign then /4 to remove LSBs */
    }
    return _data._x;

}

int16_t MMA845x::getY(void)
{
    char datain[2];

    if (_polling_mode) {
        MMA845x::readRegister(OUT_Y_MSB,2, datain);
        _data._y = ((datain[0] << 8) | datain[1]);   /* data is 14 bit signed with 2 LSB = 0 */
        _data._y /= 4;        /* need to shift first to preserve sign then /4 to remove LSBs */
    }
    return _data._y;
}

int16_t MMA845x::getZ(void)
{
    char datain[2];

    if (_polling_mode) {
        MMA845x::readRegister(OUT_Z_MSB,2, datain);
        _data._z = ((datain[0] << 8) | datain[1]);   /* data is 14 bit signed with 2 LSB = 0 */
        _data._z /= 4;        /* need to shift first to preserve sign then /4 to remove LSBs */
    }

    return _data._z;
}

MMA845x_DATA MMA845x::getXYZ(void)
{
    char datain[6];

    if (_polling_mode) {
        MMA845x::readRegister(OUT_X_MSB,6, datain);   /* data is 14 bit signed with 2 LSB = 0 */
        _data._x = ((datain[0] << 8) | datain[1]);    /* need to shift first to preserve sign */
        _data._x /= 4;                                /* then /4 to remove LSBs */
        _data._y = ((datain[2] << 8) | datain[3]);
        _data._y /= 4;
        _data._z = ((datain[4] << 8) | datain[5]);
        _data._z /= 4;
    }

    return _data;
}

char MMA845x::getWhoAmI(void) const
{
    return _who_am_i;
}

uint8_t MMA845x::writeRegister(uint8_t const reg, uint8_t const data) const
{
    char buf[2] = {reg, data};
    uint8_t result = 0;

    buf[0] = reg;
    buf[1] = data;

    __disable_irq(); // Tickers and other timebase events can jack up the I2C bus for some devices
    result |= _i2c->write(_i2c_addr, buf, 2);
    __enable_irq();  // Just need to block during the transaction

    if(result != 0) {
        debug("MMA845x:writeRegister failed r-%d\n\r",result);
    }

    return result;
}

uint8_t MMA845x::readRegister(uint8_t const reg, uint8_t count, char* data) const
{
    uint8_t result = 0;
    char reg_out[1];

    reg_out[0] = reg;
   __disable_irq(); // Tickers and other timebase events can jack up the I2C bus for some devices
    result |= _i2c->write(_i2c_addr,reg_out,1,true);
   __enable_irq();  // Just need to block during the transaction

    if(result != 0) {
        debug("MMA845x::readRegister failed write r- %d\n\r", result);
        return result;
    }

   __disable_irq(); // Tickers and other timebase events can jack up the I2C bus for some devices
    result |= _i2c->read(_i2c_addr,data,count,false);
    __enable_irq();  // Just need to block during the transaction

    if(result != 0) {
        debug("MMA845x::readRegister failed read r-%d\n\r",result);
    }

    return result;
}
