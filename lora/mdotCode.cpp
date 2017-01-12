/**
 * @file    main.cpp
 * @brief   Main application for mDot-EVB demo
 * @author  Tim Barr  MultiTech Systems Inc.
 * @version 1.03
 * @see
 *
 * Copyright (c) 2015
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * 1.01 TAB 7/6/15 Removed NULL pointer from evbAmbientLight creation call.
 *
 * 1.02 TAB 7/8/15 Send logo to LCD before attempting connection to LoRa network. Added
 *                  information on setting up for public LoRa network. Moved SW setup to
 *                  beginning of main. Removed printf call from ISR functions. Added
 *                  additional checks for exit_program.
 *
 * 1.03 TAB 7/15/15 Added threads for push button switch debounce.
 *
 */

#include "mbed.h"
#include "senet_packet.h"

#if !defined(MTDOT_EVB) && !defined(MTDOT_UDK)
#define MTDOT_UDK
#define REFLECT_FAST_TX
#endif

// EVB Sensors
#ifdef MTDOT_EVB

#include "MMA845x.h"
#include "MPL3115A2.h"
#include "ISL29011.h"
#include "NCP5623B.h"
#include "DOGS102.h"
#include "font_6x8.h"
#include "MultiTech_Logo.h"

// Added period delay 
#define PERIOD_DELAY 0

// Fast send period 
#define FAST_SEND_PERIOD pckt_time

// Send frame period 
#define SEND_PERIOD 100 

#elif defined(MTDOT_UDK)

#include "x_nucleo_iks01a1.h"

// Added period delay  
#define PERIOD_DELAY 3000 

// Fast send period 
#define FAST_SEND_PERIOD 1  

// Send frame period 
#define SEND_PERIOD 10  

#endif

#include "mDot.h"
#include "rtos.h"
#include <string>
#include <vector>

/* 
 * Board sensor data
 */
struct BoardSensorData
{
    float temperature;
    float pressure;
    int32_t accel_x;
    int32_t accel_y;
    int32_t accel_z;

    inline void init()
    {
        temperature= 0;
        pressure = 0;
        accel_x = 0;
        accel_y = 0;
        accel_z = 0;
    }

    BoardSensorData() { init(); }
};

#ifdef MTDOT_EVB

//DigitalIn mDot02(PA_2);  //  GPIO/UART_TX
//DigitalOut mDot03(PA_3); //  GPIO/UART_RX
//DigitalIn mDot04(PA_6);  //  GPIO/SPI_MISO
//DigitalIn mDot06(PA_8);  //  GPIO/I2C_SCL
//DigitalIn mDot07(PC_9);  //  GPIO/I2C_SDA

InterruptIn mDot08(PA_12);  //  GPIO/USB       PB S1 on EVB
InterruptIn mDot09(PA_11);  //  GPIO/USB       PB S2 on EVB

//DigitalIn mDot11(PA_7);   //  GPIO/SPI_MOSI

InterruptIn mDot12(PA_0);    //  GPIO/UART_CTS  PRESSURE_INT2 on EVB
DigitalOut  mDot13(PC_13,1); //  GPIO           LCD_C/D
InterruptIn mDot15(PC_1);    //  GPIO           LIGHT_PROX_INT on EVB
InterruptIn mDot16(PA_1);    //  GPIO/UART_RTS  ACCEL_INT2 on EVB
DigitalOut mDot17(PA_4,1);   //  GPIO/SPI_NCS   LCD_CS on EVB

//DigitalIn mDot18(PA_5);    //  GPIO/SPI_SCK

//DigitalInOut mDot19(PB_0,PIN_INPUT,PullNone,0); // GPIO         PushPull LED Low=Red High=Green set MODE=INPUT to turn off
AnalogIn mDot20(PB_1);         //  GPIO          Current Sense Analog in on EVB
Serial debugUART(PA_9, PA_10); // mDot debug UART
//Serial mDotUART(PA_2, PA_3); // mDot external UART mDot02 and mDot03
I2C mDoti2c(PC_9,PA_8); // mDot External I2C mDot6 and mDot7

