/*
 * main.c
 * Sistema Multi-Transceptor sobre RTEMS.
 *
 * Funcionalidad:
 * 1. Inicializa transceptores en paralelo (Base 0xA0000000).
 * 2. RX: Muestra por consola lo que llega, indicando de qué UART vino.
 * 3. TX: Permite enviar mensajes a una UART específica desde la consola USB.
 */

#include <rtems.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "transceiver.h"

/* Direcciones base para periféricos en PS (ZynqMP) */
#define SPI0_BASE 0xFF040000
#define CAN0_BASE 0xFF060000
#define CAN1_BASE 0xFF070000

/* Registros AXI SPI */
#define SPI_SRR   (SPI0_BASE + 0x40)  /* Software Reset */
#define SPI_SPICR (SPI0_BASE + 0x60)  /* Control */
#define SPI_SPISR (SPI0_BASE + 0x64)  /* Status */
#define SPI_SPIDTR (SPI0_BASE + 0x68) /* Data Transmit */
#define SPI_SPIDRR (SPI0_BASE + 0x6C) /* Data Receive */
#define SPI_SPISSR (SPI0_BASE + 0x70) /* Slave Select */

/* Registros AXI CAN */
#define CAN_SRR   (CAN0_BASE + 0x00)  /* Software Reset */
#define CAN_MSR   (CAN0_BASE + 0x04)  /* Mode Select */
#define CAN_BRPR  (CAN0_BASE + 0x08)  /* Baud Rate Prescaler */
#define CAN_BTR   (CAN0_BASE + 0x0C)  /* Bit Timing */
#define CAN_ECR   (CAN0_BASE + 0x10)  /* Error Counter */
#define CAN_ESR   (CAN0_BASE + 0x14)  /* Error Status */
#define CAN_SR    (CAN0_BASE + 0x18)  /* Status */
#define CAN_ISR   (CAN0_BASE + 0x1C)  /* Interrupt Status */
#define CAN_IER   (CAN0_BASE + 0x20)  /* Interrupt Enable */
#define CAN_ICR   (CAN0_BASE + 0x24)  /* Interrupt Clear */
#define CAN_TXFIFO_ID (CAN0_BASE + 0x30) /* TX FIFO ID */
#define CAN_TXFIFO_DLC (CAN0_BASE + 0x34) /* TX FIFO DLC */
#define CAN_TXFIFO_DATA1 (CAN0_BASE + 0x38) /* TX FIFO Data 1 */
#define CAN_TXFIFO_DATA2 (CAN0_BASE + 0x3C) /* TX FIFO Data 2 */
#define CAN_RXFIFO_ID (CAN0_BASE + 0x50) /* RX FIFO ID */
#define CAN_RXFIFO_DLC (CAN0_BASE + 0x54) /* RX FIFO DLC */
#define CAN_RXFIFO_DATA1 (CAN0_BASE + 0x58) /* RX FIFO Data 1 */
#define CAN_RXFIFO_DATA2 (CAN0_BASE + 0x5C) /* RX FIFO Data 2 */

/* Similar para CAN1 */
#define CAN1_SRR   (CAN1_BASE + 0x00)
#define CAN1_MSR   (CAN1_BASE + 0x04)
#define CAN1_BRPR  (CAN1_BASE + 0x08)
#define CAN1_BTR   (CAN1_BASE + 0x0C)
#define CAN1_ECR   (CAN1_BASE + 0x10)
#define CAN1_ESR   (CAN1_BASE + 0x14)
#define CAN1_SR    (CAN1_BASE + 0x18)
#define CAN1_ISR   (CAN1_BASE + 0x1C)
#define CAN1_IER   (CAN1_BASE + 0x20)
#define CAN1_ICR   (CAN1_BASE + 0x24)
#define CAN1_TXFIFO_ID (CAN1_BASE + 0x30)
#define CAN1_TXFIFO_DLC (CAN1_BASE + 0x34)
#define CAN1_TXFIFO_DATA1 (CAN1_BASE + 0x38)
#define CAN1_TXFIFO_DATA2 (CAN1_BASE + 0x3C)
#define CAN1_RXFIFO_ID (CAN1_BASE + 0x50)
#define CAN1_RXFIFO_DLC (CAN1_BASE + 0x54)
#define CAN1_RXFIFO_DATA1 (CAN1_BASE + 0x58)
#define CAN1_RXFIFO_DATA2 (CAN1_BASE + 0x5C)

