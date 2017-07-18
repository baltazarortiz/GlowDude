/* ========================================
 *
 * Copyright YOUR COMPANY, THE YEAR
 * All Rights Reserved
 * UNPUBLISHED, LICENSED SOFTWARE.
 *
 * CONFIDENTIAL AND PROPRIETARY INFORMATION
 * WHICH IS THE PROPERTY OF your company.
 *
 * ========================================
*/
#include <project.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>

#define DEFAULT_BRIGHTNESS (uint8)20
#define LED_DELAY 100

//IS31FL3218 control registers
#define CTL12 (uint8)0x13
#define CTL34 (uint8)0x14
#define CTLTB (uint8)0x15

//IS31FL3218 pins corresponding to each RGB LED
#define LED_S1   (uint8)1
#define LED_S1_R (uint8)1
#define LED_S1_G (uint8)2
#define LED_S1_B (uint8)3

#define LED_S2   (uint8)4
#define LED_S2_R (uint8)4
#define LED_S2_G (uint8)5
#define LED_S2_B (uint8)6

#define LED_S3   (uint8)7
#define LED_S3_R (uint8)7
#define LED_S3_G (uint8)8
#define LED_S3_B (uint8)9

#define LED_S4   (uint8) 10
#define LED_S4_R (uint8)10
#define LED_S4_G (uint8)11
#define LED_S4_B (uint8)12

#define LED_BOTTOM   (uint8)13
#define LED_BOTTOM_R (uint8)13
#define LED_BOTTOM_G (uint8)14
#define LED_BOTTOM_B (uint8)15

#define LED_TOP   (uint8)16
#define LED_TOP_R (uint8)16
#define LED_TOP_G (uint8)17
#define LED_TOP_B (uint8)18


typedef enum { A, B, D} glowdude; //used to select which cube we're communcating with
typedef enum {TOP,BOTTOM,S1,S2,S3,S4, MOVING} orientation;
typedef enum {RED, GREEN, BLUE, PURPLE, ORANGE} colors;

void uart_wait(glowdude g);
void glowdudecal(glowdude g);
uint8 readchar(glowdude g);
void readchars(char *str, uint8 len, glowdude g);
void sendcmd(uint8 cmd, glowdude g);
void glowdudeinit(glowdude g);
uint8 readhex8(glowdude g);
uint16 readhex16(glowdude g);
void readaccel(glowdude g, double* dest);
orientation getorientation(glowdude g);
void sendlongcmd(char* cmd, glowdude g);

void ledEnable(glowdude g, uint8 ctl, uint8 pattern);
void ledUpdate(glowdude g);
void ledPWM(glowdude g, uint8 led, uint8 pwm);
void led_color(glowdude g, uint8 led, uint8 r, uint8 gr, uint8 b); 
void led_red(glowdude g, uint8 led);
void led_green(glowdude g, uint8 led);
void led_blue(glowdude g, uint8 led);
void led_purple(glowdude g, uint8 led);
void led_orange(glowdude g, uint8 led);
void gammaRGB(glowdude g, uint8 step, uint8 led);
uint8 gammaColor(uint8 step);
void debugConsole();

//TODO: struct for orientation to color mapping
struct colormap {
    //index into these arrays using orientation enum values
    uint8 c_r[7];
    uint8 c_g[7];
    uint8 c_b[7];
};

#define DEBUG_UART

int main()
{
    CyGlobalIntEnable; /* Enable global interrupts. */

    /* Place your initialization/startup code here (e.g. MyInst_Start()) */
    // Start UARTS
    UART_A_Start();
    UART_B_Start();
    UART_DEBUG_Start();

    //TODO: needed?
//    UART_B_ClearRxBuffer();
//    UART_DEBUG_ClearRxBuffer();
    
    uint8 rxData;
    uint8 inputData;
    double accelRead[3]; 
    
    bool prompt = false;
    
    //CyDelay(3000); // wait for pairing
    
    glowdudeinit(B);
    getorientation(B);
    glowdudecal(B);

/*    
    sendcmd('p',B);
    sendcmd('0',B);
    sendcmd('7',B);
    sendcmd('2',B);
    sendcmd('0',B);
        CyDelay(15);
    sendcmd('p',B);
    sendcmd('0',B);
    sendcmd('b',B);
    sendcmd('2',B);
    sendcmd('0',B);
    CyDelay(15);    
    sendcmd('p',B);
    sendcmd('0',B);
    sendcmd('f',B);
    sendcmd('2',B);
    sendcmd('0',B);
    
    CyDelay(15);
    sendcmd('u',B);
*/
    
    led_red(B, LED_S4);
    led_red(B,LED_S3);
    led_red(B,LED_BOTTOM);
    led_red(B, LED_S2);
    led_red(B, LED_S1);
    led_red(B, LED_TOP);
    
    CyDelay(20);
    ledUpdate(B);
    
    for(;;)
    {
      //  debugConsole();
        
       getorientation(B);
   //   UART_DEBUG_PutString("\n");
       //CyDelay(200);
        
    }
}

