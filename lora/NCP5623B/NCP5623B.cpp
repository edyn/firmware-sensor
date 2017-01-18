/**
 * @file    NCP5623B.cpp
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
 */

#include "NCP5623B.h"
#include "mbed_debug.h"
#include "rtos.h"

NCP5623B::NCP5623B(I2C &i2c)
{
    _i2c =  &i2c;

    NCP5623B::init();

    return;
}

uint8_t NCP5623B::init(void)
{
    uint8_t result = 0;

    __disable_irq();
    _i2c->frequency(400000);
    __enable_irq();

    // Turn off all LEDs and initialize all registers
    result |= NCP5623B::writeRegister(NCP5623B::DIMDWNSET, 0x00);
    result |= NCP5623B::writeRegister(NCP5623B::DIMTIME, 0x01);
    osDelay (1000);
    result |= NCP5623B::writeRegister(NCP5623B::LEDCURR, 0x00);
    result |= NCP5623B::writeRegister(NCP5623B::PWMLED1, 0x00);
    result |= NCP5623B::writeRegister(NCP5623B::PWMLED2, 0x00);
    result |= NCP5623B::writeRegister(NCP5623B::PWMLED3, 0x00);

    return result;
}

/** Shutdown LEDS
 *  @return status of command
 */
uint8_t NCP5623B::shutdown(void) const
{
    uint8_t result = 0;

    result |= NCP5623B::writeRegister(NCP5623B::SHUTDWN, 0x00);
    return result;

}

/** Set static LED Current
 *  data - value of current draw for all LEDs range 0-31
 *  @return status of command
 */
uint8_t NCP5623B::setLEDCurrent(uint8_t data) const
{
    uint8_t result = 0;

    result |= NCP5623B::writeRegister(NCP5623B::LEDCURR, data);
    return result;
}

/** Set PWM mode for specific LED
 *  @lednum - selects LED
 *  @data - PWM value to set  range 0-31 0-100% Pulse width
 *  @return status of command
 */
uint8_t NCP5623B::setPWM(LEDNUM lednum, int8_t data ) const
{
    uint8_t result = 0;

    switch (lednum) {
        case NCP5623B::LED_1:
            result |= NCP5623B::writeRegister(NCP5623B::PWMLED1, data);
            break;
        case NCP5623B::LED_2:
            result |= NCP5623B::writeRegister(NCP5623B::PWMLED2, data);
            break;
        case NCP5623B::LED_3:
            result |= NCP5623B::writeRegister(NCP5623B::PWMLED3, data);
            break;
    }
    return result;
}

/** Set Dimming mode for all LEDs
 *  @dimdir - direction of dimming
 *  @endstep - ending step of ramp up or ramp down range 0-31
 *  @steptime - time per step range 0-31 in 8 msec multiples
 *  @return status of command
 */
uint8_t NCP5623B::setDimming(DIMDIRECTION dimdir, uint8_t endstep, uint8_t steptime) const
{
    uint8_t result = 0;

    if (dimdir == NCP5623B::DIMDWN)
        result |= NCP5623B::writeRegister(NCP5623B::DIMDWNSET, endstep);
    else
        result |= NCP5623B::writeRegister(NCP5623B::DIMUPSET, endstep);

    result |= NCP5623B::writeRegister(NCP5623B::DIMTIME, steptime);

    return result;
}
/** Write to a register (exposed for debugging reasons)
 * @param reg - The register to be written
 * @param data - The data to be written
 */
uint8_t NCP5623B::writeRegister(NCP5623B::REGISTER const reg, uint8_t const data) const
{
    char buf[1];
    uint8_t result = 0;

    buf[0] = reg | (data & NCP5623B::DATAMASK);

    __disable_irq();
    result |= _i2c->write(_i2c_addr, buf, 1);
    __enable_irq();

    return result;
}
