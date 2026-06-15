#ifndef TRANSCEIVER_H
#define TRANSCEIVER_H

#include <stdint.h>
#include <stddef.h>

/* === Bases (ajusta si hace falta) === */
#define GPIO0_BASE   0xA0000000u   /* SERIAL_CONFIG */
#define GPIO1_BASE   0xA0010000u   /* PS_RX_DataRead_ErrorOk */
#define GPIO2_BASE   0xA0020000u   /* PS_TX_DataIn_Send */
#define GPIO3_BASE   0xA0030000u   /* PS_OUT */

/* Offsets canal 1 (si usas channel 2, cambiar a 0x08) */
#define GPIO0_DATA_OFF 0x00u
#define GPIO1_DATA_OFF 0x00u
#define GPIO2_DATA_OFF 0x00u
#define GPIO3_DATA_OFF 0x00u

/* Masks */
#define PS_OUT_TX_RDY_MASK   0x2000u
#define PS_OUT_FRAME_ERR_MASK 0x1000u
#define PS_OUT_PAR_ERR_MASK   0x0800u
#define PS_OUT_FULL_MASK      0x0400u
#define PS_OUT_EMPTY_MASK     0x0200u
#define PS_OUT_DATA_MASK      0x01FFu

#define GPIO1_DATA_READ_MASK  0x1u
#define GPIO1_ERROR_OK_MASK   0x2u

#define GPIO2_DATA_IN_MASK    0x01FFu
#define GPIO2_TX_SEND_MASK    0x0200u

/* SERIAL_CONFIG masks */
#define SERIAL_BAUD_MASK      0x003FFFFFu
#define SERIAL_STOP_MASK      0x01C00000u
#define SERIAL_PARITY_MASK    0x0E000000u
#define SERIAL_DATA_BITS_MASK 0x70000000u
#define SERIAL_BIT_ORDER_MASK 0x80000000u

/* Prototipos: mmio y helpers */
void mmu_map_pl_axi_early(void); /* prototipo que sigue en tu Init */

/* MMIO */
void mmio_write32(uintptr_t a, uint32_t v);
uint32_t mmio_read32(uintptr_t a);

/* GPIO raw access */
uint32_t gpio0_read_raw(void);
void     gpio0_write_raw(uint32_t v);
uint32_t gpio1_read_raw(void);
uint32_t gpio2_read_raw(void);
uint32_t gpio3_read_raw(void);

/* RMW helpers */
void gpio1_write_rmw(uint32_t mask, uint32_t value_masked);
void gpio2_write_rmw(uint32_t mask, uint32_t value_masked);
void gpio0_write_field(uint32_t mask, unsigned shift, uint32_t val);

/* Field helpers convenient (previous inline ones) */
void gpio1_write_data_read(uint32_t v);
void gpio1_write_error_ok(uint32_t v);
void gpio2_write_data_in(uint32_t v);
void gpio2_write_tx_send(uint32_t v);

/* SERIAL getters/setters */
uint32_t serial_get_baudrate(void);
uint32_t serial_get_stop_bits(void);
uint32_t serial_get_parity(void);
uint32_t serial_get_data_bits(void);
uint32_t serial_get_bit_order(void);

void serial_set_baudrate(uint32_t br);
void serial_set_stop_bits(uint32_t sb);
void serial_set_parity(uint32_t p);
void serial_set_data_bits(uint32_t db);
void serial_set_bit_order(uint32_t bo);

/* TX helper */
void tx_write_data_and_send(uint16_t data9);

/* FIFO consume pulse */
void fifo_consume_pulse(void);

/* Higher-level send (envía varios bytes) */
/* devuelve 0 si OK, -1 si timeout en algún byte */
int send_bytes(const uint8_t *buf, size_t len, uint32_t timeout_ms_per_byte);
/* wrapper para cadenas C (no envía el '\0') */
int send_string(const char *s, uint32_t timeout_ms_per_byte);

#endif /* TRANSCEIVER_H */
