#ifndef ADS7950_H
#define ADS7950_H

#include <stdint.h>

#define ADS7950_SPI_DEVICE "/dev/spi0"
#define ADS7950_SPI_BASE 0xFF040000u
#define ADS7950_SPI_IRQ 19
#define ADS7950_INPUT_CLOCK_HZ 100000000u
#define ADS7950_DEFAULT_SPEED_HZ 500000u
#define ADS7950_NUM_CHANNELS 4

typedef struct {
  uint32_t speed_hz;
  uint8_t *tx_buf;  /* malloc'd for DMA alignment */
  uint8_t *rx_buf;  /* malloc'd for DMA alignment */
} ADS7950;

int ADS7950_Init(ADS7950 *adc, const char *device, uint32_t speed_hz);
int ADS7950_ReadChannels(ADS7950 *adc, uint16_t values[ADS7950_NUM_CHANNELS]);
void ADS7950_Destroy(ADS7950 *adc);

#endif /* ADS7950_H */
