/*
 * Receptor serie por PL (FIFO) usando AXI GPIO (RTEMS, ZynqMP)
 *  - axi_gpio_0 (canal 1, 8b)  -> DATA_OUT[7:0]  (PS lo lee)
 *  - axi_gpio_1 (canal 1, 1b)  -> EMPTY (1=vacío) (PS lo lee)
 *  - axi_gpio_2 (canal 1, 1b)  -> DATA_READ (PS lo escribe: 1->consume)
 *
 * Vivado: configurar direcciones de los GPIO y el ancho de datos como indicas.
 */

#include <rtems.h>
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>  
#include <inttypes.h>

/* Direcciones (Address Editor) */
#define GPIO0_BASE   0xA0000000u   /* axi_gpio_0: SERIAL_CONFIG[31:0] (out) */
#define GPIO1_BASE   0xA0010000u   /* axi_gpio_1: Data_read y ERROR_OK [1:0] (out)   */
#define GPIO2_BASE   0xA0020000u   /* axi_gpio_2: Data_in y Send_data [9:0] (out) */
#define GPIO3_BASE   0xA0030000u   /* axi_gpio_3: PS_out [14:0] (in) */

/* ==== Selección de canal (descomenta si tus señales están en canal 2) ==== */
// #define USE_CH2_GPIO0   /* DATA_OUT por canal 2 (offset 0x08) */
// #define USE_CH2_GPIO1   /* EMPTY por canal 2 (offset 0x08) */
// #define USE_CH2_GPIO2   /* DATA_READ por canal 2 (offset 0x0C para TRI, 0x08 para DATA) */

#ifdef USE_CH2_GPIO0
  #define GPIO0_DATA_OFF 0x08u
#else
  #define GPIO0_DATA_OFF 0x00u
#endif

#ifdef USE_CH2_GPIO1
  #define GPIO1_DATA_OFF 0x08u
#else
  #define GPIO1_DATA_OFF 0x00u
#endif

#ifdef USE_CH2_GPIO2
  #define GPIO2_DATA_OFF 0x08u
#else
  #define GPIO2_DATA_OFF 0x00u
#endif

#ifdef USE_CH2_GPIO3
  #define GPIO3_DATA_OFF 0x08u
#else
  #define GPIO3_DATA_OFF 0x00u
#endif
//#define GPIO0_DATA_OFF 0x00u  /* offset del canal 1 (canal 0 es TRI) */
//#define GPIO1_DATA_OFF 0x00u
//#define GPIO2_DATA_OFF 0x00u
//#define GPIO3_DATA_OFF 0x00u
/* GPIO3 es solo lectura, sin offset de canal */

/* Máscaras para transceptor */
/* === Masks / shifts según tu VHDL === */
/* PS_OUT (GPIO3) bits:
 *   bit 14 -> Ack_in
 *   bit 13 -> TX_RDY
 *   bit 12 -> FRAME_ERROR
 *   bit 11 -> PAR_ERROR
 *   bit 10 -> FULL
 *   bit  9 -> EMPTY
 *   bits 8:0 -> Data_out (9 bits)
 */
#define PS_OUT_ACK_IN_MASK   0x4000u   /* 1 << 14 */
#define PS_OUT_TX_RDY_MASK   0x2000u   /* 1 << 13 */
#define PS_OUT_FRAME_ERR_MASK 0x1000u  /* 1 << 12 */
#define PS_OUT_PAR_ERR_MASK   0x0800u  /* 1 << 11 */
#define PS_OUT_FULL_MASK      0x0400u  /* 1 << 10 */
#define PS_OUT_EMPTY_MASK     0x0200u  /* 1 << 9  */
#define PS_OUT_DATA_MASK      0x01FFu  /* bits [8:0] */

/* GPIO1: PS_RX_DataRead_ErrorOk [1:0] (PS writes DATA_READ bit0 to consume; ERROR_OK bit1 readable) */
#define GPIO1_DATA_READ_MASK  0x1u     /* bit 0 */
#define GPIO1_ERROR_OK_MASK   0x2u     /* bit 1 */

