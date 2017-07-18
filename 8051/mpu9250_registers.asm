; Other constants
.equ IMU_ADDR, 0xd0

.equ GYRO_FS_250, 0x00
.equ AFS_2G, 0x00

; Register map for accelerometer and gyroscope in the mpu-9250
.equ SELF_TEST_X_GYRO,  0x00
.equ SELF_TEST_Y_GYRO,  0x01
.equ SELF_TEST_Z_GYRO,  0x02
.equ SELF_TEST_X_ACCEL, 0x0d
.equ SELF_TEST_Y_ACCEL, 0x0e
.equ SELF_TEST_Z_ACCEL, 0x0f
.equ XG_OFFSET_H, 0x13
.equ XG_OFFSET_L, 0x14
.equ YG_OFFSET_H, 0x15
.equ YG_OFFSET_L, 0x16
.equ ZG_OFFSET_H, 0x17
.equ ZG_OFFSET_L, 0x18
.equ SMPLRT_DIV, 0x19
.equ CONFIG, 0x1a
.equ GYRO_CONFIG, 0x1b
.equ ACCEL_CONFIG, 0x1c
.equ ACCEL_CONFIG2, 0x1d
.equ LP_ACCEL_ODR, 0x1e
.equ WOM_THR, 0x1f
.equ FIFO_EN, 0x23
.equ I2C_MST_CTRL, 0x24
.equ I2C_SLV0_ADDR, 0x25
.equ I2C_SLV0_REG, 0x26
.equ I2C_SLV0_CTRL, 0x27
.equ I2C_SLV1_ADDR, 0x28
.equ I2C_SLV1_REG, 0x29
.equ I2C_SLV1_CTRL, 0x2a
.equ I2C_SLV2_ADDR, 0x2b
.equ I2C_SLV2_REG, 0x2c
.equ I2C_SLV2_CTRL, 0x2d
.equ I2C_SLV3_ADDR, 0x2e
.equ I2C_SLV3_REG, 0x2f
.equ I2C_SLV3_CTRL, 0x30
.equ I2C_SLV4_ADDR, 0x31
.equ I2C_SLV4_REG, 0x32
.equ I2C_SLV4_DO, 0x33
.equ I2C_SLV4_CTRL, 0x34
.equ I2C_SLV4_DI, 0x35
.equ I2C_MST_STATUS, 0x36
.equ INT_PIN_CFG, 0x37
.equ INT_ENABLE, 0x38
.equ INT_STATUS, 0x3a
.equ ACCEL_XOUT_H, 0x3b
.equ ACCEL_XOUT_L, 0x3c
.equ ACCEL_YOUT_H, 0x3d
.equ ACCEL_YOUT_L, 0x3e
.equ ACCEL_ZOUT_H, 0x3f
.equ ACCEL_ZOUT_L, 0x40
.equ TEMP_OUT_H, 0x41
.equ TEMP_OUT_L, 0x42
.equ GYRO_XOUT_H, 0x43
.equ GYRO_XOUT_L, 0x44
.equ GYRO_YOUT_H, 0x45
.equ GYRO_YOUT_L, 0x46
.equ GYRO_ZOUT_H, 0x47
.equ GYRO_ZOUT_L, 0x48
.equ EXT_SENS_DATA_00, 0x49 
.equ EXT_SENS_DATA_01, 0x4a
.equ EXT_SENS_DATA_02, 0x4b
.equ EXT_SENS_DATA_03, 0x4c 
.equ EXT_SENS_DATA_04, 0x4d
.equ EXT_SENS_DATA_05, 0x4e
.equ EXT_SENS_DATA_06, 0x4f
.equ EXT_SENS_DATA_07, 0x50
.equ EXT_SENS_DATA_08, 0x51
.equ EXT_SENS_DATA_09, 0x52
.equ EXT_SENS_DATA_10, 0x53
.equ EXT_SENS_DATA_11, 0x53
.equ EXT_SENS_DATA_12, 0x55
.equ EXT_SENS_DATA_13, 0x56
.equ EXT_SENS_DATA_14, 0x57
.equ EXT_SENS_DATA_15, 0x58
.equ EXT_SENS_DATA_16, 0x59
.equ EXT_SENS_DATA_17, 0x5a
.equ EXT_SENS_DATA_18, 0x5b
.equ EXT_SENS_DATA_19, 0x5c
.equ EXT_SENS_DATA_20, 0x5d
.equ EXT_SENS_DATA_21, 0x5e
.equ EXT_SENS_DATA_22, 0x5f
.equ EXT_SENS_DATA_23, 0x60
.equ I2C_SLV0_DO, 0x63
.equ I2C_SLV1_DO, 0x64
.equ I2C_SLV2_DO, 0x65
.equ I2C_SLV3_DO, 0x66
.equ I2C_MST_DELAY_CTRL, 0x67
.equ SIGNAL_PATH_RESET, 0x68
.equ MOT_DETECT_CTRL, 0x69
.equ USER_CTRL, 0x6a
.equ PWR_MGMT_1, 0x6b
.equ PWR_MGMT_2, 0x6c
.equ FIFO_COUNTH, 0x72
.equ FIFO_COUNTL, 0x73
.equ FIFO_R_W, 0x74
.equ WHO_AM_I, 0x75
.equ WHOAMI_VAL, 0x71 ; expected output when reading WHOAMI reg
.equ XA_OFFSET_H, 0x77
.equ XA_OFFSET_L, 0x78
.equ YA_OFFSET_H, 0x7a
.equ YA_OFFSET_L, 0x7b
.equ ZA_OFFSET_H, 0x7d
.equ ZA_OFFSET_L, 0x7e

; magnetometer i2c address
. equ MAG_ADDR, 0x18

; Register map for the magnetometer in the imu-9250
.equ WIA, 0x00
.equ MAG_WHOAMI_VAL, 0x48

.equ INFO, 0x01
.equ ST1, 0x02
.equ HXL, 0x03
.equ HXH, 0x04
.equ HYL, 0x05
.equ HYH, 0x06
.equ HZL, 0x07
.equ HZH, 0x08
.equ ST2, 0x09
.equ CNTL, 0x0a
; .equ RSV, 0x0b ; do not access
.equ ASTC, 0x0c
; .equ TS1, 0x0d ; do not access
; .equ TS2, 0x0e ; do not access
.equ I2CDIS, 0x0f
.equ ASAX, 0x10
.equ ASAY, 0x11
.equ ASAZ, 0x12
