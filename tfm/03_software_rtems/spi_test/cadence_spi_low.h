#ifndef CADENCE_SPI_LOW_H
#define CADENCE_SPI_LOW_H

#include <stdint.h>

/* Cadence SPI Register Offsets (ZynqMP PS SPI) */
#define CSPI_CONTROL_REG        0x00U /* Configuration Register (CR) */
#define CSPI_INTR_STATUS_REG    0x04U /* Interrupt Status Register (ISR) */
#define CSPI_INTR_ENABLE_REG    0x08U /* Interrupt Enable Register (IER) */
#define CSPI_INTR_DISABLE_REG   0x0CU /* Interrupt Disable Register (IDR) */
#define CSPI_INTR_MASK_REG      0x10U /* Interrupt Mask Register (IMR) */
#define CSPI_ENABLE_REG         0x14U /* SPI Enable/Disable Register (ER) */
#define CSPI_DELAY_REG          0x18U /* Delay Register (DR) */
#define CSPI_TX_DATA_REG        0x1CU /* Data Transmit Register (TXD) */
#define CSPI_RX_DATA_REG        0x20U /* Data Receive Register (RXD) */
#define CSPI_SLAVE_IDLE_COUNT   0x24U /* Slave Idle Count Register (SICR) */
#define CSPI_TX_THRES_REG       0x28U /* Transmit FIFO Watermark Register (TXWR) */
#define CSPI_RX_THRES_REG       0x2CU /* Receive FIFO Watermark Register (RXWR) */

/* Control Register (CR) Bits */
#define CSPI_CTRL_MSTREN_MASK   0x00000001U /* Master Mode Enable */
#define CSPI_CTRL_CPOL_MASK     0x00000002U /* Clock Polarity */
#define CSPI_CTRL_CPHA_MASK     0x00000004U /* Clock Phase */
#define CSPI_CTRL_PRESC_MASK    0x00000038U /* Prescaler divisor setting */
#define CSPI_CTRL_SSDECEN_MASK  0x00000200U /* Slave Select Decode Enable */
#define CSPI_CTRL_SSCTRL_MASK   0x00003C00U /* Slave Select Decode field */
#define CSPI_CTRL_SSFORCE_MASK  0x00004000U /* Force Slave Select (Manual CS) */
#define CSPI_CTRL_MANSTRTEN_VAL 0x00008000U /* Manual Transmission Start Enable */
#define CSPI_CTRL_MANSTRT_VAL   0x00010000U /* Manual Transmission Start Trigger */

/* Interrupt Status Register (ISR) Flags */
#define CSPI_ISR_TX_FULL_MASK   0x00000008U /* Tx FIFO Full */
#define CSPI_ISR_RX_NEMPTY_MASK 0x00000010U /* Rx FIFO Not Empty */

int cadence_spi_init(uint32_t base, uint32_t speed_hz, uint32_t input_clock_hz);
int cadence_spi_transfer(uint32_t base, const uint8_t *tx_buf, uint8_t *rx_buf, int len);

#endif /* CADENCE_SPI_LOW_H */