SPI mDotspi(PA_7,PA_6,PA_5); // mDot external SPI mDot11, mDot4, and mDot18
#elif defined(MTDOT_UDK)

Serial debugUART(USBTX, USBRX); // mDot debug UART

#endif

/* 
 * LoRaWAN Configuration 
 */
 
 // Senet Developer Portal Application EUI
static uint8_t app_id[8]   = {0x00,0x80,0x00,0x00,0x00,0x01,0xAE,0xD1};

// Get Application Key from Senet Developer Portal Device Edit page
static uint8_t app_key[16] = {0xED,0xEE,0x52,0xA3,0xC1,0xF8,0x6A,0xEB,0xA4,0x24,0x24,0x3F,0x28,0x34,0x52,0xA3};

static std::vector<uint8_t> config_app_id(app_id,app_id+sizeof(app_id)/sizeof(uint8_t));
static std::vector<uint8_t> config_app_key(app_key,app_key+sizeof(app_key)/sizeof(uint8_t));
static uint8_t config_frequency_sub_band = 1;
static bool    config_adr_on = true;
#define DATARATE mDot::DR2

bool     position_changed = true;
uint32_t sample_period    = 0;

#ifdef  MTDOT_EVB
MMA845x_DATA accel_data;
MPL3115A2_DATA baro_data;
uint16_t  lux_data;
MMA845x* evbAccel;     
MPL3115A2* evbBaro;
ISL29011* evbAmbLight;
NCP5623B* evbBackLight;
DOGS102* evbLCD;

/* 
 * EVB Application state 
 */
uint8_t position_value   = 0xFF; // 00 unknown, 01 is flat, 02 is vertical
uint8_t reflected_value  = 0xFE;

unsigned char test;
char     txtstr[17];
int32_t  num_whole;
uint32_t pressure;
int16_t  num_frac;
uint8_t  result, pckt_time=100;
char     data;
// flags for pushbutton debounce code
bool pb1_low = false;
bool pb2_low = false;

void pb1ISR(void);
void pb2ISR(void);
void pb1_debounce(void const *args);
void pb2_debounce(void const *args);
Thread* thread_3;

void config_pkt_xmit (void const *args);

#elif defined(MTDOT_UDK)

uint16_t position_value  = 0;
uint16_t reflected_value = 0;

static X_NUCLEO_IKS01A1 *mems_shield; 

#endif 

mDot* mdot_radio;
bool  exit_program = false;
Ticker joinTicker;
DigitalOut APP_LED(PA_0);

// join status
#define JOIN_LED APP_LED

// server sync status 
#define SYNC_LED APP_LED

#define SYNC_LED_OK  0 // synced
#define SYNC_LED_OOS 1 // out of sync


/* 
 * Process downlink
 */
static void ReceiveData(std::vector<uint8_t> frame);

static bool checkForExit(bool exit);

/*
 *  prints of mDot error 
 */
void log_error(mDot* dot, const char* msg, int32_t retval)
{
    printf("%s - %ld:%s, %s\r\n", msg, retval, mDot::getReturnCodeString(retval).c_str(), dot->getLastError().c_str());
}

/*
 * Send frame
 */
void SendFrame(std::vector<uint8_t> frame)
{
    int32_t mdot_ret;

    if ((mdot_ret = mdot_radio->send(frame)) != mDot::MDOT_OK) {
        log_error(mdot_radio, "failed to send", mdot_ret);
    } 
    else {
        printf("successfully sent data\r\n");
        frame.clear();
        if ((mdot_ret = mdot_radio->recv(frame)) == mDot::MDOT_OK) {
            printf("recv data: ");
            for(uint32_t i = 0;i < frame.size();i++)
                printf("%02X",frame[i]);
            printf("\r\n");

            ReceiveData(frame);
        }
        position_changed = false;
    }
}

#ifdef MTDOT_EVB