/* Objeto global para los transceptores */
static uint32_t num_transceivers;
static Transceiver uarts[MAX_TRANSCEIVERS];

/* Configuración común para todos (115200 8N1) */
static const Transceiver_Config_t cfg = {
    .baud = TRANSCEIVER_BAUD_115200, 
    .data_bits = TRANSCEIVER_DATA_BITS_8, 
    .parity = TRANSCEIVER_PARITY_NONE, 
    .stop_bits = TRANSCEIVER_STOP_BITS_1, 
    .bit_order = TRANSCEIVER_BIT_ORDER_DEFAULT,
    .slo_mode = TRANSCEIVER_SLO_DEFAULT
};

/* Configuración común para SLO ON (115200 8N1) */
static const Transceiver_Config_t cfg_slo_on = {
    .baud = TRANSCEIVER_BAUD_115200, 
    .data_bits = TRANSCEIVER_DATA_BITS_8, 
    .parity = TRANSCEIVER_PARITY_NONE, 
    .stop_bits = TRANSCEIVER_STOP_BITS_1, 
    .bit_order = TRANSCEIVER_BIT_ORDER_DEFAULT,
    .slo_mode = TRANSCEIVER_SLO_ON
};

/* Configuración común para SLO OFF (115200 8N1) */
static const Transceiver_Config_t cfg_slo_off = {
    .baud = TRANSCEIVER_BAUD_115200, 
    .data_bits = TRANSCEIVER_DATA_BITS_8, 
    .parity = TRANSCEIVER_PARITY_NONE, 
    .stop_bits = TRANSCEIVER_STOP_BITS_1, 
    .bit_order = TRANSCEIVER_BIT_ORDER_DEFAULT,
    .slo_mode = TRANSCEIVER_SLO_OFF
};
/* =========================================================================
 * 1. CALLBACK DE RECEPCIÓN (Se ejecuta cuando llega algo a CUALQUIER UART)
 * ========================================================================= */
/* Añadir esto al principio de main.c, junto a los otros defines */
#define APP_LINE_BUF_SIZE 1024

/* Estructura para gestionar el buffer de cada canal independientemente */
typedef struct {
    char buf[APP_LINE_BUF_SIZE];
    size_t idx;
} AppLineBuffer;

/* Array estático para guardar el estado de los 14 canales */
static AppLineBuffer rx_lines[MAX_TRANSCEIVERS]; 

/* Funciones para testing SPI y CAN */
static inline uint32_t read_reg(uintptr_t addr) {
    return *(volatile uint32_t *)addr;
}

static inline void write_reg(uintptr_t addr, uint32_t val) {
    *(volatile uint32_t *)addr = val;
}

void spi_init(void) {
    // Reset SPI
    write_reg(SPI_SRR, 0x0000000A);
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(1));

    // Configure SPI: Master, CPOL=0, CPHA=0, LSB first, etc.
    uint32_t spicr = (1 << 1) | (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5); // SPE, MSTR, CPOL=0, CPHA=0, TXFIFO_RST, RXFIFO_RST
    write_reg(SPI_SPICR, spicr);

    // Slave select
    write_reg(SPI_SPISSR, 0xFFFFFFFE); // Select slave 0
}

uint16_t spi_transfer(uint16_t data) {
    // Wait for TX FIFO empty
    while ((read_reg(SPI_SPISR) & (1 << 2)) == 0);

    // Send data
    write_reg(SPI_SPIDTR, data);

    // Wait for RX FIFO not empty
    while ((read_reg(SPI_SPISR) & (1 << 0)) == 0);

    // Read data
    return read_reg(SPI_SPIDRR);
}