void debugConsole()
{
        bool prompt = false;
        uint8 rxData = readchar(B); // store received characters in temporary variable
        uint8 inputData;
        if(rxData) { // make sure data is non-zero
            #ifdef DEBUG_UART
               // UART_DEBUG_PutChar(rxData); // echo characters in terminal window
               //  UART_DEBUG_PutString("\n");
            #endif
            
            if (rxData == '*') {
                prompt = true;
            }
            else {
                prompt = false;   
            }
        }

        #ifdef DEBUG_UART
            // Send data over debug UART
            inputData = UART_DEBUG_GetChar();
            if (inputData) {
                UART_B_PutChar(inputData);
            }   
        #endif
}

bool whoami(glowdude g)
{    
    sendcmd('w', g);    
 
    uint8 whoamival = 0;
    whoamival = readhex8(g);
    
    #ifdef DEBUG_UART
        UART_DEBUG_PutString("WHOAMI: ");
    #endif
 
    if (whoamival == (uint8)(1))
    {
        UART_DEBUG_PutString("true\r\n");
        return true;   
    }
    else {
        UART_DEBUG_PutString("false\r\n");
        return false;   
    }
}

void gameSelect()
{
    UART_DEBUG_PutString("Welcome to Glowdude! Pick a mode:\n");
    UART_DEBUG_PutString("1: Color Blend demo\n2: Color maze game\n");
    uart_wait(D); // wait for user input
    
    switch(readchar(D))
    {
        case '1':
            colorBlend();
        break;
        case '2':
          //  mazeGame();
        break;
        default:
            UART_DEBUG_PutString("Invalid option. Please enter 1 or 2 to pick a mode!");
        break;
    }
    
}

//TECH DEMO:
void colorBlend()
{
    //one colormap for each cube, one for blended colors
    orientation ao;
    orientation bo;    
    uint8 step = 0;
    bool continue = true;
    
    for(;;) {
        led_
        
        //reset colors
        led_red(A, LED_BOTTOM);
        led_green(A,LED_S1);
        led_blue(A, LED_S2);
        led_orange(A, LED_S3);
        led_purple(A, LED_S4);

        led_red(B, LED_BOTTOM);
        led_green(B,LED_S1);
        led_blue(B, LED_S2);
        led_orange(B, LED_S3);
        led_purple(B, LED_S4);
    
        UART_DEBUG_PutString("Rotate the cubes to show the colors you want to mix!\n");
        UART_DEBUG_PutString("Then type 'M'");
        
        uart_wait(D);
        
        if (readchar(D) == 'M') {
            ao = getorientation(A);
            bo = getorientation(B);
            
            if (ao == MOVING || bo == MOVING)
            {
                // color breathe led on psoc
                gammaColor(step);
                step++;
            }
            else //show blend of the colors
            {
                if (ao == TOP) {
                    //show b color
                    
                }
                else if (bo == TOP) {
                    //show a color
                }
                else if (ao == bo) {
                    // no change
                }
                else if (ao == S1 && bo == S2) {
                
                }
                else if (ao == S1 && bo == S3) {
                
                }
                else if (ao == S1 && bo == S4) {
                
                }
                else if (ao == S2 && bo == S3) {
                
                }
                else if (ao == S2 && bo == S4) {
                
                }
                else if (ao == S3 && bo == S2) {
                
                }
                else if (ao == S3 && bo == S4) {
                
                }
                else {
                    UART_DEBUG_PutString("ERROR: invalid color combination.\n");
                }
            } 
            
            UART_DEBUG_PutString("Press 'Y' to mix again or any other key to go back to the menu.");
            uart_wait(D);
            
            if(readchar(D) != 'Y') {
                return;
            }       
        }
        else {
            UART_DEBUG_PutString("Please press 'M' to mix!");
        }
    }
}

