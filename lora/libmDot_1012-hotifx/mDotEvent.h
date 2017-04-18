#include "LoRaMacEvent.h"
#include "MTSLog.h"

#ifndef __MDOT_EVENT_H__
#define __MDOT_EVENT_H__

class mDotEvent : public LoRaMacEvent {
    public:

        virtual ~mDotEvent() {}

        /*!
         * MAC layer event callback prototype.
         *
         * \param [IN] flags Bit field indicating the MAC events occurred
         * \param [IN] info  Details about MAC events occurred
         */
        virtual void MacEvent(LoRaMacEventFlags *flags, LoRaMacEventInfo *info) {
            logDebug("mDotEvent");

            if (flags->Bits.Rx) {
                logDebug("Rx");

                // Event Object must delete RxBuffer
                delete[] info->RxBuffer;
            }
        }

        virtual uint8_t MeasureBattery(void) {
            return 255;
        }
};


#endif // __MDOT_EVENT_H__

