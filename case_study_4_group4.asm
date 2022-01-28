#include <xc.h>
#include <pic.h>
#pragma config  FOSC=HS, CP=OFF, DEBUG=OFF, BORV=20, BOREN=0, MCLRE=ON, PWRTE=ON, WDTE=OFF
#pragma config  BORSEN=OFF, IESO=OFF, FCMEN=0

#define PORTBIT(adr,bit)	((unsigned)(&adr)*8+(bit))

static bit		greenButton		@	PORTBIT(PORTC,1);
static bit		redButton	@	PORTBIT(PORTC,0);
int mode = 0; //initializing the different modes
int modeOneFresh = 0; //initializing the mode 1
int modeTwoFresh = 0; //initializing the mode 2
int modeThreeFresh = 0;
int modeOneState = 0;
int modeTwoState = 0;
int motorOnePhase = 0;
int motorTwoPhase = 0;

char biMotorSteps[4] = {0x40, 0x00, 0x10, 0x50};
int biMotorIndex = 0;


void switchDelay (void) // Waits for switch debounce
{
	for (int i=140; i > 0; i--) {} // 1200 us delay
}

void buttonPressCheck (void) // Waits for switch debounce
{
	for (int i=10000; i > 0; i--) {}
}

char bitCheck(char flag, char bitshift){
	char check = flag & (1<<bitshift);
	return check;
}

void init()
{

	//clear output latches
    PORTA = 0x00;
	PORTB = 0x00;
	PORTC = 0x00;
	PORTD = 0x00;
	PORTE = 0x00;

	//configure I/O
    TRISA = 0xFF;
	TRISB = 0xF0;	//led
	TRISC = 0xFF;	//buttons
	TRISD = 0x00;	//motors
	TRISE = 0xFF;	//octal

	//configure Digital/Analog
	ADCON1 = 0B00001111; //all digital (p. 153)


	PSPMODE = 0; //disable parallel slave port multiplex on PORTD
/*
	//timer 0
	T0CS = 0; //use internal clock
    TMR0IE = 1; //enable interrupt
    TMR0 = 0x00;

	//1:8 pre-scalar
	PSA = 0;
	PS2 = 0;
	PS1 = 1;
	PS0 = 0;
	INTEDG = 0; //falling edge trigger
   	GIE = 1; //enable global interrupts

	PORTD = 0B10100000;
*/
}

char readMode(){
    // TO BE CODED - MOVE ON TO OTHER STUFF FIRST
	//char Read_PortE = ~PORTE & 0x07; //invert and retain last 3 bits
	//mode = Read_PortE; //store mode

	//invalid mode, add error light
	//if(Read_PortE == 0 || Read_PortE > 4){
	//	Read_PortE = Read_PortE | 0B00001000;
	//}
    mode = 7 - (PORTEbits.RE0 + 2*PORTEbits.RE1 + 4*PORTEbits.RE2); //reading the modes according to the mode set on the octal
	return mode;
}

void moveUniMotor(int direction, int breaker) //steps to move the unipolar motor
{
    if (direction == 0)
    {
        PORTD = 0x08;
        char temp = 0x08;
        while(1)
        {
            temp = (temp >> 1);
            if (temp == 0)
            {
                temp = 0x08;
            }
            PORTD = temp;
            switchDelay();

            if (breaker == 0)
            {
                if (PORTAbits.RA0 == 0) //movement of the motor according to the horizontal Interrupter
                    break;
            } else if (breaker ==1)
            {
                if (PORTAbits.RA1 == 0) //movement of the motor according to the vertical Interrupter
                    break;
            }
        }

    } else if (direction == 1)
    {
        PORTD = 0x01;
        char temp = 0x01;
        while(1)
        {
            temp = (temp << 1);
            if (temp == 0x10)
            {
                temp = 0x01;
            }
            PORTD = temp;
            switchDelay();

            if (breaker == 0)
            {
                if (PORTAbits.RA0 == 0) //movement of the motor according to the horizontal Interrupter
                    break;
            } else if (breaker ==1)
            {
                if (PORTAbits.RA1 == 0) //movement of the motor according to the vertical Interrupter
                    break;
            }
        }
    }
}

