#include "transceiver.h"
#include <rtems.h>   /* para rtems_task_wake_after en send_bytes */
#include <stdio.h>
#include <string.h>
#include <inttypes.h>

/* MMIO helpers */
void mmio_write32(uintptr_t a, uint32_t v) {
  *(volatile uint32_t *)a = v;
  __asm__ volatile("dmb sy" ::: "memory");
}
uint32_t mmio_read32(uintptr_t a) {
  __asm__ volatile("dmb sy" ::: "memory");
  return *(volatile uint32_t *)a;
}

/* ---- GPIO helpers (lectura/escritura por campos) ---- */
uint32_t gpio0_read_raw(void) {
  return mmio_read32(GPIO0_BASE + GPIO0_DATA_OFF);
}
void gpio0_write_raw(uint32_t v) {
  mmio_write32(GPIO0_BASE + GPIO0_DATA_OFF, v);
  __asm__ volatile("dmb sy" ::: "memory");
}
uint32_t gpio1_read_raw(void) {
  return mmio_read32(GPIO1_BASE + GPIO1_DATA_OFF);
}
uint32_t gpio2_read_raw(void) {
  return mmio_read32(GPIO2_BASE + GPIO2_DATA_OFF);
}
uint32_t gpio3_read_raw(void) {
  return mmio_read32(GPIO3_BASE + GPIO3_DATA_OFF);
}

/* RMW helpers */
void gpio1_write_rmw(uint32_t mask, uint32_t value_masked) {
  uintptr_t addr = GPIO1_BASE + GPIO1_DATA_OFF;
  uint32_t v = mmio_read32(addr);
  v &= ~mask;
  v |= (value_masked & mask);
  mmio_write32(addr, v);
  __asm__ volatile("dmb sy" ::: "memory");
}
void gpio2_write_rmw(uint32_t mask, uint32_t value_masked) {
  uintptr_t addr = GPIO2_BASE + GPIO2_DATA_OFF;
  uint32_t v = mmio_read32(addr);
  v &= ~mask;
  v |= (value_masked & mask);
  mmio_write32(addr, v);
  __asm__ volatile("dmb sy" ::: "memory");
}
void gpio0_write_field(uint32_t mask, unsigned shift, uint32_t val) {
  uint32_t v = gpio0_read_raw();
  v &= ~mask;
  v |= ((val << shift) & mask);
  gpio0_write_raw(v);
}

/* SERIAL getters/setters */
uint32_t serial_get_baudrate(void) { return gpio0_read_raw() & SERIAL_BAUD_MASK; }
uint32_t serial_get_stop_bits(void) { return (gpio0_read_raw() & SERIAL_STOP_MASK) >> 22; }
uint32_t serial_get_parity(void) { return (gpio0_read_raw() & SERIAL_PARITY_MASK) >> 25; }
uint32_t serial_get_data_bits(void) { return (gpio0_read_raw() & SERIAL_DATA_BITS_MASK) >> 28; }
uint32_t serial_get_bit_order(void) { return (gpio0_read_raw() & SERIAL_BIT_ORDER_MASK) ? 1u : 0u; }

void serial_set_baudrate(uint32_t br) { gpio0_write_field(SERIAL_BAUD_MASK, 0u, br & 0x3FFFFFu); }
void serial_set_stop_bits(uint32_t sb) { gpio0_write_field(SERIAL_STOP_MASK, 22u, sb & 0x7u); }
void serial_set_parity(uint32_t p) { gpio0_write_field(SERIAL_PARITY_MASK, 25u, p & 0x7u); }
void serial_set_data_bits(uint32_t db) { gpio0_write_field(SERIAL_DATA_BITS_MASK, 28u, db & 0x7u); }
void serial_set_bit_order(uint32_t bo) { gpio0_write_field(SERIAL_BIT_ORDER_MASK, 31u, bo & 0x1u); }