/* GPIO2: PS_TX_DataIn_Send [9:0] (write Data_in bits[8:0] and TX_Send bit9) */
#define GPIO2_DATA_IN_MASK    0x01FFu  /* bits [8:0] */
#define GPIO2_TX_SEND_MASK    0x0200u  /* bit 9 */

/* SERIAL_CONFIG (GPIO0) masks (por si luego quieres leer/configurar) */
#define SERIAL_BAUD_MASK      0x003FFFFFu  /* bits [21:0] */
#define SERIAL_STOP_MASK      0x01C00000u  /* bits [24:22] */
#define SERIAL_PARITY_MASK    0x0E000000u  /* bits [27:25] */
#define SERIAL_DATA_BITS_MASK 0x70000000u  /* bits [30:28] */
#define SERIAL_BIT_ORDER_MASK 0x80000000u  /* bit 31 */

void mmu_map_pl_axi_early(void);

/* === MMIO helpers con barrera (ARM/AXI) === */
static inline void mmio_write32(uintptr_t a, uint32_t v) {
  *(volatile uint32_t *)a = v;
  __asm__ volatile("dmb sy" ::: "memory");
}
static inline uint32_t mmio_read32(uintptr_t a) {
  __asm__ volatile("dmb sy" ::: "memory");
  return *(volatile uint32_t *)a;
}

/* === Lectura de PS_OUT (GPIO3) y extracción de campos === */
static inline uint32_t ps_out_read_raw(void) {
  return mmio_read32(GPIO3_BASE + GPIO3_DATA_OFF);
}

static inline uint16_t ps_out_get_data_out(uint32_t raw) {
  return (uint16_t)(raw & PS_OUT_DATA_MASK); /* 9 bits */
}
static inline int ps_out_is_empty(uint32_t raw) {
  return (raw & PS_OUT_EMPTY_MASK) ? 1 : 0; /* 1 = vacío según tu comentario */
}
static inline int ps_out_is_full(uint32_t raw) {
  return (raw & PS_OUT_FULL_MASK) ? 1 : 0;
}
static inline int ps_out_tx_rdy(uint32_t raw) {
  return (raw & PS_OUT_TX_RDY_MASK) ? 1 : 0;
}
static inline int ps_out_frame_err(uint32_t raw) {
  return (raw & PS_OUT_FRAME_ERR_MASK) ? 1 : 0;
}
static inline int ps_out_par_err(uint32_t raw) {
  return (raw & PS_OUT_PAR_ERR_MASK) ? 1 : 0;
}
static inline int ps_out_ack_in(uint32_t raw) {
  return (raw & PS_OUT_ACK_IN_MASK) ? 1 : 0;
}

/* === Consumir FIFO: escribir DATA_READ=1 luego 0 en GPIO1 (bit0) ===
   Usamos RMW para preservar otros bits en GPIO1 (por si ERROR_OK u otros) */
static inline void gpio1_write_field_rmw(uint32_t mask, uint32_t value_shifted) {
  uintptr_t addr = GPIO1_BASE + GPIO1_DATA_OFF;
  uint32_t v = mmio_read32(addr);
  v &= ~mask;
  v |= value_shifted & mask;
  mmio_write32(addr, v);
}

/* Pulso de consumo (DATA_READ = 1 -> small delay -> 0) */
static inline void fifo_consume_pulse(void) {
  /* set DATA_READ = 1 (bit0) */
  gpio1_write_field_rmw(GPIO1_DATA_READ_MASK, GPIO1_DATA_READ_MASK);
  /* breve espera */
  for (volatile int i = 0; i < 100; ++i) __asm__ volatile("nop");
  /* clear DATA_READ = 0 */
  gpio1_write_field_rmw(GPIO1_DATA_READ_MASK, 0u);
}

/* === Lectura de ERROR_OK desde GPIO1 (bit1) === */
static inline int gpio1_get_error_ok(void) {
  uint32_t v = mmio_read32(GPIO1_BASE + GPIO1_DATA_OFF);
  return (v & GPIO1_ERROR_OK_MASK) ? 1 : 0;
}

/* === Funciones TX (si luego quieres probar TX) === */
static inline void gpio2_write_field_rmw(uint32_t mask, uint32_t value_shifted) {
  uintptr_t addr = GPIO2_BASE + GPIO2_DATA_OFF;
  uint32_t v = mmio_read32(addr);
  v &= ~mask;
  v |= value_shifted & mask;
  mmio_write32(addr, v);
}

