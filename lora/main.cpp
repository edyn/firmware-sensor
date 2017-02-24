#include "mbed.h"
#include "mDot.h"
#include "CommandTerminal.h"
#include "ATSerial.h"
#include "ATSerialFlowControl.h"

#define SERIAL_BUFFER_SIZE 512

Serial debug(PA_2, PA_3);

#ifndef UNIT_TEST

int main()
{
    debug.baud(9600);

    mDot* dot = mDot::getInstance();

    // Seed the RNG
    srand(dot->getRadioRandom());

    mts::ATSerial* serial;

    if (dot->getFlowControl())
#if defined(TARGET_MTS_MDOT_F411RE)
        serial = new mts::ATSerialFlowControl(XBEE_DOUT, XBEE_DIN, XBEE_RTS, XBEE_CTS, SERIAL_BUFFER_SIZE, SERIAL_BUFFER_SIZE);
#else
        serial = new mts::ATSerialFlowControl(PA_2, PA_3, UART1_RTS, UART1_CTS, SERIAL_BUFFER_SIZE, SERIAL_BUFFER_SIZE);
#endif
    else
printf("awepog");
#if defined(TARGET_MTS_MDOT_F411RE)
        serial = new mts::ATSerial(XBEE_DOUT, XBEE_DIN, SERIAL_BUFFER_SIZE, SERIAL_BUFFER_SIZE);
#else
        serial = new mts::ATSerial(PA_2, PA_3, SERIAL_BUFFER_SIZE, SERIAL_BUFFER_SIZE);
#endif

    debug.baud(dot->getDebugBaud());
    serial->baud(dot->getBaud());

    CommandTerminal term(*serial);
    CommandTerminal::_dot = dot;

    term.init();

    term.start();
}

#endif // UNIT_TEST
