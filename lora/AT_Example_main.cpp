#include "mbed.h"
#include "mDot.h"
#include "CommandTerminal.h"
#include "ATSerial.h"
#include "ATSerialFlowControl.h"

#define SERIAL_BUFFER_SIZE 512

Serial debug(USBTX, USBRX);

#ifndef UNIT_TEST

int main()
{
    debug.baud(115200);

    mDot* dot = mDot::getInstance();

    // Seed the RNG
    srand(dot->getRadioRandom());

    mts::ATSerial* serial;

    if (dot->getFlowControl())
#if defined(TARGET_MTS_MDOT_F411RE)
        serial = new mts::ATSerialFlowControl(XBEE_DOUT, XBEE_DIN, XBEE_RTS, XBEE_CTS, SERIAL_BUFFER_SIZE, SERIAL_BUFFER_SIZE);
#else
        serial = new mts::ATSerialFlowControl(UART1_TX, UART1_RX, UART1_RTS, UART1_CTS, SERIAL_BUFFER_SIZE, SERIAL_BUFFER_SIZE);
#endif
    else
#if defined(TARGET_MTS_MDOT_F411RE)
        serial = new mts::ATSerial(XBEE_DOUT, XBEE_DIN, SERIAL_BUFFER_SIZE, SERIAL_BUFFER_SIZE);
#else
        serial = new mts::ATSerial(UART1_TX, UART1_RX, SERIAL_BUFFER_SIZE, SERIAL_BUFFER_SIZE);
#endif

    debug.baud(dot->getDebugBaud());
    serial->baud(dot->getBaud());

    CommandTerminal term(*serial);
    CommandTerminal::_dot = dot;

    term.init();

    term.start();
}

#endif // UNIT_TEST

