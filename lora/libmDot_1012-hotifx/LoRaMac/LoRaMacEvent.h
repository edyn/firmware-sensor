/*
 / _____)             _              | |
 ( (____  _____ ____ _| |_ _____  ____| |__
 \____ \| ___ |    (_   _) ___ |/ ___)  _ \
 _____) ) ____| | | || |_| ____( (___| | | |
 (______/|_____)_|_|_| \__)_____)\____)_| |_|
 (C)2013 Semtech

 Description: Generic radio driver definition

 License: Revised BSD License, see LICENSE.TXT file include in the project

 Maintainer: Miguel Luis and Gregory Cristian
 */
#ifndef __LORAMACEVENT_H__
#define __LORAMACEVENT_H__

/*!
 * LoRaMAC event flags
 */
typedef union {
        uint8_t Value;
        struct {
                uint8_t :1;
                uint8_t Tx :1;
                uint8_t Rx :1;
                uint8_t RxData :1;
                uint8_t RxSlot :2;
                uint8_t LinkCheck :1;
                uint8_t JoinAccept :1;
        } Bits;
} LoRaMacEventFlags;

typedef enum {
    LORAMAC_EVENT_INFO_STATUS_OK = 0,
    LORAMAC_EVENT_INFO_STATUS_ERROR,
    LORAMAC_EVENT_INFO_STATUS_TX_TIMEOUT,
    LORAMAC_EVENT_INFO_STATUS_RX_TIMEOUT,
    LORAMAC_EVENT_INFO_STATUS_RX_ERROR,
    LORAMAC_EVENT_INFO_STATUS_JOIN_FAIL,
    LORAMAC_EVENT_INFO_STATUS_DOWNLINK_FAIL,
    LORAMAC_EVENT_INFO_STATUS_ADDRESS_FAIL,
    LORAMAC_EVENT_INFO_STATUS_MIC_FAIL,
} LoRaMacEventInfoStatus;

/*!
 * LoRaMAC event information
 */
typedef struct {
        LoRaMacEventInfoStatus Status;
        bool TxAckReceived;
        uint8_t TxNbRetries;
        uint8_t TxDatarate;
        uint8_t RxPort;
        uint8_t *RxBuffer;
        uint8_t RxBufferSize;
        int16_t RxRssi;
        uint8_t RxSnr;
        uint16_t Energy;
        uint8_t DemodMargin;
        uint8_t NbGateways;
} LoRaMacEventInfo;

/*!
 * LoRaMAC events structure
 * Used to notify upper layers of MAC events
 */
class LoRaMacEvent {
    public:

        virtual ~LoRaMacEvent() {}

        /*!
         * MAC layer event callback prototype.
         *
         * \param [IN] flags Bit field indicating the MAC events occurred
         * \param [IN] info  Details about MAC events occurred
         */
        virtual void MacEvent(LoRaMacEventFlags *flags, LoRaMacEventInfo *info) {

            if (flags->Bits.Rx) {
                delete[] info->RxBuffer;
            }
        }

        virtual uint8_t MeasureBattery(void) {
            return 255;
        }
};

#endif // __LORAMACEVENT_H__