void ReceiveData(std::vector<uint8_t> frame)
{
    reflected_value = frame[0];

    if(reflected_value == position_value)
    {
        evbBackLight->setLEDCurrent(16);
        // Set LED to indicate server in agreement 
        SYNC_LED=SYNC_LED_OK;
    }
    else 
    {
        evbBackLight->setLEDCurrent(0);
    }
}

void BoardInit()
{
    static Thread thread_1(pb1_debounce);    // threads for de-bouncing pushbutton switches
    static Thread thread_2(pb2_debounce);

    debugUART.baud(115200);
    // mDotUART.baud(9600);    // mdot UART unused but available on external connector

    thread_3 = new Thread(config_pkt_xmit); // start thread that sends LoRa packet when SW2 pressed

    evbAccel = new MMA845x(mDoti2c,MMA845x::SA0_VSS); // setup Accelerometer
    evbBaro = new MPL3115A2(mDoti2c); // setup Barometric sensor
    evbAmbLight = new ISL29011(mDoti2c); // Setup Ambient Light Sensor
    evbBackLight = new NCP5623B(mDoti2c); // setup backlight and LED 2 driver chip
    evbLCD = new DOGS102(mDotspi, mDot17, mDot13); // setup LCD

    /*
     *  Setup SW1 as program stop function
     */
    mDot08.disable_irq();
    mDot08.fall(&pb1ISR);

    /*
     *  need to call this function after rise or fall because rise/fall sets
     *  mode to PullNone
     */
    mDot08.mode(PullUp);

    mDot08.enable_irq();

    /*
     *  Setup SW2 as packet time change
     */
    mDot09.disable_irq();
    mDot09.fall(&pb2ISR);

    /*
     *  need to call this function after rise or fall because rise/fall sets
     *  mode to PullNone
     */
    mDot09.mode(PullUp);
 
    mDot09.enable_irq();

    /*
    * Setting other InterruptIn pins with Pull Ups
    */
    mDot12.mode(PullUp);
    mDot15.mode(PullUp);
    mDot16.mode(PullUp);

    printf("font table address %p\n\r",&font_6x8);
    printf("bitmap address %p\n\r",&MultiTech_Logo);

// Setup and display logo on LCD
    evbLCD->startUpdate();

    evbLCD->writeBitmap(0,0,MultiTech_Logo);

    sprintf(txtstr,"MTDOT");
    evbLCD->writeText(24,3,font_6x8,txtstr,strlen(txtstr));
    sprintf(txtstr,"Evaluation");
    evbLCD->writeText(24,4,font_6x8,txtstr,strlen(txtstr));
    sprintf(txtstr,"Board");
    evbLCD->writeText(24,5,font_6x8,txtstr,strlen(txtstr));

    evbLCD->endUpdate();

    pckt_time = 10;
}