void moveBiMotor(int direction, int breaker) //steps to move the Bipolar motor
{
    PORTD = 0xA0;
    while(1)
    {
        PORTD = biMotorSteps[biMotorIndex];
        if (direction == 0)
        {
            biMotorIndex = (biMotorIndex - 1) % 4;
        }
        else
        {
            biMotorIndex = (biMotorIndex +1) % 4;
        }
        switchDelay();

        if (breaker == 3)
        {
            if (PORTAbits.RA3 == 0)//movement of the motor according to the vertical Interrupter
                break;
        } else if (breaker == 2)
        {
            if (PORTAbits.RA2 == 0) //movement of the motor according to the horizontal Interrupter
                break;
        }
    }
}

void sendHome() //initializing the motor to its home position that is to the horizontal interruptors
{
    PORTD = 0x08;
    char temp = 0x08;
    while(1)
    {
        temp = (temp >> 1);
        if (temp == 0)
        {
            temp = 0x08;
        }
        PORTD = temp;
        switchDelay();
        if (mode == 1 || mode == 2 || mode == 4) //checking if it is mode 1, 2 or 4
        {
            if (PORTAbits.RA0 == 0) //movement of the motor according to the horizontal Interrupter
                break;
        }
        else if (mode == 3)
        {
            if (PORTAbits.RA1 == 0) //movement of the motor according to the vertical Interrupter
                break;
        }
    }

    PORTD = 0x00;
    PORTD = 0xA0;
    while(1)
    {
        PORTD = 0x40;
        switchDelay();
        PORTD = 0x00;
        switchDelay();
        PORTD = 0x10;
        switchDelay();
        PORTD = 0x50;
        switchDelay();
        if (PORTAbits.RA2 == 0)
            break;
    }
}

void modeOneOnRed() //Mode 1 of Case study 4
{
    if (modeOneFresh)
    {
        sendHome();
        modeOneFresh = 0;
        return;
    }

    switch(modeOneState) //Mode 1 of Case study 4
    {
        case 0: //moving the motor according to mode 1
            moveUniMotor(0,1);
            break;
        case 1:
            moveBiMotor(1,3);
            break;
        case 2:
            moveUniMotor(1,0);
            break;
        case 3:
            moveBiMotor(0,2);
            break;
    }
    modeOneState = (modeOneState + 1) % 4;
}

void stepMotorOne()//stepping the motor (Full Step)(setting the bits on Port D)
{
    switch (motorOnePhase)
    {
        case 0:
        {
            PORTDbits.RD0 = 1;
            PORTDbits.RD1 = 0;
            PORTDbits.RD2 = 0;
            PORTDbits.RD3 = 1;
            break;
        }
        case 1:
        {
            PORTDbits.RD0 = 1;
            PORTDbits.RD1 = 1;
            PORTDbits.RD2 = 0;
            PORTDbits.RD3 = 0;
            break;
        }
        case 2:
        {
            PORTDbits.RD0 = 0;
            PORTDbits.RD1 = 1;
            PORTDbits.RD2 = 1;
            PORTDbits.RD3 = 0;
            break;
        }
        case 3:
        {
            PORTDbits.RD0 = 0;
            PORTDbits.RD1 = 0;
            PORTDbits.RD2 = 1;
            PORTDbits.RD3 = 1;
            break;
        }
    }
}

void waveMotorOne(void) //wave motor drive of the motor(setting the bits)
{
	switch (motorOnePhase)
	{
        case 0:
		{
			PORTDbits.RD0 = 0;
			PORTDbits.RD1 = 0;
			PORTDbits.RD2 = 0;
			PORTDbits.RD3 = 1;
			break;
		}
		case 1:
		{
			PORTDbits.RD0 = 1;
			PORTDbits.RD1 = 0;
			PORTDbits.RD2 = 0;
			PORTDbits.RD3 = 0;
			break;
		}
		case 2:
		{
			PORTDbits.RD0 = 0;
			PORTDbits.RD1 = 1;
			PORTDbits.RD2 = 0;
			PORTDbits.RD3 = 0;
			break;
		}
		case 3:
		{
			PORTDbits.RD0 = 0;
			PORTDbits.RD1 = 0;
			PORTDbits.RD2 = 1;
			PORTDbits.RD3 = 0;
			break;
		}
	}
}

