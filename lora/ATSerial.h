#ifndef ATSERIAL_H
#define ATSERIAL_H

#include "MTSSerial.h"
#include "MTSBufferedIO.h"

namespace mts
{

/** This class derives from MTSBufferedIO and provides a buffered wrapper to the
* standard mbed Serial class. Since it depends only on the mbed Serial class for
* accessing serial data, this class is inherently portable accross different mbed
* platforms.
*/
class ATSerial : public MTSSerial
{
public:
    /** Creates a new ATSerial object that can be used to talk to an mbed serial port
    * through internal SW buffers.
    *
    * @param TXD the transmit data pin on the desired mbed Serial interface.
    * @param RXD the receive data pin on the desired mbed Serial interface.
    * @param txBufferSize the size in bytes of the internal SW transmit buffer. The
    * default is 256 bytes.
    * @param rxBufferSize the size in bytes of the internal SW receive buffer. The
    * default is 256 bytes.
    */
    ATSerial(PinName TXD, PinName RXD, int txBufferSize = 256, int rxBufferSize = 256);

    /** Destructs an ATSerial object and frees all related resources, including
    * internal buffers.
    */
    virtual ~ATSerial();

    /**
     * Attach the internal serial object to provided pins
     * @param TXD the transmit data pin on the desired mbed Serial interface.
     * @param RXD the receive data pin on the desired mbed Serial interface.
     */
    void reattach(PinName TXD, PinName RXD);

    /** This method is used to the set the baud rate of the serial port.
    *
    * @param baudrate the baudrate in bps as an int. The default is 9600 bps.
    */
    void baud(int baudrate);

    /** This method sets the transmission format used by the serial port.
    *
    * @param bits the number of bits in a word (5-8; default = 8)
    * @param parity the parity used (SerialBase::None, SerialBase::Odd, SerialBase::Even,
    * SerialBase::Forced1, SerialBase::Forced0; default = SerialBase::None)
    * @param stop the number of stop bits (1 or 2; default = 1)
    */
    void format(int bits=8, SerialBase::Parity parity=mbed::SerialBase::None, int stop_bits=1);

    /** Generate a break condition on the serial line
     */
    void sendBreak();

    /** Check for escape sequence detected on serial input
     *  @return true if escape sequence was seen
     */
    bool escaped();

    void escapeChar(char esc);

    char escapeChar();

    void clearEscaped();


protected:

    RawSerial* _serial; // Internal mbed Serial object
    int _baudrate;
    int _bits;
    SerialBase::Parity _parity;
    int _stop_bits;
    Timer timer;
    int _last_time;
    int _esc_cnt;
    char _esc_ch;
    bool _escaped;

    virtual void handleWrite(); // Method for handling data to be written
    virtual void handleRead(); // Method for handling data to be read


};

}

#endif /* ATSERIAL_H */