//GAME:
void mazeGame()
{
    uint8 ascore = 0;
    uint8 bscore = 0;
    
    orientation ao;
    orientation bo;
    
    orientation target;
    orientation target_old;
    
    //init color map 
    
    typedef enum {TOP,BOTTOM,S1,S2,S3,S4, MOVING} orientation;
    
    char* colornames[6];
    colornames[0] = "No Color (off)";
    colornames[1] = "Red";
    colornames[2] = "Green";
    colornames[3] = "Blue";
    colornames[4] = "Orange";
    colornames[5] = "Purple";

    UART_DEBUG_PutString("Welcome to mazeGame!\nI will tell you which color to find. ");
    UART_DEBUG_PutString("Then, whichever player finds the color first gets the point! ");
    UART_DEBUG_PutString("First to 5 points wins.\n\n");
    
    UART_DEBUG_PutString("Starting in 3...");
    CyDelay(500);
    UART_DEBUG_PutString("2...");
    CyDelay(500);
    UART_DEBUG_PutString("1...");

    // show colors on cubes
    led_red(A, LED_BOTTOM);
    led_green(A,LED_S1);
    led_blue(A, LED_S2);
    led_orange(A, LED_S3);
    led_purple(A, LED_S4);

    led_red(B, LED_BOTTOM);
    led_green(B,LED_S1);
    led_blue(B, LED_S2);
    led_orange(B, LED_S3);
    led_purple(B, LED_S4); 
        
    target = 0;
    target_old = 0;

    UART_DEBUG_PutString("Target color: ");
    UART_DEBUG_PutString(colornames[target]);
    UART_DEBUG_PutString("\n");

    
    while(ascore < 5 && bscore < 5)
    {
        if (target != target_old) {
            UART_DEBUG_PutString("Target color: ");
            UART_DEBUG_PutString(colornames[target]);
            UART_DEBUG_PutString("\n");        
        }
        
        // check cube orientations
        ao = getorientation(A);
        bo = getorientation(B);
        
        // compare against target orientation
        if (ao == target) {
            ascore++;
            UART_DEBUG_PutString("Cube A gets a point!");
            target++;
        }    
        else if (bo == target) {
            bscore++;
            UART_DEBUG_PutString("Cube B gets a point!");
            target++;
        }
    }
    
    if (ascore == 5)
    {
        UART_DEBUG_PutString("Cube A wins!");
    }
    else if (bscore == 5)
    {
        UART_DEBUG_PutString("Cube B wins!");
    }
}

void waitforprompt(glowdude g)
{
    switch(g) {
        case A:
            while(UART_A_GetChar() != '*') {}
            break;
        case B:
            while(UART_B_GetChar() != '*') {}
            break;
        case D:
            while(UART_DEBUG_GetChar() != '*') {}
            break;
    }        
}

void sendcmd(uint8 cmd, glowdude g)
{
    switch(g) {
        case A:
            UART_A_PutChar(cmd);
            break;
        case B:
            UART_B_PutChar(cmd);
            break;
        case D:
            UART_DEBUG_PutChar(cmd);
            break;
    }
}

void sendlongcmd(char* cmd, glowdude g)
{
    switch(g) {
        case A:
            UART_A_PutString(cmd);
            break;
        case B:
            UART_B_PutString(cmd);
            break;
        case D:
            UART_DEBUG_PutString(cmd);
            break;
    }
}