void stepMotorTwo() //stepping the motor (Full Step) (setting the bits)
{
    switch(motorTwoPhase)
    {
        case 0:
        {
            PORTDbits.RD4 = 0;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 0;
            PORTDbits.RD7 = 0;
            break;
        }
        case 1:
        {
            PORTDbits.RD4 = 1;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 0;
            PORTDbits.RD7 = 0;
            break;
        }
        case 2:
        {
            PORTDbits.RD4 = 1;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 1;
            PORTDbits.RD7 = 0;
            break;
        }
        case 3:
        {
            PORTDbits.RD4 = 0;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 1;
            PORTDbits.RD7 = 0;
            break;
        }
    }
}

void waveMotorTwo(void) //wave motor drive of the motor (setting the bits)
{
	switch(motorTwoPhase)
    {
        case 0:
        {
            PORTDbits.RD4 = 0;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 0;
            PORTDbits.RD7 = 0;
            break;
        }
        case 1:
        {
            PORTDbits.RD4 = 1;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 0;
            PORTDbits.RD7 = 0;
            break;
        }
        case 2:
        {
            PORTDbits.RD4 = 1;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 1;
            PORTDbits.RD7 = 0;
            break;
        }
        case 3:
        {
            PORTDbits.RD4 = 0;
            PORTDbits.RD5 = 0;
            PORTDbits.RD6 = 1;
            PORTDbits.RD7 = 0;
            break;
        }
    }
}


void moveModeTwo1() //mode two of case study 4 step 1, here the mode 2, 3 and 4 have been declared at once
{
    int motorOneDirection = 0;
    int motorTwoDirection = 0;
    if (mode == 2 || mode == 4)
    {
         motorOneDirection = -1;
         motorTwoDirection = 1;
    }
    else if (mode == 3)
    {
        motorOneDirection = -1;
        motorTwoDirection = -1;
    }

    while(1)
    {
        if (mode == 4)
            waveMotorOne();
        else
            stepMotorOne();
        motorOnePhase = (motorOnePhase + motorOneDirection) % 4;

        if (mode == 4)
            waveMotorTwo();
        else
            stepMotorTwo();
        motorTwoPhase = (motorTwoPhase + motorTwoDirection) % 4;

        switchDelay();

        if (PORTAbits.RA1 == 0 && (mode == 2 || mode == 4) || PORTAbits.RA0 == 0 && mode == 3) // if motor 1 reaches end before motor 2, keep running motor 2
        {
            while(1)
            {
                if (mode == 4)
                    waveMotorTwo();
                else
                    stepMotorTwo();
                motorTwoPhase = (motorTwoPhase + motorTwoDirection) % 4;
                switchDelay();
                if (PORTAbits.RA3 == 0) //movement of the motor according to the vertical Interrupter
                    break;
            }
            break;
        }
        else if (PORTAbits.RA3 == 0) // if motor 2 reaches end before motor 1, keep running motor 1
        {
            while(1)
            {
                if (mode == 4)
                    waveMotorOne();
                else
                    stepMotorOne();
                motorOnePhase = (motorOnePhase + motorOneDirection) % 4;
                switchDelay();
                if (PORTAbits.RA1 == 0 && (mode == 2 || mode == 4) || PORTAbits.RA0 == 0 && mode == 3) //Checking which mode is set according to the horizontal and vertical interruptors
                    break;
            }
            break;
        }
    }
}

