/*
 * =====================================================================================
 *
 *       Filename:  senet_packet.h
 *
 *    Description: Senet Packet types 
 *
 *        Version:  1.0
 *        Created:  03/05/2016 03:13:20 PM
 *       Revision:  1
 *
 *         Author:  Shaun Nelson, coder extraodinaire
 *        Company:  Senet, Inc  
 *
 * =====================================================================================
 */

#ifndef __SENET_PACKET__
#define __SENET_PACKET__

#include <stdint.h>
#include <string.h>


// Senet packet types
enum SenetPacketT
{
    SELF_ID_PACKET      = 0,
    RF_PACKET           = 1,
    GPS_PACKET          = 2,
    CONTROL_PACKET      = 3,
    BOOT_INFO_PACKET    = 4,
    SENSOR_PACKET       = 8,
    OCTET_STRING_PACKET = 126,
    UTF_8_STRING        = 127
};


/*
 * =====================================================================================
 *        Class:  SenetPacket
 *  Description:  Senet Packet Base class 
 * =====================================================================================
 */
struct SenetPacket
{
    static const uint32_t MAX_FRAME_SIZE = 242;
    static const uint8_t  VERSION        = 1;

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  SenetPacket
     *      Method:  serialize
     * Description:  Packet serializer 
     *--------------------------------------------------------------------------------------
     */
    int32_t serialize();

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  SenetPacket
     *      Method:  deserialize
     * Description:  Packet deserializer 
     *--------------------------------------------------------------------------------------
     */
    int32_t deserialize(uint8_t *frame, int32_t len);

    inline const uint8_t* payload() { return buffer;}
                 uint8_t  length () { return pktLen; }

    protected:
    // Common packet header
    struct PacketHeader
    {
        static const uint8_t HEADER_SIZE = 2;

        uint8_t version; // packet format versioni
        uint8_t type;    // Senet packet type

        PacketHeader(uint8_t _type=0)
        {
            version = VERSION;
            type    = _type;
        }

        int32_t serialize  (uint8_t *frame, int32_t len);
        int32_t deserialize(uint8_t *frame, int32_t len);
    } header;

    uint8_t  pktLen;   
    uint8_t *buffer;
    uint8_t  bufferLen;
    bool     ownBuffer;

    SenetPacket(uint8_t senetPktType, uint8_t *_buffer=NULL, uint8_t _buflen=0);
   ~SenetPacket();

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  SenetPacket
     *      Method:  serializePayload
     * Description:  Each unique packet type implements this to serialize its payload   
     *--------------------------------------------------------------------------------------
     */
    virtual int32_t serializePayload(uint8_t *frame, int32_t len) = 0; 

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  SenetPacket
     *      Method:  deserializePayload
     * Description:  Derived packet types can implement this to deserialize 
     *--------------------------------------------------------------------------------------
     */
    virtual int32_t deserializePayload(uint8_t *frame, int32_t len) {return 0;}

};


/*
 * =====================================================================================
 *        Class:  BootInfoPacket
 *  Description:  Device Boot information packet
 * =====================================================================================
 */
struct BootInfoPacket : public SenetPacket
{
    static const uint8_t BOOT_PAYLOAD_LENGTH = 9;

    uint16_t bootCount;       // number of device boots
    uint16_t resetCount;      // number of device resets
    uint32_t lastBootReason;  // last boot reason
    uint8_t  authKey;         

    BootInfoPacket(uint8_t *_buffer=NULL, uint8_t _buflen=0) :
        SenetPacket(BOOT_INFO_PACKET, _buffer, _buflen)
    {
        bootCount      = 0; 
        resetCount     = 0;
        lastBootReason = 0;
        authKey        = 0;
    }

    protected:
    /*
     *--------------------------------------------------------------------------------------
     *       Class:  BootInfoPacket
     *      Method:  serializePayload
     * Description:  Serialize packet data
     *--------------------------------------------------------------------------------------
     */
    virtual int32_t serializePayload(uint8_t *frame, int32_t len); 

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  BootInfoPacket 
     *      Method:  deserializePayload
     * Description:  Deserialize packet data
     *--------------------------------------------------------------------------------------
     */
    virtual int32_t deserializePayload(uint8_t *frame, int32_t len); 
};


/*
 * =====================================================================================
 *        Class:  ConfigWordPacket
 *  Description:  Packet to configure device
 * =====================================================================================
 */
struct ConfigWordPacket : public SenetPacket
{
    static const uint8_t CONTROL_PAYLOAD_LENGTH = 9;

    ConfigWordPacket(uint8_t *_buffer=NULL, uint8_t _buflen=0) :
        SenetPacket(CONTROL_PACKET, _buffer, _buflen) { config = 0; mask = 0; authKey = 0; }

    uint32_t config;  // configuration word
    uint32_t mask;    // valid bit mask applied to configuration word
    uint8_t  authKey; // Downlink authentication key 

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  ConfigWordPacket 
     *      Method:  serializePayload
     * Description:  Serialize packet data
     *--------------------------------------------------------------------------------------
     */
    virtual int32_t serializePayload(uint8_t *frame, int32_t len);

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  ConfigWordPacket 
     *      Method:  deserializePayload
     * Description:  Deserialize packet data
     *--------------------------------------------------------------------------------------
     */
    virtual int32_t deserializePayload(uint8_t *frame, int32_t len); 
};


/*
 * =====================================================================================
 *        Class:  GpsPacket
 *  Description:  Transmit device location in Decimal degress (http://www.en.wikipedia.org/wiki/Decimal_degrees)
 * =====================================================================================
 */