void PostJoinInit()
{
    osDelay(200);
    evbBackLight->setPWM(NCP5623B::LED_3,16); // enable LED2 on EVB and set to 50% PWM

    // sets LED2 to 50% max current
    evbBackLight->setLEDCurrent(16);

    printf("Start of Test\n\r");

    osDelay (500); // allows other threads to process
    printf("shutdown LED:\n\r");
    evbBackLight->shutdown();

    osDelay (500); // allows other threads to process
    printf("Turn on LED2\n\r");
    evbBackLight->setLEDCurrent(16);

    data = evbAccel->getWhoAmI();
    printf("Accelerometer who_am_i value = %x \n\r", data);

    result = evbAccel->getStatus();
    printf("status byte = %x \n\r", result);

    printf("Barometer who_am_i check = %s \n\r", evbBaro->testWhoAmI() ? "TRUE" : "FALSE");

    result = evbBaro->getStatus();
    printf("status byte = %x \n\r", result);

    /*
     *  Setup the Accelerometer for 8g range, 14 bit resolution, Noise reduction off, sample rate 1.56 Hz
     *  normal oversample mode, High pass filter off
     */
    evbAccel->setCommonParameters(MMA845x::RANGE_8g,MMA845x::RES_MAX,MMA845x::LN_OFF,
                                  MMA845x::DR_1_56,MMA845x::OS_NORMAL,MMA845x::HPF_OFF );

    /*
     * Setup the Barometric sensor for post processed Ambient pressure, 4 samples per data acquisition.
     * and a sample taken every second when in active mode
     */
    evbBaro->setParameters(MPL3115A2::DATA_NORMAL, MPL3115A2::DM_BAROMETER, MPL3115A2::OR_16,
                           MPL3115A2::AT_1);
    /*
     * Setup the Ambient Light Sensor for continuous Ambient Light Sensing, 16 bit resolution,
     * and 16000 lux range
     */

    evbAmbLight->setMode(ISL29011::ALS_CONT);
    evbAmbLight->setResolution(ISL29011::ADC_16BIT);
    evbAmbLight->setRange(ISL29011::RNG_16000);

    /*
     * Set the accelerometer for active mode
     */
    evbAccel->activeMode();

    /*
     * Clear the min-max registers in the Barometric Sensor
     */
    evbBaro->clearMinMaxRegs();

    evbBackLight->setLEDCurrent(0);

    /*
     * Check for PB1 press during network join attempt
     */
    if (exit_program) {
        printf("Exiting program\n\r");
        evbLCD->clearBuffer();
        sprintf(txtstr,"Exiting Program");
        evbLCD->writeText(0,4,font_6x8,txtstr,strlen(txtstr));
        exit(1);
    }
}