void test_spi(void) {
    printf("Testing SPI with ADS7950QDBTRQ1 (Temperature ADC)...\n");
    spi_init();

    // ADS7950 command: Manual mode, channel 0, 12-bit
    uint16_t cmd = 0x1000 | (0 << 12) | (0 << 10) | (1 << 9); // Manual, CH0, 12-bit
    uint16_t response = spi_transfer(cmd);
    printf("SPI Command Response: 0x%04X\n", response);

    // Read conversion (temperature value)
    response = spi_transfer(0x0000);
    uint16_t adc_value = response & 0x0FFF;
    printf("ADC Value: %d (0x%03X)\n", adc_value, adc_value);

    // Assuming linear conversion: 0-4095 -> 0-100°C (example)
    float temperature = (adc_value / 4095.0) * 100.0;
    printf("Estimated Temperature: %.2f °C\n", temperature);
}

void can_init(uintptr_t base) {
    // Reset CAN
    write_reg(base + 0x00, 0x00000001);
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(1));

    // Set mode to Configuration
    write_reg(base + 0x04, 0x00000004);

    // Set baud rate: Assume 1Mbps, prescaler 5, etc.
    write_reg(base + 0x08, 5); // BRPR
    write_reg(base + 0x0C, 0x00002301); // BTR: SJW=1, TS2=3, TS1=2, BRP=1

    // Set mode to Normal with Loopback
    write_reg(base + 0x04, 0x00000002); // Loopback mode
}

void can_send(uintptr_t base, uint32_t id, uint8_t dlc, uint32_t data1, uint32_t data2) {
    // Wait for TX FIFO empty
    while ((read_reg(base + 0x18) & (1 << 3)) == 0);

    write_reg(base + 0x30, id);
    write_reg(base + 0x34, dlc);
    write_reg(base + 0x38, data1);
    write_reg(base + 0x3C, data2);
}

uint32_t can_receive(uintptr_t base) {
    if ((read_reg(base + 0x18) & (1 << 0)) != 0) {
        uint32_t id = read_reg(base + 0x50);
        uint32_t dlc = read_reg(base + 0x54);
        uint32_t data1 = read_reg(base + 0x58);
        uint32_t data2 = read_reg(base + 0x5C);
        printf("CAN RX: ID=0x%X, DLC=%d, Data=0x%X%X\n", id, dlc, data1, data2);
        return 1;
    }
    return 0;
}

void test_can(uintptr_t base, const char *name) {
    printf("Testing %s...\n", name);
    can_init(base);

    // Send a test message
    can_send(base, 0x123, 8, 0xDEADBEEF, 0xCAFEBABE);

    // Wait a bit and check for receive (if loopback)
    rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(10));
    if (!can_receive(base)) {
        printf("%s: No message received (check connections)\n", name);
    }
}

static void on_rx_data(void *arg) {
    Transceiver *dev = (Transceiver *)arg;
    
    /* 1. Obtenemos el buffer correspondiente a ESTE transceptor */
    AppLineBuffer *line = &rx_lines[dev->id];
    
    uint8_t temp_buf[64]; /* Buffer temporal para sacar datos del driver */
    size_t n;

    /* 2. Drenamos todo lo que tenga el driver disponible */
    do {
        n = Transceiver_Read(dev, temp_buf, sizeof(temp_buf));
        
        for (size_t i = 0; i < n; i++) {
            char c = (char)temp_buf[i];

            /* A. Si es salto de línea: Terminar y Mostrar */
            if (c == '\n' || c == '\r') {
                if (line->idx > 0) { // Solo imprimir si hay algo acumulado
                    line->buf[line->idx] = '\0'; // Null-termination
                    printf("[RX UART %02d]: %s\n", (unsigned int)dev->id, line->buf);
                    fflush(stdout);
                    line->idx = 0; // Resetear índice para la siguiente frase
                }
            } 
            /* B. Si es un carácter normal: Acumular */
            else {
                if (line->idx < (APP_LINE_BUF_SIZE - 1)) {
                    line->buf[line->idx++] = c;
                } 
                /* C. Protección Anti-Overflow: Si se llena sin \n, forzamos impresión */
                else {
                    line->buf[line->idx] = '\0';
                    printf("[RX UART %02d PARCIAL]: %s\n", (unsigned int)dev->id, line->buf);
                    line->idx = 0; // Reset y guardamos el carácter actual en el nuevo buffer
                    line->buf[line->idx++] = c;
                }
            }
        }
    } while (n > 0);
}