struct GpsPacket : public SenetPacket
{
    static const uint8_t GPS_PAYLOAD_LENGTH = 9;

           bool setCoordinates(int32_t latitude, int32_t longitude, uint16_t elevation);
    inline void setTxPower(uint8_t dBm) { txPower = dBm; }


    GpsPacket(uint8_t* _buffer=NULL, uint8_t _buflen=0):
        SenetPacket(GPS_PACKET, _buffer, _buflen)
    {
        latitude   = 0;
        longitude  = 0;
        elevation  = 0;
        txPower    = 0;
    }

    protected:
    uint32_t latitude;
    uint32_t longitude;
    uint16_t elevation;
    uint8_t  txPower;

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  GpsPacket
     *      Method:  serializePayload
     * Description:  Serialize the data 
     *--------------------------------------------------------------------------------------
     */
    virtual int32_t serializePayload(uint8_t *frame, int32_t len); 
};


/*
 * =====================================================================================
 *        Class:  OctetStringPacket
 *  Description:  Variable length Octet String packet 
 * =====================================================================================
 */
struct OctetStringPacket : public SenetPacket
{
    bool setOctetString(uint8_t *os, uint8_t len);

    OctetStringPacket(uint8_t size); 

    protected:
    uint8_t  oslen;
    uint8_t  max;

    virtual int32_t serializePayload(uint8_t *frame, int32_t len);
};

/*
 * =====================================================================================
 *        Class:  RFDataPacket
 *  Description: Radio Data packet 
 * =====================================================================================
 */
struct RFDataPacket : public SenetPacket
{
    static const uint8_t RFDATA_PAYLOAD_LEN = 9;

    uint8_t  channel;   //  The channel the device sent on
    uint8_t  txpower;   //  The transmit power in dBm used by the device
    uint8_t  datarate;  //  The datarate used by the device
    uint8_t  snr;       //  Signal to Noise ratio of the last frame received
    uint8_t  rssi;      //  RSSI of the last frame received
    uint32_t timestamp; //  The device's current timestamp

    RFDataPacket(uint8_t *_buffer=NULL, uint8_t _buflen=0):
        SenetPacket(RF_PACKET, _buffer, _buflen)
    { 
        channel   = 0;
        txpower   = 0;
        datarate  = 0;
        snr       = 0;
        rssi      = 0;
        timestamp = 0;
    }

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  RFDataPacket
     *      Method:  serializePayload
     * Description:  Serialize the data 
     *--------------------------------------------------------------------------------------
     */
    virtual int32_t serializePayload(uint8_t *frame, int32_t len);
};


/*
 * =====================================================================================
 *        Class:  SelfIdPacket
 *  Description:  
 * =====================================================================================
 */
struct SelfIdPacket : public SenetPacket
{
    const static uint8_t EXT_POWER_SUPPLY_ID_MAX = 2;
    const static uint8_t EXT_POWER_SUPPLY_1      = 1;
    const static uint8_t EXT_POWER_SUPPLY_2      = 2;
    const static uint8_t BATTERY_LEVEL_MAX       = 7;
    const static uint8_t SELFID_PAYLOAD_LEN      = 9;

    bool setDeviceType          (uint32_t model, uint8_t revision);
    bool setSwVersion           (uint8_t major, uint8_t minor, uint8_t point, uint16_t build, uint8_t developer);
    void setBatteryFailState    (bool failed);
    bool setBatteryLevel        (uint8_t level);
    bool setExtPowerSupplyState (uint8_t id, bool isPresent);

    SelfIdPacket(uint8_t *_buffer=NULL, uint8_t _buflen=0) :
        SenetPacket(SELF_ID_PACKET, _buffer, _buflen) { deviceType = 0; swVersion = 0; powerMask = 0; }

    protected:
    uint32_t deviceType;
    uint32_t swVersion;
    uint8_t  powerMask;

    /*
     *--------------------------------------------------------------------------------------
     *       Class:  SelfIdPacket 
     *      Method:  serializePayload
     * Description:  Serialize the data 
     *--------------------------------------------------------------------------------------
     */
    virtual int32_t serializePayload(uint8_t *frame, int32_t len); 
};


/*
 * =====================================================================================
 *        Class:  SensorPacket
 *  Description:  
 * =====================================================================================
 */
struct SensorPacket : public SenetPacket
{
    bool setPrimarySensor(uint16_t value) { return addSensorValue(0,1, value);}
    bool setTemperature  (uint16_t value) { return addSensorValue(1,2, value);}
    bool setPressure     (uint16_t value) { return addSensorValue(2,3, value);}
    void reset();

    SensorPacket(uint8_t *_buffer=NULL, uint8_t _buflen=0) :
        SenetPacket(SENSOR_PACKET, _buffer, _buflen) {}

    public:
    static const uint8_t MAX_SENSOR_VALUES = 3;

    struct SensorValue
    {
        uint8_t  type;
        uint16_t value;
        bool     isSet;

        SensorValue() { type  = 0; value = 0; isSet = false;}

        int32_t serialize(uint8_t *frame, int32_t len)
        {
            if(len < 3)
                return -1;

            frame[0] = type;
            frame[1] = (value >> 8) & 0xff;
            frame[2] = value & 0xff;
            return 3;
        }
    } sensorValue[MAX_SENSOR_VALUES];

    bool    addSensorValue(uint8_t position, uint8_t type, uint16_t value);

    virtual int32_t serializePayload(uint8_t *frame, int32_t len);
    virtual int32_t deserializePayload(uint8_t *frame, int32_t len);

};

#endif // __SENET_PACKET__ 

