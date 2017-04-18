/*
 * =====================================================================================
 *
 *       Filename:  senet_packet.cpp
 *
 *    Description:  Senet Packet Types implementation file 
 *
 *        Version:  1.0
 *        Created:  03/05/2016 04:23:40 PM
 *
 *         Author:  S. Nelson  
 *        Company:  Senet, Inc
 *
 * =====================================================================================
 */
#include "senet_packet.h"
#include <stdio.h>

#define ASSERT(_expr) 


int32_t SenetPacket::
PacketHeader::serialize(uint8_t *frame, int32_t len)
{
    int32_t serializedLen = -1;

    if(len >= PacketHeader::HEADER_SIZE)
    {
        serializedLen = 0;
        frame[serializedLen++] = version;
        frame[serializedLen++] = type;

        ASSERT(serializedLen == PacketHeader::HEADER_SIZE);
    }

    return serializedLen;
}

int32_t SenetPacket::
PacketHeader::deserialize(uint8_t *frame, int32_t len)
{
    if((frame != NULL) && (len >= PacketHeader::HEADER_SIZE))
    {
        int32_t offset = 0;
        version = frame[offset++];
        type    = frame[offset++];

        ASSERT(offset == PacketHeader::HEADER_SIZE);

        return  PacketHeader::HEADER_SIZE;
    }
    return false;
}


SenetPacket::SenetPacket(uint8_t senetPktType, uint8_t *_buffer, uint8_t _buflen)
{
    header.type    = senetPktType;
    header.version = VERSION;
    pktLen         = 0;

    if(_buffer != NULL)
    {
        buffer     = _buffer;
        bufferLen  = _buflen;
        ownBuffer  = false;
    }
    else
    {
        if(_buflen != 0) 
            bufferLen = _buflen;
        else 
            bufferLen = MAX_FRAME_SIZE;

        buffer = new uint8_t[bufferLen];
        ASSERT(buffer != NULL);
        ownBuffer = true;
    }
    memset(buffer, 0, bufferLen);
}


SenetPacket::~SenetPacket()
{
    if(ownBuffer == true)
        delete buffer;
}


int32_t SenetPacket::serialize()
{
    pktLen = header.serialize(buffer, bufferLen);
    ASSERT(pktLen > 0);

    if(pktLen > 0)
    {
        int32_t payloadLen = serializePayload(buffer + pktLen, bufferLen - pktLen);

        ASSERT(payloadLen > 0);

        if(payloadLen > 0)
        {
            pktLen += payloadLen;
            return pktLen;
        }
    }

    return -1;
}

int32_t SenetPacket::deserialize(uint8_t *frame, int32_t len)
{
    int32_t bytes = 0;

    bytes = header.deserialize(frame, len);
    if(bytes > 0)
    {
        int32_t payloadLen = deserializePayload(frame, len - bytes);
        if(payloadLen > 0)
            bytes += payloadLen; 
        else
            bytes = payloadLen; 

    }
    return bytes;
}


bool SensorPacket::addSensorValue(uint8_t position, uint8_t type, uint16_t value)
{
    if (position < MAX_SENSOR_VALUES)
    {
        sensorValue[position].type  = type;
        sensorValue[position].value = value;
        sensorValue[position].isSet = true;
        return true;
    }
    else
        return false;
}

int32_t SensorPacket::serializePayload(uint8_t *buffer, int32_t len)
{
    int32_t bytes   = 0;
    int32_t dataLen = 0;

    for(int32_t i = 0; i < MAX_SENSOR_VALUES; i++)
    {
        if(sensorValue[i].isSet == true)
        {
            dataLen = sensorValue[i].serialize(buffer+bytes, len - bytes);
            if(dataLen == -1)
                return -1;
            bytes += dataLen;
        }
    }
    return bytes; 
}
int32_t SensorPacket::deserializePayload(uint8_t *frame, int32_t len) 
{
    int32_t num_sensors = 0;
    for(int i = 0;i < MAX_SENSOR_VALUES;i++)
    {
        if(len < 3)
            break;
        sensorValue[i].type = frame[i*3+0];
        sensorValue[i].value= (frame[i*3+1]<<8)|frame[i*3+2];
        sensorValue[i].isSet= true;
        len-=3;
        num_sensors++;
    }
    return(num_sensors);
}
bool SelfIdPacket::setDeviceType(uint32_t model, uint8_t revision)
{
    if((model & 0x00FFFFFF) != model)
        return false;

    deviceType = (model<<8)|revision;
    return true;
}

