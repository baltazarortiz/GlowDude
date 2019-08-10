# GlowDude: Motion Sensitive LED Cubes
Final project for 6.115, Microcomputer Project Laboratory. Notes adapted from
project proposal.

## Overview
This system allows one or more 8051-based “smart cubes” to
wirelessly connect to a Cypress PSoC. When sent requests by the PSoC, each cube responds with
information about its orientation and movement that it gathers from an InvenSense IMU module,
which contains an accelerometer, gyroscope, and magnetometer. Using this data, the PSoC
commands the cubes to change colors. This system can be used to implement games or tech
demos that demonstrate applications of sensor fusion.

## Hardware Description
There are two hardware components to this project: the cube(s) and the PSoC, which acts as a
sort of “base” for the cubes.

Each cube is identical from a hardware perspective. The design is centered around the Atmel
AT89S8253, an 8051-compatible chip.
The AT89S8253 is connected to an MPU-9250 with SPI and uses a HC-05
Bluetooth module with UART to create a wireless serial interface. Both protocols are natively
supported by the AT89S8253.

The AT89S8253 can be battery powered to provide the correct voltage for it to operate as a 3.3V
microcontroller. This eliminates the need to use a level shifter to interface with the
MPU-9250 or HC-05. Batteries can be removed to be charged externally, avoiding the
need for included charging hardware.

In response to commands from the PSoC (see Software Description below), the
8253 drives six RGB LEDs (one for each face of the cube) by interfacing with an IS31FL3218
driver chip (hereafter referred to as the LED driver) over a bit-banged I2C driver.

The PSoC acts as a central base or hub for one or more cubes. It uses one HC-05 chip per cube to
create wireless serial connections to communicate with the cubes. It also drives a small numberof RGB LEDs using PWM modules. These can be used to display information for various demos.

## Software Description
Upon powering on, the cube initializes the IMU, LED driver, HC-05, and any internal timers or
values that need to be set. It then moves to an idle state, which can optionally be taken advantage
of to do some processing of any IMU data that is available.

In the idle state, the cube regularly polls the IMU to get up to date sensor readings.

When the cube receives a signal from the PSoC (detailed below), it interprets the command that
has been sent. It then either updates the LED state and sends a response signal,
or it just sends a response with the data that
has been requested.

Although the hardware the PSoC is attached to is relatively simple, it handles the brunt of the
computation and data handling in this system. Upon powering on, the PSoC initializes the
HC-05s and any internal components that are needed, then transition to an idle state, which
carries out the game logic for the current game mode or tech demo. 

On a regular basis, the PSoC polls all of the connected cubes in a round robin fashion, using the
following process for each cube:
1. Send a request for IMU data and wait until the cube sends a response back with the data.
2. Process data as needed (get orientation, motion, etc).3. Send a command to the cube to change its LEDs appropriately
Project Scope and Management

## Components
* 1 Cypress PSoC
* Per Cube:
  * AT89S8253 DIP
  * 1 MPU-9250
  * 1 IS31FL3218 + SMD to DIP adapters
  * 2 HC-05 chips (one inside cube, one connected to PSoC)
  * 6 RGB LEDs
  * Zero-insertion force chip carrier for 8253
  * Opaque plastic cube (3D printed)