/* Escribe data_in (9 bits) y hace pulso TX_Send si quieres enviar */
static inline void tx_write_data_and_send(uint16_t data9) {
  /* escribir DATA_IN (bits [8:0]) */
  gpio2_write_field_rmw(GPIO2_DATA_IN_MASK, (uint32_t)(data9 & GPIO2_DATA_IN_MASK));
  /* pulso TX_SEND (bit9) */
  gpio2_write_field_rmw(GPIO2_TX_SEND_MASK, GPIO2_TX_SEND_MASK);
  for (volatile int i = 0; i < 100; ++i) __asm__ volatile("nop");
  gpio2_write_field_rmw(GPIO2_TX_SEND_MASK, 0u);
}

/* === Init minimal y correcto: solo receptor, imprime lo que llega desde PS_OUT DATA_OUT === */
rtems_task Init(rtems_task_argument arg) {

  mmu_map_pl_axi_early();
  
  printf("=== RX TEST: usando campos correctos según tu VHDL ===\n");
  printf("GPIO0 SERIAL_CONFIG @%08" PRIxPTR "\n", (uintptr_t)(GPIO0_BASE + GPIO0_DATA_OFF));
  printf("GPIO1 RX_CTRL       @%08" PRIxPTR "\n", (uintptr_t)(GPIO1_BASE + GPIO1_DATA_OFF));
  printf("GPIO2 TX_CTRL       @%08" PRIxPTR "\n", (uintptr_t)(GPIO2_BASE + GPIO2_DATA_OFF));
  printf("GPIO3 PS_OUT        @%08" PRIxPTR "\n", (uintptr_t)(GPIO3_BASE + GPIO3_DATA_OFF));
  printf("Esperando datos en PS_OUT.Data_out [bits 8:0] (EMPTY = bit9)\n");
  uint32_t serial_cfg =
    (0u << 31)        |   // bit_order = 0
    (3u << 28)        |   // data_bits = 3 (8 bits)
    (4u << 25)        |   // parity = 4 (none)
    (2u << 22)        |   // stop_bits = 2
    (0x1C200u);           // baudrate = 115200 decimal

  mmio_write32(GPIO0_BASE + GPIO0_DATA_OFF, serial_cfg);

  /* Imprime una vez el raw de los registros para diagnóstico inicial */
  uint32_t raw0 = mmio_read32(GPIO0_BASE + GPIO0_DATA_OFF);
  printf("RAW GPIO0: 0x%08x\n", raw0);
  uint32_t raw1 = mmio_read32(GPIO1_BASE + GPIO1_DATA_OFF);
  printf("RAW GPIO1: 0x%08x\n", raw1);
  uint32_t raw2 = mmio_read32(GPIO2_BASE + GPIO2_DATA_OFF);
  printf("RAW GPIO2: 0x%08x\n", raw2);
  uint32_t raw3 = mmio_read32(GPIO3_BASE + GPIO3_DATA_OFF);
  printf("RAW GPIO3: 0x%08x\n", raw3);


  /* Bucle simple: cuando EMPTY==0 (hay datos) leemos DATA_OUT y generamos pulso DATA_READ */
  for (;;) {
    uint32_t psout = ps_out_read_raw();

    if (ps_out_is_empty(psout)) {
      /* vacío: dormir un poco y volver a comprobar */
      rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(1));
      continue;
    }

    /* hay datos: leer campo Data_out (9 bits) */
    uint16_t data = ps_out_get_data_out(psout) & 0x1FFu; /* nos quedamos con 8 LSB para byte */
    /* imprimir */
    printf("RX byte: 0x%02x ('%c') [raw data 0x%03x] — PS_OUT raw 0x%04x\n",
           (unsigned)data,
           (data >= 32 && data < 127) ? (char)data : '.',
           (unsigned)(ps_out_get_data_out(psout)),
           (unsigned)psout);
    fflush(stdout);

    /* consumir: pulso DATA_READ en GPIO1 */
    fifo_consume_pulse();

    /* pequeña espera para no monopolizar CPU */
    //rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(1));
  }
}