bool SelfIdPacket::setSwVersion(uint8_t major, uint8_t minor, uint8_t point, uint16_t build, uint8_t developerId)
{
 uint8_t  _major =  major & 0xf;
 uint8_t  _minor =  minor & 0xf;
 uint8_t  _point =  point & 0x3f;
 uint16_t _build =  build & 0x3ff;
 uint8_t  _devid =  developerId & 0xff;

 if((_major != major) || (_minor != minor) || (_point != point) || (_build != build) || (_devid != developerId))
     return false;

  swVersion = (_major << 28) | (_minor << 24) | (_point << 18) | (_build << 8) | _devid; 
  return true;
}

void SelfIdPacket::setBatteryFailState(bool failed)
{
    if(failed == true)
        powerMask |= 1 << 3;
    else
        powerMask &= ~(1 << 3); 
}

bool SelfIdPacket::setBatteryLevel(uint8_t level)
{
    uint8_t _level = level & 0x7;

    if(level != _level)
        return false;

    powerMask &= 0xf8;
    powerMask |= _level;

    return true;
}

bool SelfIdPacket::setExtPowerSupplyState(uint8_t id, bool isPresent)
{
    bool retVal = false;
    if(id == EXT_POWER_SUPPLY_1)      
    {
        powerMask &= 0x7F; 
        if(isPresent)
            powerMask |= 0x80;
        retVal = true;
    }
    else if(id == EXT_POWER_SUPPLY_2)      
    {
        powerMask &= 0xBF; 
        if(isPresent)
            powerMask |= 0x40;
        retVal = true;
    }
    return retVal;
}

int32_t SelfIdPacket::serializePayload(uint8_t *frame, int32_t len)
{
    int32_t out = -1;

    if(SELFID_PAYLOAD_LEN <= len)
    {
        frame[0] = (deviceType>>24) & 0xff;
        frame[1] = (deviceType>>16)  & 0xff;
        frame[2] = (deviceType>>8)  & 0xff;
        frame[3] = deviceType & 0xff;

        frame[4] = (swVersion >> 24) & 0xff;
        frame[5] = (swVersion >> 16) & 0xff;
        frame[6] = (swVersion >> 8)  & 0xff;
        frame[7] = swVersion & 0xff;

        frame[8] = powerMask;

        out = SELFID_PAYLOAD_LEN;
    }

    return out;
}

int32_t ConfigWordPacket::serializePayload(uint8_t *frame, int32_t len)
{
    int32_t out = -1;

    if(CONTROL_PAYLOAD_LENGTH <= len)
    {
        frame[0] = (config>>24) & 0xff;
        frame[1] = (config>>16) & 0xff;
        frame[2] = (config>>8) & 0xff;
        frame[3] = config & 0xff;

        frame[4] = (mask>>24) & 0xff;
        frame[5] = (mask>>16) & 0xff;
        frame[6] = (mask>>8) & 0xff;
        frame[7] = mask & 0xff;

        frame[8] = authKey;
        out = CONTROL_PAYLOAD_LENGTH;
    }

    return out;

}

int32_t ConfigWordPacket::deserializePayload(uint8_t *frame, int32_t len) 
{
    if(CONTROL_PAYLOAD_LENGTH <= len)
    {
        int32_t offset = 0;

        config  = frame[offset++]<<24; 
        config |= frame[offset++]<<16; 
        config |= frame[offset++]<<8; 
        config |= frame[offset++]; 

        mask  = frame[offset++]<<24; 
        mask |= frame[offset++]<<16; 
        mask |= frame[offset++]<<8; 
        mask |= frame[offset++]; 

        authKey = frame[offset++];

        return offset;
    }
    return -1;
}