void moveModeTwo2() //mode two of case study 4 step 2, here the mode 2, 3 and 4 have been declared at once
{
    int motorOneDirection = 0;
    int motorTwoDirection = 0;
    if (mode == 2 || mode == 4)
    {
         motorOneDirection = 1;
         motorTwoDirection = -1;
    }
    else if (mode == 3)
    {
        motorOneDirection = 1;
        motorTwoDirection = 1;
    }

    while(1)
    {
        if (mode == 4)
            waveMotorOne();
        else
            stepMotorOne();
        motorOnePhase = (motorOnePhase + motorOneDirection) % 4;
        if (mode == 4)
            waveMotorTwo();
        else
            stepMotorTwo();
        motorTwoPhase = (motorTwoPhase + motorTwoDirection) % 4;
        switchDelay();

        if (PORTAbits.RA0 == 0 && (mode == 2 || mode == 4) || PORTAbits.RA1 == 0 && mode == 3) // if motor 1 reaches end before motor 2, keep running motor 2
        {
            while(1)
            {
                if (mode == 4)
                    waveMotorTwo();
                else
                    stepMotorTwo();
                motorTwoPhase = (motorTwoPhase + motorTwoDirection) % 4;
                switchDelay();
                if (PORTAbits.RA2 == 0)
                    break;
            }
            break;
        }
        else if (PORTAbits.RA2 == 0) // if motor 2 reaches end before motor 1, keep running motor 1
        {
            while(1)
            {
                if (mode == 4)
                    waveMotorOne();
                else
                    stepMotorOne();
                motorOnePhase = (motorOnePhase + motorOneDirection) % 4;
                switchDelay();
                if (PORTAbits.RA0 == 0 && (mode == 2 || mode == 4) || PORTAbits.RA1 == 0 && mode == 3)
                    break;
            }
            break;
        }
    }
}


void modeTwoOnRed() //mode 2 on redpress
{
    if (modeTwoFresh)
    {
        sendHome();
        modeTwoFresh = 0;
    }
    while(1)
    {
        if(redButton == 0)
        {
            buttonPressCheck();
            if(redButton == 0)
            {
                while(redButton == 0){} // Wait for release
                switchDelay(); // Let switch debounce
                break;
            }
        }

        motorOnePhase = 0;
        motorTwoPhase = 0;
        moveModeTwo1(); // Move motor 1 CW and motor 2 CCW

        if(redButton == 0 && mode != 4)
        {
            buttonPressCheck();
            if(redButton == 0)
            {
                while(redButton == 0){} // Wait for release
                switchDelay(); // Let switch debounce
                break;
            }
        }

        motorOnePhase = 0;
        motorTwoPhase = 0;
        moveModeTwo2(); // Move motor 2 CW and motor 1 CCW
    }
}

void modeThreeOnRed()
{
    if (modeThreeFresh)
    {
        sendHome();
        modeThreeFresh = 0;
    }
}

void modeZeroOnRed() //setting the error light on the led for the modes that show error
{
    PORTBbits.RB0 = 0;
    PORTBbits.RB1 = 0;
    PORTBbits.RB2 = 0;
    PORTBbits.RB3 = 1;
}

void onRedPress() {
    if (mode == 1)
    {
        modeOneOnRed();
    }
    if (mode == 2 || mode == 3 || mode == 4) //checking which mode has been set
    {
        modeTwoOnRed();
    }
    if (mode == 5 || mode == 6 || mode == 7 || mode == 0) //checking for the mode (This is for the modes that show error)
    {
        modeZeroOnRed();
    }
}


void main (void) //main function of the case study 4
{
    init();
	while(1) // Infinite loop
	{
		if(redButton == 0)
        {
			while(redButton == 0){} // Wait for release
			switchDelay(); // Let switch debounce
			onRedPress();
		}

        if(greenButton == 0) //checking green press
        {
			while(greenButton == 0){} // Wait for release
			switchDelay(); // Let switch debounce
			PORTB = readMode(); // Display Count value on PORTD LEDs
            modeOneFresh = 1;
            modeTwoFresh = 1;
            modeThreeFresh = 1;
            modeOneState = 0;
		}
	}
}