void readaccel(glowdude g, double* dest)
{   
    sendcmd('a',g);
    
    int16 rx = readhex16(g);
    int16 ry = readhex16(g);
    int16 rz = readhex16(g);

    //16g scale for cube for some reason, 2 is set (works on r31jp)
	double x = rx*0.0001220703125;//4 //0.00006103515625; //*0.00048828125;//
    double y = ry*0.0001220703125;//4 //0.00006103515625; //*0.00048828125;//
    double z = rz*0.0001220703125;//4 //0.00006103515625; //*0.00048828125;//
	
    
    dest[0] = x;
    dest[1] = y;
    dest[2] = z;
    
    #ifdef DEBUG_UART
        char xs[40];
        char ys[40];
        char zs[40];
        
        sprintf(xs, "X: %5f \r\n", x);
        sprintf(ys, "Y: %f \r\n", y);
        sprintf(zs, "Z: %f \r\n", z);
        
        UART_DEBUG_PutString(xs);
    
        UART_DEBUG_PutString(ys);
        UART_DEBUG_PutString(zs);
    #endif
}

orientation getorientation(glowdude g)
{
    double adata[3];
    //thresholds for "0" and "1"
    double zero_t = 0.2;
    double one_t = 0.9;
    double negativeone_t = -0.9;
    
    //on r31jp
    //double zero_t = 0.008;
    //double one_t = 0.2;
    //double negativeone_t = -0.2;

    //cube
    //double zero_t = 0.05;
    //double one_t = 0.45;
    //double negativeone_t = -0.45;
    
    readaccel(g, adata);
    
    //adata[0] -> x, 1 -> y, 2 -> z
    //top: x=0,y=1,z=0
    if (adata[0] < zero_t && adata[1] > one_t && adata[2] < zero_t)
    {
        #ifdef DEBUG_UART
            UART_DEBUG_PutString("ORIENTATION: TOP");
        #endif 
        
        return TOP;   
    }
    //bottom: x=0,y=-1,z=0
    else if(adata[0] < zero_t && adata[1] < negativeone_t && adata[2] < zero_t)
    {
        #ifdef DEBUG_UART
            UART_DEBUG_PutString("ORIENTATION: BOTTOM");
        #endif 
                
         return BOTTOM;
    }
    //s1: x=0,y=0,z=-1
    else if (adata[0] < zero_t && adata[1] < zero_t && adata[2] > one_t)
    {
        #ifdef DEBUG_UART
            UART_DEBUG_PutString("ORIENTATION: S1");
        #endif 
        
        return S1;
    }
    //s2: x=-1,y=0,z=0
    else if (adata[0] < negativeone_t && adata[1] < zero_t && adata[2] < zero_t)
    {
        #ifdef DEBUG_UART
            UART_DEBUG_PutString("ORIENTATION: S2");
        #endif 
        
        return S2;
    }
    //s3: x=0,y=0,z=1
    else if (adata[0] < zero_t && adata[1] < zero_t && adata[2] < negativeone_t)
    {
        #ifdef DEBUG_UART
            UART_DEBUG_PutString("ORIENTATION: S3");
        #endif 
        
        return S3;
    }
    //s4: x=1,y=0,z=0
    else if (adata[0] > one_t && adata[1] < zero_t && adata[2] < zero_t)
    {
        #ifdef DEBUG_UART
            UART_DEBUG_PutString("ORIENTATION: S4");
        #endif 
        
        return S4;
    }
    else {
        #ifdef DEBUG_UART
            UART_DEBUG_PutString("ORIENTATION: MOVING");
        #endif 
        
        return MOVING;    
    }
}

// modified from psoc forums
void readchars(char *str, uint8 len, glowdude g)
{
    uint8 count = 0;
    char tmp;
    
    // Read characters until line break.
    while (count < len) // no buffer overflows
    {
        uart_wait(g);
        tmp = readchar(g);
        
        if (tmp != '*') {
            str[count] = tmp;
            count++;
        }
    }
}

// return the next hex string received on the uart as an int
uint8 readhex8(glowdude g)
{
    char hexstr[2];
    readchars(hexstr, 2, g);
    //TODO: does this break or fix things? UART_B_ClearRxBuffer();
    return (uint8)strtol(hexstr, NULL, 16);
}

uint16 readhex16(glowdude g)
{
    char hexstr[4];
    readchars(hexstr, 4, g);
      //  UART_DEBUG_PutString(hexstr);
        UART_DEBUG_PutString("\n");        

    return (uint16)strtol(hexstr, NULL, 16);    
}

