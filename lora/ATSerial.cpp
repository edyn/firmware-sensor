#include "mbed.h"
#include "ATSerial.h"
#include "MTSLog.h"

using namespace mts;

ATSerial::ATSerial(PinName TXD, PinName RXD, int txBufferSize, int rxBufferSize)
    : MTSSerial(TXD, RXD, txBufferSize, rxBufferSize)
    , _serial(new RawSerial(TXD,RXD)),
    _baudrate(9600),
    _bits(8),
    _parity(mbed::SerialBase::None),
    _stop_bits(1),
    _last_time(0),
    _esc_cnt(0),
    _esc_ch('+'),
    _escaped(false)
{
    timer.start();
    _serial->attach(this, &ATSerial::handleRead, Serial::RxIrq);
}

ATSerial::~ATSerial()
{
    delete _serial;
}



void ATSerial::baud(int baudrate)
{
    _baudrate = baudrate;
    _serial->baud(_baudrate);
}

void ATSerial::format(int bits, SerialBase::Parity parity, int stop_bits)
{
    _bits = bits;
    _parity = parity;
    _stop_bits = stop_bits;
    _serial->format(_bits, _parity, _stop_bits);
}

void ATSerial::handleWrite()
{
    while(txBuffer.size() != 0) {
        if (_serial->writeable()) {
            char byte;
            if(txBuffer.read(byte) == 1) {
                _serial->attach(NULL, Serial::RxIrq);
                _serial->putc(byte);
                _serial->attach(this, &ATSerial::handleRead, Serial::RxIrq);
            }
        } else {
            return;
        }
    }
}

void mts::ATSerial::reattach(PinName TXD, PinName RXD) {
    delete _serial;
    _serial = new RawSerial(TXD, RXD);
    _serial->attach(this, &ATSerial::handleRead, Serial::RxIrq);
    _serial->baud(_baudrate);
    _serial->format(_bits, _parity, _stop_bits);
    rxBuffer.clear();
    txBuffer.clear();
}

void mts::ATSerial::sendBreak() {
    _serial->send_break();
}

bool ATSerial::escaped() {

    int now = timer.read_ms();

    // Have we seen three esc chars and 1 sec end guard has passed
    if (_escaped || (_esc_cnt == 3 && (now - _last_time > 1000))) {
        _escaped = true;
        return true;

    // Have we seen a couple esc chars but nothing in 500 ms
    } else if (_esc_cnt > 0 && _esc_cnt != 3 && now - _last_time > 500) {
        // Write seen esc chars
        while (_esc_cnt) {
            rxBuffer.write(_esc_ch);
            _esc_cnt--;
        }
    }

    return false;
}

void ATSerial::clearEscaped() {
    _esc_cnt = 0;
    _escaped = false;
}

void ATSerial::handleRead()
{
    char byte = _serial->getc();
    int now = timer.read_ms();

    // Have we seen 3 esc chars but this char is before 1 sec end guard time
    if (_esc_cnt == 3 && (now - _last_time < 1000)) {
        // Write the three chars we held back
        while (_esc_cnt) {
            rxBuffer.write(_esc_ch);
            _esc_cnt--;
        }
    } else if (byte == _esc_ch) {
        // Has 1 second passed before last char
        if (now - _last_time > 1000) {
            _esc_cnt = 1;
        // Is this second or third esc char
        } else if (_esc_cnt > 0 && _esc_cnt < 3) {
            _esc_cnt++;
        }
    } else if (_esc_cnt > 0) {
        // Write any esc chars held back
        while (_esc_cnt) {
            rxBuffer.write(_esc_ch);
            _esc_cnt--;
        }
    }

    if(_esc_cnt == 0 && rxBuffer.write(byte) != 1) {
        // logError("Serial Rx Byte Dropped [%c][0x%02X]", byte, byte);
    }

    _last_time = timer.read_ms();
}

void ATSerial::escapeChar(char esc) {
    _esc_ch = esc;
}

char ATSerial::escapeChar() {
    return _esc_ch;
}
