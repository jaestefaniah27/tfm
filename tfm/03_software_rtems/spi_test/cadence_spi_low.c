#include "cadence_spi_low.h"
#include <stdint.h>
#include <stddef.h>
#include <unistd.h>
#include <stdio.h>

static volatile uint32_t *spi_reg_base = NULL;

static inline uint32_t read_reg(uint32_t offset) {
  return *(volatile uint32_t *)((uintptr_t)spi_reg_base + offset);
}

static inline void write_reg(uint32_t offset, uint32_t value) {
  *(volatile uint32_t *)((uintptr_t)spi_reg_base + offset) = value;
}

int cadence_spi_init(uint32_t base, uint32_t speed_hz, uint32_t input_clock_hz) {
  /* En RTEMS accedemos directamente a la memoria física mapeada */
  spi_reg_base = (volatile uint32_t *)(uintptr_t)base;

  /* 1. Deshabilitar el controlador SPI antes de configurarlo */
  write_reg(CSPI_ENABLE_REG, 0);

  /* 2. Deshabilitar todas las interrupciones */
  write_reg(CSPI_INTR_DISABLE_REG, 0xFFFFFFFF);

  /* 3. Limpiar cualquier flag de estado residual en ISR */
  write_reg(CSPI_INTR_STATUS_REG, 0xFFFFFFFF);

  /* 4. Calcular el divisor del prescaler para la frecuencia de reloj.
   * La fórmula es divisor = 2^(prescaler + 1)
   * Los valores van de 0 a 7 (divisores de 4 a 512).
   */
  uint32_t prescaler = 0;
  uint32_t divisor = 4;
  while (prescaler < 7 && divisor < (input_clock_hz / speed_hz)) {
    prescaler++;
    divisor <<= 1;
  }

  /* 5. Configurar el Registro de Control (CR):
   * - CPOL = 0, CPHA = 0 (SPI Mode 0 para ADS7950)
   * - Prescaler = prescaler (desplazado 3 bits)
   * - Master Mode Enable = 1
   * - SSFORCE = 1 (habilitar el chip select manual forzado)
   * - SSCTRL = 0xF << 10 (inicialmente deseleccionar todos los CS)
   */
  uint32_t ctrl_reg = CSPI_CTRL_MSTREN_MASK | 
                      (prescaler << 3) | 
                      (0x0FU << 10) | 
                      CSPI_CTRL_SSFORCE_MASK;
  
  write_reg(CSPI_CONTROL_REG, ctrl_reg);

  /* 6. Habilitar de nuevo el controlador SPI */
  write_reg(CSPI_ENABLE_REG, 1);

  return 0;
}

int cadence_spi_transfer(uint32_t base, const uint8_t *tx_buf, uint8_t *rx_buf, int len) {
  (void)base;

  if (!spi_reg_base || !tx_buf || !rx_buf || len <= 0) {
    return -1;
  }

  /* 1. Limpiar cualquier dato antiguo del RX FIFO */
  while (read_reg(CSPI_INTR_STATUS_REG) & CSPI_ISR_RX_NEMPTY_MASK) {
    (void)read_reg(CSPI_RX_DATA_REG);
  }

  /* 2. Limpiar flags de estado en ISR */
  write_reg(CSPI_INTR_STATUS_REG, 0xFFFFFFFF);

  /* 3. Seleccionar CS0 (0xE) de forma manual mediante SSCTRL en CR */
  uint32_t ctrl = read_reg(CSPI_CONTROL_REG);
  ctrl &= ~CSPI_CTRL_SSCTRL_MASK;   /* Limpiar selección de CS */
  ctrl |= (0x0EU << 10);            /* Seleccionar CS0 (0x0E) */
  ctrl |= CSPI_CTRL_SSFORCE_MASK;   /* Forzar CS bajo */
  write_reg(CSPI_CONTROL_REG, ctrl);

  /* 4. Bucle full-duplex en lockstep de transmisión y recepción */
  int written = 0;
  int read_count = 0;

  while (read_count < len) {
    /* Escribir un byte si hay datos por mandar y el TX FIFO no está lleno */
    if (written < len && !(read_reg(CSPI_INTR_STATUS_REG) & CSPI_ISR_TX_FULL_MASK)) {
      write_reg(CSPI_TX_DATA_REG, tx_buf[written++]);
    }

    /* Leer un byte si el RX FIFO no está vacío */
    if (read_reg(CSPI_INTR_STATUS_REG) & CSPI_ISR_RX_NEMPTY_MASK) {
      rx_buf[read_count++] = (uint8_t)read_reg(CSPI_RX_DATA_REG);
    }
  }

  /* 5. Deseleccionar el chip select (poner SSCTRL a 0xF) */
  ctrl = read_reg(CSPI_CONTROL_REG);
  ctrl &= ~CSPI_CTRL_SSCTRL_MASK;   /* Limpiar selección */
  ctrl |= (0x0FU << 10);            /* Deseleccionar todos los CS (0x0F) */
  write_reg(CSPI_CONTROL_REG, ctrl);

  return 0;
}
