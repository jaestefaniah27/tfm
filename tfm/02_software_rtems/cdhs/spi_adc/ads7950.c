#include "ads7950.h"
#include "cadence_spi_low.h"

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

static inline uint16_t ads7950_build_command(uint8_t channel)
{
  return (uint16_t)(0x1800u | ((uint16_t)(channel & 0x0Fu) << 7));
}

static int ads7950_transfer(ADS7950 *adc, uint8_t next_channel, uint16_t *response_word)
{
  uint16_t command = ads7950_build_command(next_channel);
  adc->tx_buf[0] = (uint8_t)(command >> 8);
  adc->tx_buf[1] = (uint8_t)command;

  if (cadence_spi_transfer(ADS7950_SPI_BASE, adc->tx_buf, adc->rx_buf, 2) != 0) {
    printf("ADS7950: cadence_spi_transfer failed\n");
    fflush(stdout);
    return -1;
  }

  *response_word = (uint16_t)adc->rx_buf[0] << 8 | adc->rx_buf[1];
  return 0;
}

int ADS7950_Init(ADS7950 *adc, const char *device, uint32_t speed_hz)
{
  (void)device;

  if (adc == NULL) {
    return -1;
  }

  if (cadence_spi_init(ADS7950_SPI_BASE, speed_hz, ADS7950_INPUT_CLOCK_HZ) != 0) {
    printf("ADS7950: cadence_spi_init failed\n");
    fflush(stdout);
    return -1;
  }

  adc->speed_hz = speed_hz;
  adc->tx_buf = (uint8_t *)malloc(2);
  adc->rx_buf = (uint8_t *)malloc(2);

  if (adc->tx_buf == NULL || adc->rx_buf == NULL) {
    printf("ADS7950: malloc failed\n");
    fflush(stdout);
    free(adc->tx_buf);
    free(adc->rx_buf);
    return -1;
  }

  return 0;
}

int ADS7950_ReadChannels(ADS7950 *adc, uint16_t values[ADS7950_NUM_CHANNELS])
{
  if (adc == NULL || values == NULL) {
    return -1;
  }

  const uint8_t sequence[6] = { 0, 1, 2, 3, 0, 1 };

  for (int i = 0; i < 6; i++) {
    uint16_t response;
    if (ads7950_transfer(adc, sequence[i], &response) < 0) {
      return -1;
    }

    if (i >= 2) {
      values[i - 2] = response & 0x0FFFu;
    }
  }

  return 0;
}

void ADS7950_Destroy(ADS7950 *adc)
{
  if (adc == NULL) {
    return;
  }
  
  if (adc->tx_buf != NULL) {
    free(adc->tx_buf);
    adc->tx_buf = NULL;
  }
  
  if (adc->rx_buf != NULL) {
    free(adc->rx_buf);
    adc->rx_buf = NULL;
  }
}