/* TX helper: pulse TX_SEND in GPIO2 (RMW) */
void tx_write_data_and_send(uint16_t data9) {
  gpio2_write_rmw(GPIO2_DATA_IN_MASK, (uint32_t)(data9 & GPIO2_DATA_IN_MASK));
  /* pulse TX_SEND (bit 9) */
  gpio2_write_rmw(GPIO2_TX_SEND_MASK, GPIO2_TX_SEND_MASK);
  for (volatile int i = 0; i < 200; ++i) __asm__ volatile("nop");
  gpio2_write_rmw(GPIO2_TX_SEND_MASK, 0u);
}

/* DATA_READ pulse on GPIO1 */
void fifo_consume_pulse(void) {
  gpio1_write_rmw(GPIO1_DATA_READ_MASK, GPIO1_DATA_READ_MASK);
  for (volatile int i = 0; i < 200; ++i) __asm__ volatile("nop");
  gpio1_write_rmw(GPIO1_DATA_READ_MASK, 0u);
}

/* Field-style helpers */
void gpio1_write_data_read(uint32_t v)
{
    uint32_t reg = mmio_read32(GPIO1_BASE);
    reg &= ~0x1u;          // limpiar bit0
    reg |= (v & 0x1u);     // escribir nuevo valor
    mmio_write32(GPIO1_BASE, reg);
}

void gpio1_write_error_ok(uint32_t v)
{
    uint32_t reg = mmio_read32(GPIO1_BASE);
    reg &= ~0x2u;              // limpiar bit1
    reg |= ((v & 0x1u) << 1);  // escribir bit1
    mmio_write32(GPIO1_BASE, reg);
}
void gpio2_write_data_in(uint32_t v)
{
    v &= 0x1FFu;           // limitar a 9 bits
    uint32_t reg = mmio_read32(GPIO2_BASE);
    reg &= ~0x1FFu;        // limpiar bits 0–8
    reg |= v;              // escribir DATA_IN
    mmio_write32(GPIO2_BASE, reg);
}

void gpio2_write_tx_send(uint32_t v)
{
    uint32_t reg = mmio_read32(GPIO2_BASE);
    reg &= ~(1u << 9);         // limpiar bit9
    reg |= ((v & 0x1u) << 9);  // escribir TX_SEND
    mmio_write32(GPIO2_BASE, reg);
}

/* ---- Higher-level send_bytes ---- */
/* Devuelve 0 OK, -1 timeout */
int send_bytes(const uint8_t *buf, size_t len, uint32_t timeout_ms_per_byte)
{
  if (!buf || len == 0) return 0;

  for (size_t i = 0; i < len; ++i) {
    uint16_t data9 = (uint16_t)(buf[i] & GPIO2_DATA_IN_MASK);

    /* escribir DATA_IN (9 bits) */
    gpio2_write_rmw(GPIO2_DATA_IN_MASK, (uint32_t)data9);

    /* esperar a TX_RDY == 1 (GPIO3) */
    if (timeout_ms_per_byte == 0) {
      /* esperar indefinidamente (busy-wait corto) */
      while ((gpio3_read_raw() & PS_OUT_TX_RDY_MASK) == 0) {
        __asm__ volatile("nop");
      }
    } else {
      uint32_t waited = 0;
      const uint32_t step_ms = 1;
      while ((gpio3_read_raw() & PS_OUT_TX_RDY_MASK) == 0) {
        if (waited >= timeout_ms_per_byte) {
          return -1; /* timeout */
        }
        rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(step_ms));
        waited += step_ms;
      }
    }

    /* Pulso TX_SEND = 1 -> pequeña espera -> TX_SEND = 0 */
    gpio2_write_rmw(GPIO2_TX_SEND_MASK, GPIO2_TX_SEND_MASK);
    for (volatile int j = 0; j < 200; ++j) __asm__ volatile("nop");
    gpio2_write_rmw(GPIO2_TX_SEND_MASK, 0u);

    /* opcional: dar una pequeña pausa para asegurar que el HW capture el pulso */
    for (volatile int j = 0; j < 20; ++j) __asm__ volatile("nop");
  }

  return 0;
}

/* Envoltorio para strings C null-terminated (no envía el '\0') */
int send_string(const char *s, uint32_t timeout_ms_per_byte)
{
  if (!s) return -1;
  return send_bytes((const uint8_t *)s, strlen(s), timeout_ms_per_byte);
}