/* =========================================================================
 * 2. TAREA DE CONSOLA (Parsea comandos y envía)
 * ========================================================================= */
static rtems_task Tx_Console_Task(rtems_task_argument arg) {
    (void)arg;
    char input_buf[512];
    char *cmd_ptr;
    char *msg_ptr;
    int target_id;

    printf("\n=======================================================\n");
    printf(" CONSOLA DE CONTROL MULTI-TRANSCEPTOR\n");
    printf("-------------------------------------------------------\n");
    printf(" Formato: <ID> <MENSAJE> | <ID> SLO ON | <ID> SLO OFF\n");
    printf(" Comandos especiales: SPI TEST | CAN0 TEST | CAN1 TEST\n");
    printf(" Ejemplos:\n");
    printf("   '0 Hola'      -> Envia 'Hola' por UART 0\n");
    printf("   'ALL Reset'   -> Envia 'Reset' por TODAS las UARTs\n");
    printf("   '2 SLO ON'    -> Activa el modo Slow Rate en UART 2\n");
    printf("   'ALL SLO OFF' -> Desactiva el modo Slow en TODAS\n");
    printf("   'SPI TEST'    -> Prueba el ADC ADS7950 por SPI\n");
    printf("   'CAN0 TEST'   -> Prueba CAN 0\n");
    printf("   'CAN1 TEST'   -> Prueba CAN 1\n");
    printf("=======================================================\n\n");

    for (;;) {
        /* Prompt */
        printf("CMD> ");
        fflush(stdout);

        /* Leer línea de la consola USB */
        if (fgets(input_buf, sizeof(input_buf), stdin) == NULL) {
            rtems_task_wake_after(RTEMS_MILLISECONDS_TO_TICKS(100));
            continue;
        }

        /* Ignorar líneas vacías */
        if (strlen(input_buf) == 0) continue;

        /* Separar ID del Mensaje */
        cmd_ptr = strtok(input_buf, " "); // Primer token (ID o ALL)
        msg_ptr = strtok(NULL, "");       // Resto de la línea (Mensaje o Comando)

        if (msg_ptr == NULL) {
            printf("Error: Falta el mensaje o comando.\n");
            continue;
        }

        /* --- CASO 1: Enviar a TODOS --- */
        if (strcasecmp(cmd_ptr, "ALL") == 0) {
            if (strcasecmp(msg_ptr, "SLO ON") == 0) {
                printf("Activando SLO en todas las UARTs...\n");
                for (int i = 0; i < num_transceivers; i++) {
                    Transceiver_Init(&uarts[i], i, &cfg_slo_on);
                    Transceiver_SetRxCallback(&uarts[i], on_rx_data, &uarts[i]);
                }
            } else if (strcasecmp(msg_ptr, "SLO OFF") == 0) {
                printf("Desactivando SLO en todas las UARTs...\n");
                for (int i = 0; i < num_transceivers; i++) {
                    Transceiver_Init(&uarts[i], i, &cfg_slo_off);
                    Transceiver_SetRxCallback(&uarts[i], on_rx_data, &uarts[i]);
                }
            } else {
                printf("Enviando a las %d UARTs...\n", num_transceivers);
                for (int i = 0; i < num_transceivers; i++) {
                    Transceiver_SendString(&uarts[i], msg_ptr);
                }
            }
            continue;
        }

        /* --- CASO 2: Comandos especiales --- */
        if (strcasecmp(cmd_ptr, "SPI") == 0 && strcasecmp(msg_ptr, "TEST") == 0) {
            test_spi();
            continue;
        }
        if (strcasecmp(cmd_ptr, "CAN0") == 0 && strcasecmp(msg_ptr, "TEST") == 0) {
            test_can(CAN0_BASE, "CAN0");
            continue;
        }
        if (strcasecmp(cmd_ptr, "CAN1") == 0 && strcasecmp(msg_ptr, "TEST") == 0) {
            test_can(CAN1_BASE, "CAN1");
            continue;
        }

        /* --- CASO 2: Enviar a ID específico --- */
        char *endptr;
        target_id = strtoul(cmd_ptr, &endptr, 10);

        if (*endptr != '\0') {
            printf("Error: ID '%s' no valido.\n", cmd_ptr);
            continue;
        }

        if (target_id >= 0 && target_id < num_transceivers) {
            
            /* Interceptar comandos de configuración de Slew Rate */
            if (strcasecmp(msg_ptr, "SLO ON") == 0) {
                Transceiver_Init(&uarts[target_id], target_id, &cfg_slo_on);
                Transceiver_SetRxCallback(&uarts[target_id], on_rx_data, &uarts[target_id]);
                printf("SLO -> UART %d: ON\n", target_id);
            } 
            else if (strcasecmp(msg_ptr, "SLO OFF") == 0) {
                Transceiver_Init(&uarts[target_id], target_id, &cfg_slo_off);
                Transceiver_SetRxCallback(&uarts[target_id], on_rx_data, &uarts[target_id]);
                printf("SLO -> UART %d: OFF\n", target_id);
            } 
            else {
                /* ¡ENVÍO REAL! */
                Transceiver_SendString(&uarts[target_id], msg_ptr);
                printf("Tx -> UART %d: OK\n", target_id);
            }
        } else {
            printf("Error: ID %d fuera de rango (0-%d)\n", target_id, num_transceivers - 1);
        }
    }
}

