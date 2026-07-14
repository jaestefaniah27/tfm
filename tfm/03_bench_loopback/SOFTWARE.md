# El software del benchmark

El programa de medida es `bench_main.c`. Vive **junto a cada variante**, en
`02_transporte/<variante>/software/bench/`, porque necesita el `transceiver.h` de su
propio driver para compilar.

Las tres copias son el mismo programa salvo cuatro líneas: la versión del MCDMA llama a
`Transceiver_BenchDbgReset()` antes de cada bloque de 1024 B, para que los contadores de
traza midan solo ese bloque y no arrastren lo recibido en las pruebas anteriores. Esa
función solo existe en el driver del MCDMA. Los tests que ejecuta (T1..T7) y las métricas
que emite son idénticos, así que la comparación es válida.

Junto a él van:

- `bench_compat.h` — la topología de buses que el test da por supuesta (qué canal es
  maestro de qué bus). El loopback de la PL reproduce exactamente esta topología.
- `transceiver_bench.h` — contadores de instrumentación del driver (interrupciones,
  bytes, errores), lo que alimenta la métrica `irq_per_kb`.

## Compilar una variante

```bash
export RTEMS_PREFIX=$HOME/quick-start/rtems/7
cd tfm/02_transporte/c_mcdma_bridge/software
cp bench/* .                       # el wscript coge todos los *.c del directorio
../../../06_tools/make_img.sh      # → rtems.img
```

Ojo: el `wscript` compila **todos** los `.c` de la carpeta, así que no puede haber a la vez
`main.c` y `bench_main.c` (dos `Init`). Deja solo el que quieras arrancar.