uint8 readchar(glowdude g)
{
    switch(g){
        case A:
            return UART_A_GetChar();
            break;
        case B:
            return UART_B_GetChar();
            break;
        case D:
            return UART_DEBUG_GetChar();
            break;
    }
    
    return 0;
}

void uart_wait(glowdude g) {
    switch(g){
        case A:
            while(UART_A_ReadRxStatus() != UART_A_RX_STS_FIFO_NOTEMPTY);
            break;
        case B:
            while(UART_B_ReadRxStatus() != UART_B_RX_STS_FIFO_NOTEMPTY);
            break;
        case D:
            while(UART_DEBUG_ReadRxStatus() != UART_DEBUG_RX_STS_FIFO_NOTEMPTY);
            break;
    }
}

void glowdudecal(glowdude g)
{
   
}

void glowdudeinit(glowdude g)
{
    sendcmd('i', g);  //send init command    
    waitforprompt(g); // wait on init
    whoami(g);
}

void ledEnable(glowdude g, uint8 ctl, uint8 pattern)
{
    //construct command string
    char hexstr[2];
    sendcmd('p',g);
    itoa(ctl,hexstr,16);
    if (hexstr[0] == '\000')
    {
        hexstr[0] = '0';
    }
    if (hexstr[1] == '\000')
    {
        hexstr[1] = '0';
    }
    sendcmd(hexstr[1],g);
    sendcmd(hexstr[0],g);
    
    itoa(pattern,hexstr,16);
    if (hexstr[0] == '\000')
    {
        hexstr[0] = '0';
    }
    if (hexstr[1] == '\000')
    {
        hexstr[1] = '0';
    }
    sendcmd(hexstr[1],g);
    sendcmd(hexstr[0],g);
}

void ledPWM(glowdude g, uint8 led, uint8 pwm)
{
     //construct command string
    char hexstr[2];
    sendcmd('p',g);
    itoa(led,hexstr,16);
    if (hexstr[0] == '\000')
    {
        hexstr[0] = '0';
    }
    if (hexstr[1] == '\000')
    {
        hexstr[1] = '0';
    }
    sendcmd(hexstr[1],g);
    sendcmd(hexstr[0],g);
    itoa(pwm,hexstr,16);
    if (hexstr[0] == '\000')
    {
        hexstr[0] = '0';
    }
    if (hexstr[1] == '\000')
    {
        hexstr[1] = '0';
    }
    sendcmd(hexstr[1],g);
    sendcmd(hexstr[0],g);
}

void ledUpdate(glowdude g)
{
    sendcmd('u',g);
}

//general rgb led color method
void led_color(glowdude g, uint8 led, uint8 r, uint8 gr, uint8 b)
{
    ledPWM(g, led, r);
    CyDelay(LED_DELAY);
    ledPWM(g, led+1, g);
    CyDelay(LED_DELAY);
    ledPWM(g, led+2, b);
    CyDelay(LED_DELAY);
}

// generic led colors
void led_red(glowdude g, uint8 led)
{
    led_color(g, led, DEFAULT_BRIGHTNESS, 0, 0);
}

void led_green(glowdude g, uint8 led)
{
    led_color(g, led, 0, DEFAULT_BRIGHTNESS, 0);}

void led_blue(glowdude g, uint8 led)
{
    led_color(g, led, 0 ,0, DEFAULT_BRIGHTNESS);
}

void led_purple(glowdude g, uint8 led)
{
    led_color(g, led, DEFAULT_BRIGHTNESS, 0, DEFAULT_BRIGHTNESS);}

void led_orange(glowdude g, uint8 led)
{
    led_color(g, led, DEFAULT_BRIGHTNESS, DEFAULT_BRIGHTNESS, 0);
}

//set led colors to gamma step
void gammaRGB(glowdude g, uint8 step, uint8 led)
{
    uint8 pwm = gammaColor(step);
    led_color(g, led, pwm, pwm, pwm);
}

//32 step gamma correction table as per led driver datasheet
uint8 gammaColor(uint8 step)
{
    uint8 ctbl[32] = {0,1,2,4,6,10,13,18,22,28,33,39,46,
                      53,61,69,78,86,96,106,116,126,138,
                      149,161,173,186,199,212,240,255};

    if (step < 31)
        return ctbl[step];
    else
        return 0;
}

/* [] END OF FILE */