int32_t BootInfoPacket::serializePayload(uint8_t *frame, int32_t len) 
{
    int32_t out = -1;

    if(BOOT_PAYLOAD_LENGTH <= len)
    {
        frame[0] = (bootCount>>8) & 0xff;
        frame[1] = bootCount & 0xff;

        frame[2] = (resetCount>>8) & 0xff;
        frame[3] = resetCount & 0xff;

        frame[4] = (lastBootReason>>24) & 0xff;
        frame[5] = (lastBootReason>>16)  & 0xff;
        frame[6] = (lastBootReason>>8)  & 0xff;
        frame[7] = lastBootReason  & 0xff;
        frame[8] = authKey;

        out = BOOT_PAYLOAD_LENGTH;
    }

    return out;
}


int32_t BootInfoPacket::deserializePayload(uint8_t *frame, int32_t len) 
{
    if(BOOT_PAYLOAD_LENGTH <= len)
    {
        int32_t offset = 0;

        bootCount  = frame[offset++]<<8; 
        bootCount |= frame[offset++]; 

        resetCount  = frame[offset++]<<8; 
        resetCount |= frame[offset++]; 

        lastBootReason  = frame[offset++] << 24;
        lastBootReason |= frame[offset++] << 16;
        lastBootReason |= frame[offset++] << 8;
        lastBootReason |= frame[offset++];

        authKey =  frame[offset++];

        return offset;
    }
    return -1;
}

bool GpsPacket::setCoordinates(int32_t _latitude, int32_t _longitude, uint16_t _elevation)
{
    latitude  = _latitude; 
    longitude = _longitude; 
    elevation = _elevation;
    
    return true;
}

int32_t GpsPacket::serializePayload(uint8_t *frame, int32_t len)
{
    int32_t out = -1;

    if(GPS_PAYLOAD_LENGTH <= len)
    {
        frame[0] = (latitude>>16) & 0xff;
        frame[1] = (latitude>>8) & 0xff;
        frame[2] = latitude & 0xff;

        frame[3] = (longitude>>16) & 0xff;
        frame[4] = (longitude>>8) & 0xff;
        frame[5] = longitude & 0xff;

        frame[6] = (elevation>>8) & 0xff;
        frame[7] = elevation & 0xff;

        frame[8] = txPower;

        out = GPS_PAYLOAD_LENGTH;
    }

    return  out;
}

int32_t RFDataPacket::serializePayload(uint8_t *frame, int32_t len)
{
    int32_t out = -1;

    if(RFDATA_PAYLOAD_LEN <= len)
    {
        frame[0] = channel;
        frame[1] = txpower;
        frame[2] = datarate;
        frame[3] = snr;
        frame[4] = (rssi >>8) & 0xff;
        frame[5] = rssi & 0xff;
        frame[6] = (timestamp >> 16) & 0xff;
        frame[7] = (timestamp >> 8)  & 0xff;
        frame[8] = timestamp & 0xff;
        out = RFDATA_PAYLOAD_LEN;
    }
    return out;
}


OctetStringPacket::OctetStringPacket(uint8_t size) : 
    SenetPacket(OCTET_STRING_PACKET, NULL, size + SenetPacket::PacketHeader::HEADER_SIZE)
{ 
    max   = size;
    oslen = 0;
}

bool OctetStringPacket::setOctetString(uint8_t *os, uint8_t len)
{
    if(len > max)
        return false;

    oslen = len;
    memcpy(buffer+PacketHeader::HEADER_SIZE, os, oslen);
    return true;
}

int32_t OctetStringPacket::serializePayload(uint8_t *frame, int32_t len)
{
    int32_t out = -1;

    if(oslen >= len)
    {
        memcpy(frame, buffer + PacketHeader::HEADER_SIZE, oslen);
        out = oslen;
    }

    return out;
}
    