void ReadSensors(BoardSensorData &sensorData)
{
    MMA845x_DATA accel_data;
    /*
     * Test Accelerometer XYZ data ready bit to see if acquisition complete
     */
    do {
        osDelay(100); // allows other threads to process
        result = evbAccel->getStatus();
    } while ((result & MMA845x::XYZDR) == 0 );

    /*
     * Retrieve and print out accelerometer data
     */
    accel_data = evbAccel->getXYZ();

    sprintf(txtstr,"Accelerometer");
    evbLCD->writeText(0,0,font_6x8,txtstr,strlen(txtstr));
    sprintf(txtstr, "x = %d", accel_data._x);
    evbLCD->writeText(20,1,font_6x8,txtstr,strlen(txtstr));
    sprintf(txtstr, "y = %d", accel_data._y);
    evbLCD->writeText(20,2,font_6x8,txtstr,strlen(txtstr));
    sprintf(txtstr, "z = %d", accel_data._z );
    evbLCD->writeText(20,3,font_6x8,txtstr,strlen(txtstr));

    sensorData.accel_x = accel_data._x;
    sensorData.accel_y = accel_data._y;
    sensorData.accel_z = accel_data._z;

    // Update accelerometer state
    evbLCD->startUpdate();
    evbLCD->clearBuffer();
    
    // convert to simple position value for use in send/recv
    if((accel_data._x > 500)&&(accel_data._z < 500))
    {
        if(position_value != 0x02)
            position_changed = true;
        position_value = 0x02;
    }
    else if((accel_data._x < 500)&&(accel_data._z > 500))
    {
        if(position_value != 0x01)
            position_changed = true;
        position_value = 0x01;
    }
    else
    {
        if(position_value != 0x00)
            position_changed = true;
        position_value= 0x00;
    }

    if(position_changed){
        evbBackLight->setLEDCurrent(0);
        // Turn LED off to indicate server not in agreement 
        SYNC_LED=SYNC_LED_OOS;
        // Set reflected_value to an out of range value to stay
        // in fast transmit mode until server responds
        reflected_value = 0;
    }

    /*
     * Trigger a Pressure reading
     */
    evbBaro->setParameters(MPL3115A2::DATA_NORMAL, MPL3115A2::DM_BAROMETER, MPL3115A2::OR_16,
                           MPL3115A2::AT_1);
    evbBaro->triggerOneShot();

    /*
     * Test barometer device status to see if acquisition is complete
     */
    do {
        osDelay(100);           // allows other threads to process
        result = evbBaro->getStatus();
    } while ((result & MPL3115A2::PTDR) == 0 );

    /*
     * Retrieve and print out barometric pressure
     */
    pressure = evbBaro->getBaroData() >> 12; // convert 32 bit signed to 20 bit unsigned value
    num_whole = pressure >> 2;          // 18 bit integer significant
    num_frac = (pressure & 0x3) * 25;       // 2 bit fractional  0.25 per bit
    sensorData.pressure = pressure + (.25 * num_frac);

    sprintf(txtstr,"Press=%ld.%02d Pa", num_whole, num_frac);
    evbLCD->writeText(0,4,font_6x8,txtstr,strlen(txtstr));

    /*
     * Trigger a Altitude reading
     */
    evbBaro->setParameters(MPL3115A2::DATA_NORMAL, MPL3115A2::DM_ALTIMETER, MPL3115A2::OR_16,
                           MPL3115A2::AT_1);
    evbBaro->triggerOneShot();

    /*
     * Test barometer device status to see if acquisition is complete
     */
    do {
        osDelay(100);           // allows other threads to process
        result = evbBaro->getStatus();
    } while ((result & MPL3115A2::PTDR) == 0 );

    /*
     * Retrieve and print out altitude and temperature
     */
    baro_data = evbBaro->getAllData(false);
    baro_data._baro /= 4096;                // convert 32 bit signed to 20 bit signed value
    num_whole = baro_data._baro / 16;       //  18 bit signed significant integer
    num_frac = (baro_data._baro & 0xF) * 625 / 100;     // 4 bit fractional .0625 per bit
    sprintf(txtstr,"Alti=%ld.%03d m", num_whole, num_frac);
    evbLCD->writeText(0,5,font_6x8,txtstr,strlen(txtstr));
    num_whole = baro_data._temp / 16;       // 8 bit signed significant integer
    num_frac = (baro_data._temp & 0x0F) * 625 / 100;        // 4 bit fractional .0625 per bit
    sensorData.temperature = num_whole  + ((float)num_frac / 100);
    sprintf(txtstr,"Temp=%ld.%03d C", num_whole, num_frac);
    evbLCD->writeText(0,6,font_6x8,txtstr,strlen(txtstr));

    /*
     * retrieve and print out Ambient Light level
     */
    lux_data = evbAmbLight->getData();
    num_whole = lux_data * 24 / 100;        // 16000 lux full scale .24 lux per bit
    num_frac = lux_data * 24 % 100;
    sprintf(txtstr, "Light=%ld.%02d lux", num_whole, num_frac );
    evbLCD->writeText(0,7,font_6x8,txtstr,strlen(txtstr));

    evbLCD->endUpdate();
}

uint32_t PrepareFrame(std::vector<uint8_t> &frame, BoardSensorData &data)
{
    frame.clear();

#ifdef REFLECT_FAST_TX
    if((reflected_value != position_value)|| position_changed || ( ( sample_period % SEND_PERIOD ) == 0 ) )
#else
    if( position_changed || ( ( sample_period % SEND_PERIOD ) == 0 ) )
#endif
    {
        // we will send a simple byte descriptor of the current position of the device: 01 is laying flat, 02 is vertically oriented
        frame.push_back(0x00);
        frame.push_back(position_value);
    }

    return frame.size();
}

bool checkForExit(bool _exit)
{
    // Check for PB1 press during network join attempt
    if (exit_program) {
      printf("Exiting program\n\r"); 
      evbLCD->clearBuffer();
      sprintf(txtstr,"Exiting Program");
      evbLCD->writeText(0,4,font_6x8,txtstr,strlen(txtstr));
      if(_exit)
          exit(1);
    } 

    return false;
}

