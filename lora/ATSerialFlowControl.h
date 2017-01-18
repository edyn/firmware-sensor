#ifndef ATSERIALFLOWCONTROL_H
#define ATSERIALFLOWCONTROL_H

#include "ATSerial.h"

namespace mts
{

/** This class derives from MTSBufferedIO/ATSerial and provides a buffered wrapper to the
* standard mbed Serial class along with generic RTS/CTS HW flow control. Since it
* depends only on the mbed Serial, DigitalOut and DigitalIn classes for accessing
* the serial data, this class is inherently portable accross different mbed platforms
* and provides HW flow control even when not natively supported by the processors
* serial port. If HW flow control is not needed, use ATSerial instead. It should also
* be noted that the RTS/CTS functionality in this class is implemented as a DTE device.
*/
class ATSerialFlowControl : public ATSerial
{
public:
    /** Creates a new ATSerialFlowControl object that can be used to talk to an mbed serial
    * port through internal SW buffers. Note that this class also adds the ability to use
    * RTS/CTS HW Flow Conrtol through and standard mbed DigitalIn and DigitalOut pins.
    * The RTS and CTS functionality assumes this is a DTE device.
    *
    * @param TXD the transmit data pin on the desired mbed serial interface.
    * @param RXD the receive data pin on the desired mbed serial interface.
    * @param RTS the DigitalOut pin that RTS will be attached to. (DTE)
    * @param CTS the DigitalIn pin that CTS will be attached to. (DTE)
    * @param txBufferSize the size in bytes of the internal SW transmit buffer. The
    * default is 256 bytes.
    * @param rxBufferSize the size in bytes of the internal SW receive buffer. The
    * default is 256 bytes.
    */
    ATSerialFlowControl(PinName TXD, PinName RXD, PinName RTS, PinName CTS, int txBufSize = 256, int rxBufSize = 256);

    /** Destructs an ATSerialFlowControl object and frees all related resources.
    */
    virtual ~ATSerialFlowControl();
    
    //Overriden from MTSBufferedIO to support flow control correctly
    virtual void rxClear();

private:
    void notifyStartSending(); // Used to set cts start signal
    void notifyStopSending(); // Used to set cts stop signal
    
    //This device acts as a DTE
    bool rxReadyFlag;   //Tracks state change for rts signaling
    DigitalOut rts; // Used to tell DCE to send or not send data
    DigitalIn cts; // Used to check if DCE is ready for data
    int highThreshold; // High water mark for setting cts to stop
    int lowThreshold; // Low water mark for setting cts to start

    virtual void handleRead(); // Method for handling data to be read
    virtual void handleWrite(); // Method for handling data to be written
};

}

#endif /* MTSSERIALFLOWCONTROL */
