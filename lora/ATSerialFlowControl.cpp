#include "mbed.h"
#include "ATSerialFlowControl.h"
#include "MTSLog.h"
#include "Utils.h"

using namespace mts;

ATSerialFlowControl::ATSerialFlowControl(PinName TXD, PinName RXD, PinName RTS, PinName CTS, int txBufSize, int rxBufSize)
    : ATSerial(TXD, RXD, txBufSize, rxBufSize)
    , rxReadyFlag(false)
    , rts(RTS)
    , cts(CTS)
{
    notifyStartSending();

    // Calculate the high and low watermark values
    highThreshold = mts_max(rxBufSize - 10, rxBufSize * 0.85);
    lowThreshold = rxBufSize * 0.3;

    // Setup the low watermark callback on the internal receive buffer
    rxBuffer.attach(this, &ATSerialFlowControl::notifyStartSending, lowThreshold, LESS);
}

ATSerialFlowControl::~ATSerialFlowControl()
{
}

//Override the rxClear function to make sure that flow control lines are set correctly.
void ATSerialFlowControl::rxClear()
{
    MTSBufferedIO::rxClear();
    notifyStartSending();
}

void ATSerialFlowControl::notifyStartSending()
{
    if(!rxReadyFlag) {
        rts.write(0);
        rxReadyFlag = true;
        //printf("RTS LOW: READY - RX[%d/%d]\r\n", rxBuffer.size(), rxBuffer.capacity());
    }
}

void ATSerialFlowControl::notifyStopSending()
{
    if(rxReadyFlag) {
        rts.write(1);
        rxReadyFlag = false;
        //printf("RTS HIGH: NOT-READY - RX[%d/%d]\r\n", rxBuffer.size(), rxBuffer.capacity());
    }
}

void ATSerialFlowControl::handleRead()
{
    ATSerial::handleRead();
    if (rxBuffer.size() >= highThreshold) {
        notifyStopSending();
    }
}

void ATSerialFlowControl::handleWrite()
{
    while(txBuffer.size() != 0) {
        if (_serial->writeable() && cts.read() == 0) {
            char byte;
            if(txBuffer.read(byte) == 1) {
                _serial->attach(NULL, Serial::RxIrq);
                _serial->putc(byte);
                _serial->attach(this, &ATSerialFlowControl::handleRead, Serial::RxIrq);
            }
        } else {
            return;
        }
    }
}