void ExitingProgram()
{
    evbBaro->triggerOneShot();
    do {
        osDelay(200);           // allows other threads to process
        result = evbBaro->getStatus();
    } while ((result & MPL3115A2::PTDR) == 0 );

    baro_data = evbBaro->getAllData(true);
    printf ("minBaro=%ld maxBaro=%ld minTemp=%d maxTemp=%d\n\r", baro_data._minbaro, baro_data._maxbaro,
            baro_data._mintemp, baro_data._maxtemp);
    evbLCD->clearBuffer();
    sprintf(txtstr,"Exiting Program");
    evbLCD->writeText(0,4,font_6x8,txtstr,strlen(txtstr));
    printf("End of Test\n\r");
}


/*
 * Sets pb1_low flag. Slag is cleared in pb1_debounce thread
 */
void pb1ISR(void)
{
    if (!pb1_low)
        pb1_low = true;
}

/*
 * Debounces pb1. Also exits program if pushbutton 1 is pressed
 */
void pb1_debounce(void const *args)
{ 
    static uint8_t count = 0;

    while (true) { 
        if (pb1_low && (mDot08 == 0))
            count++;
        else {
            count = 0;
            pb1_low = false;
        } 

        if (count == 5) 
            exit_program = true; 

        Thread::wait(5);
    }
}

/*
 * Sets pb2_low flag. Flag is cleared in pb2_debounce thread
 */
void pb2ISR(void)
{
    if (!pb2_low)
        pb2_low = true;
}

/*
 * Debounces pb2. Also changes packet transmit time to every other,
 * every fifth, or every tenth sample when SW2 pushed
 * Also triggers a thread to transmit a configuration packet
 */
void pb2_debounce(void const *args)
{
    static uint8_t count = 0;

    while (true) {

        if (pb2_low && (mDot09 == 0))
            count++;
        else {
            count = 0;
            pb2_low = false;
        }
        
        if (count == 5){ 
            if (pckt_time >= 5)
                pckt_time /= 2;
            else 
                pckt_time = 20; 
            
            //thread_3->signal_set(0x10);       // signal config_pkt_xmit to send packet
            position_changed = true;
        } 
        Thread::wait(5);
    }
 }

/*
 * Thread that is triggered by SW2 ISR. Sends a packet to the LoRa server with the new Packet Transmission time setting
 */
void config_pkt_xmit (void const *args)
{
    int32_t mdot_ret;

    std::vector<uint8_t> data;

    while (true) {
        Thread::signal_wait(0x10);      // wait for pb2ISR to signal send
        data.clear();
        data.push_back(0x0F);           // key for Configuration data (packet transmission timer)
        data.push_back(pckt_time);

        if ((mdot_ret = mdot_radio->send(data)) != mDot::MDOT_OK) {
            log_error(mdot_radio, "failed to send config data", mdot_ret);
        } else {
            printf("sent config data to gateway\r\n");
        }
    }
}

#elif defined(MTDOT_UDK)

void ReceiveData(std::vector<uint8_t> frame)
{
    uint16_t value;

    if(frame.size() >= 2)
    {
        value = frame[0] << 8 | frame[1];
        if(value == position_value)
        {
            reflected_value = value;
            // Turn LED on to indicate server in agreement 
            SYNC_LED=SYNC_LED_OK;
        }
    }
}

void BoardInit()
{ 
    debugUART.baud(9600); 

    // ST X-NUCLEO-IKS01A1 MEMS Shield
    mems_shield = X_NUCLEO_IKS01A1::Instance(NULL, NC); 
    // mems_shield = X_NUCLEO_IKS01A1::Instance(); 
}

void PostJoinInit() { }