/* =========================================================================
 * 3. INICIALIZACIÓN DEL SISTEMA
 * ========================================================================= */
rtems_task Init(rtems_task_argument arg) {
    (void)arg;
    rtems_status_code sc;

    /* Mapeo de Memoria (Necesario para acceder al PL) */
    extern void mmu_map_pl_axi_early(void);
    mmu_map_pl_axi_early();

    
    /* 1. Inicializar el INTC Global (Paso Crítico Único) */
    /* Esto habilita el controlador maestro que escucha a las 14 UARTs */
    num_transceivers = Transceiver_Global_INIT();
    printf("\n=== ARRANQUE SISTEMA ZCU102 (%d UARTs) ===\n", num_transceivers);
    /* 2. Bucle de Inicialización de Transceptores */
    for (int i = 0; i < num_transceivers; i++) {
        /* Esta función calcula las direcciones automáticamente basándose en el ID */
        sc = Transceiver_Init(&uarts[i], i, &cfg);

        if (sc == RTEMS_SUCCESSFUL) {
            /* Registrar callback para recibir datos */
            Transceiver_SetRxCallback(&uarts[i], on_rx_data, &uarts[i]);
            
            /* Saludo opcional por el cable al arrancar */
            char boot_msg[64];
            sprintf(boot_msg, "UART %d Lista.\r\n", i);
            Transceiver_SendString(&uarts[i], boot_msg);
            
            printf("UART %02d [OK] Base: 0x%08lX\n", i, (unsigned long)uarts[i].base_addr);
        } else {
            printf("UART %02d [FALLO] Error código: %d\n", i, sc);
        }
    }

    /* Testing SPI and CAN */
    test_spi();
    test_can(CAN0_BASE, "CAN0");
    test_can(CAN1_BASE, "CAN1");

    /* 3. Arrancar la Consola de Usuario */
    rtems_id console_tid;
    sc = rtems_task_create(rtems_build_name('C','M','D','T'), 
                           100, /* Prioridad baja */
                           RTEMS_MINIMUM_STACK_SIZE * 4,
                           RTEMS_DEFAULT_MODES, 
                           RTEMS_DEFAULT_ATTRIBUTES, 
                           &console_tid);
    if (sc == RTEMS_SUCCESSFUL) {
        rtems_task_start(console_tid, Tx_Console_Task, 0);
    }

    /* Init muere o duerme */
    rtems_task_delete(RTEMS_SELF);
}