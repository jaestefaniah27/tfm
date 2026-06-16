/* main.c
 * ADS7950 SPI test para RTEMS 7 en ZCU102.
 *
 * Lee continuamente los 4 canales del ADS7950 y los imprime por la consola.
 */

#include <rtems.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>

#include "ads7950.h"

#define ADS7950_PRINT_INTERVAL_MS 500

rtems_task Init(rtems_task_argument arg)
{
  (void)arg;

  ADS7950 adc = { .speed_hz = 0 };
  uint16_t values[ADS7950_NUM_CHANNELS];
  printf("RTEMS OK\n");
  printf("ADS7950 SPI test arrancando...\n");

  if (ADS7950_Init(&adc, ADS7950_SPI_DEVICE, ADS7950_DEFAULT_SPEED_HZ) != 0) {
    printf("ERROR: no se pudo inicializar ADS7950 en %s\n", ADS7950_SPI_DEVICE);
    rtems_task_delete(RTEMS_SELF);
    return;
  }

  printf("ADS7950 inicializado en %s a %u Hz\n", ADS7950_SPI_DEVICE, ADS7950_DEFAULT_SPEED_HZ);

  for (;;) {
    if (ADS7950_ReadChannels(&adc, values) != 0) {
      printf("ERROR: lectura SPI ADS7950 fallida\n");
    } else {
      printf("ADS7950: CH0=%4u  CH1=%4u  CH2=%4u  CH3=%4u\n",
             (unsigned)values[0],
             (unsigned)values[1],
             (unsigned)values[2],
             (unsigned)values[3]);
    }

    fflush(stdout);
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(ADS7950_PRINT_INTERVAL_MS));
  }

  ADS7950_Destroy(&adc);
  rtems_task_delete(RTEMS_SELF);
}