void ReadSensors(BoardSensorData &data)
{
    uint32_t ret = 0;
    int32_t  accel_data[3];
    
   // Temperature
   ret |= (!CALL_METH(mems_shield->pt_sensor, GetTemperature, &data.temperature, 0.0f) ? 0x0 : 0x1);

   // Pressure
   ret |= (!CALL_METH(mems_shield->pt_sensor, GetPressure, &data.pressure, 0.0f) ? 0x0 : 0x1);

   // Accelerometer
   MotionSensor *motionSensor = mems_shield->GetAccelerometer();
   if( motionSensor != NULL)
   {
       motionSensor->Get_X_Axes(accel_data);

       data.accel_x = accel_data[0];
       data.accel_y = accel_data[1];
       data.accel_z = accel_data[2];
       /*  z-axis : > 0 = rightside up, < 0 upside down
        *  x-axis: com LED to the left x < 0, x > 0 on the right
        *  y-axis: y > 0 COM LED down, y < 0  COM LED up 
        */
       bool up         = false;
       bool down       = false;
       bool right      = false;
       bool left       = false;
       bool horizontal = false;
       bool upsidedown = false;
       uint16_t next_value = 0; 
       
       // rightside up
       if(data.accel_z >= 750)
       {
           horizontal  = true;
       }
       // upside down
       else if(data.accel_z <= -750)
       {
           horizontal  = true;
           upsidedown  = true;
           position_value = (2 << 12) | (1 << 8);
       }
       // vertical down
       else if(data.accel_y >= 900 )
       {
           down = true;
       }
       // vertical up
       else if(data.accel_y <= -900 )
       {
           up = true;
       }
       // side right
       else if(data.accel_x > 900)
       {
           right = true;
       }
       // side left
       else
       {
           left = true;
       }

       if(horizontal)
       {
           next_value = (2 << 12) | (upsidedown << 8); 
       }
       else
       {
           next_value = (up << 12) | (left << 8) | (down << 4) | right;
       }

       if(next_value != position_value)
       {
           position_value = next_value;
           position_changed = true;
           
           // Set reflected_value to an out of range value to stay
           // in fast transmit mode until server responds
           reflected_value = 0;

            // Turn LED off to indicate server is not in agreement 
            SYNC_LED=SYNC_LED_OOS;
       }
   }

   printf("%s: position_value=%04x, reflected_value=%04x\r\n",__func__, position_value, reflected_value);
}

uint32_t PrepareFrame(std::vector<uint8_t> &frame, BoardSensorData &data)
{
    static uint8_t buffer[64];

    frame.clear();

    // Sensor packet type serialized to the LMIC frame buffer
    SensorPacket packet(buffer, sizeof(buffer));

#ifdef REFLECT_FAST_TX
    if( position_changed  || (reflected_value != position_value) || ( ( sample_period % SEND_PERIOD ) == 0 ) )
#else
    if( position_changed  || ( ( sample_period % SEND_PERIOD ) == 0 ) )
#endif
    {
        packet.setPrimarySensor(position_value);
        packet.setTemperature(data.temperature);
        packet.setPressure(data.pressure);
                
        // Serialize  packet 
        packet.serialize();

        frame.assign(packet.payload(), packet.payload() + packet.length());
    }

    return frame.size();
}

bool checkForExit(bool _exit) { return false;}


void ExitingProgram()
{
    printf("Exiting\n\r");
}

#else
#error Board type not defined!
#endif

void joinLedToggle()
{
    JOIN_LED = !JOIN_LED;
}

void mDotConfigureAndJoin()
{ 
    bool    ok;
    int32_t mdot_ret;

    printf("Configuring mDot\r\n");
    
    // get mDot handle
    mdot_radio = mDot::getInstance();
    if(mdot_radio == NULL)
    { 
        while(1) {
            printf("radio setup failed\n\r");
            osDelay(1000);
        }
    }

    do{
        ok = true; 

        printf("\n\r setup mdot\n\r"); 
        
        // reset to default config so we know what state we're in
        mdot_radio->resetConfig();
        //mdot_radio->setLogLevel(6);

        mdot_radio->setAntennaGain(-3);

        // Setting up LED1 as activity LED
#ifdef MTDOT_EVB
        mdot_radio->setActivityLedPin(PB_0);
        mdot_radio->setActivityLedEnable(true);
#endif

        // Read node ID
        std::vector<uint8_t> mdot_EUI;
        mdot_EUI = mdot_radio->getDeviceId();
        printf("mDot EUI = ");

        for (uint8_t i=0; i<mdot_EUI.size(); i++) {
            printf("%02x ", mdot_EUI[i]);
        }
        printf("\n\r"); 
        

      /*
       * This call sets up private or public mode on the MTDOT. Set the function to true if
       * connecting to a public network
       */
       printf("setting Public Network Mode\r\n");
       if ((mdot_ret = mdot_radio->setPublicNetwork(true)) != mDot::MDOT_OK) {
           log_error(mdot_radio, "failed to set Public Network Mode", mdot_ret);
       }
       mdot_radio->setTxDataRate(DATARATE);
       mdot_radio->setTxPower(14);
       mdot_radio->setJoinRetries(1);
       mdot_radio->setJoinMode(mDot::OTA); 

      /*
       * Frequency sub-band is valid for NAM only and for Private networks should be set to a value
       * between 1-8 that matches the the LoRa gateway setting. Public networks use sub-band 0 only.
       * This function can be commented out for EU networks
       */
       printf("setting frequency sub band\r\n");
       if ((mdot_ret = mdot_radio->setFrequencySubBand(config_frequency_sub_band)) != mDot::MDOT_OK) {
            log_error(mdot_radio, "failed to set frequency sub band", mdot_ret);
            ok = false;
        }
        
        printf("setting ADR\r\n");
        if ((mdot_ret = mdot_radio->setAdr(config_adr_on)) != mDot::MDOT_OK) {
            log_error(mdot_radio, "failed to set ADR", mdot_ret);
            ok = false;
        }

       /*
        * setNetworkName is used for private networks.
        * Use setNetworkID(AppID) for public networks
        */ 
        printf("setting network name\r\n");
        if ((mdot_ret = mdot_radio->setNetworkId(config_app_id)) != mDot::MDOT_OK) {
            log_error(mdot_radio, "failed to set network name", mdot_ret);
            ok = false;
        }

       /*
        * setNetworkPassphrase is used for private networks
        * Use setNetworkKey for public networks
        */ 
        printf("setting network key\r\n");
        if ((mdot_ret = mdot_radio->setNetworkKey(config_app_key)) != mDot::MDOT_OK) {
            log_error(mdot_radio, "failed to set network password", mdot_ret);
            ok = false;
        } 

        checkForExit(true);

    }while(ok == false);

    joinTicker.attach(joinLedToggle,1); 
    
    // attempt to join the network
    printf("joining network\r\n");
    char letter;
    while ((mdot_ret = mdot_radio->joinNetwork()) != mDot::MDOT_OK) { 
        log_error(mdot_radio,"failed to join network:", mdot_ret);
        if (mdot_radio->getFrequencyBand() == mDot::FB_868){
            mdot_ret = mdot_radio->getNextTxMs();
        }
        else {
            mdot_ret = 0;
        } 
        checkForExit(true);
        scanf("  %c", &letter );
        printf("value of letter = %c\n", letter );
        printf("delay = %lu\n\r",mdot_ret);
        osDelay(mdot_ret + 10000);
    } 
    printf("network joined\r\n");

    joinTicker.detach(); 
    JOIN_LED=1;
}


int main()
{
    BoardSensorData sensorData;
    std::vector<uint8_t> frame;
    
    // Board specific initialization
    BoardInit(); 

    // Configure mDot and join
    mDotConfigureAndJoin();

    // Do board specific post join configuration
    PostJoinInit();

    /*
     * Main data acquisition loop
     */
    while(!checkForExit(false))
    {
        if( PERIOD_DELAY  > 0 )
            osDelay( PERIOD_DELAY ); 

        // Minimum delay between sampling
        if( ( sample_period % FAST_SEND_PERIOD ) == 0 )
        {
            // Acquire sensor values
            ReadSensors(sensorData);

            // Generate frame if send conditions are satisified
            if( PrepareFrame(frame, sensorData) > 0 )
            {
                // Send sensor packets
                SendFrame( frame );
            }
        }
        sample_period++;
    } 

    ExitingProgram();
}
