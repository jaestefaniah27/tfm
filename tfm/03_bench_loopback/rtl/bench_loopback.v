// bench_loopback.v — cierra en la FPGA los buses que el benchmark espera
// encontrar en la PCB, para poder ejecutarlo sin hardware externo.
//
// Reproduce la topología de bench_compat.h:
//     Bus A (multidrop): maestro CH0  | esclavos CH1..CH6
//     Bus B            : maestro CH7  | esclavos CH8..CH10
//     Bus C            : maestro CH11 | esclavos CH12..CH13
//
// Modelo eléctrico: un bus RS485 en reposo está a '1' y los drivers hacen
// wired-AND sobre él. La línea de recepción de un canal es, por tanto, el AND
// de las transmisiones del resto de canales de su bus.
//
// Un canal NO se oye a sí mismo. En la PCB el receptor se inhibe mientras DE
// está activo; si aquí realimentáramos el eco, cada byte enviado se contaría
// dos veces en `bytes_rx` y el test de overrun mediría el doble de pérdidas.
//
// Consecuencia directa de excluir el auto-eco:
//     rd[1] = td[0]   (el esclavo 1 oye al maestro del bus A)
//     rd[0] = 1       (el maestro no oye a nadie: los esclavos callan)
// que es exactamente el camino CH0→CH1 sobre el que mide el benchmark.

`timescale 1ns / 1ps

module bench_loopback (
    input  wire [13:0] td,
    output wire [13:0] rd
);

    // Máscara de los canales que comparten bus con el canal `i`.
    function [13:0] bus_mask(input integer i);
        begin
            if (i <= 6)       bus_mask = 14'h007F;   // Bus A: canales 0..6
            else if (i <= 10) bus_mask = 14'h0780;   // Bus B: canales 7..10
            else              bus_mask = 14'h3800;   // Bus C: canales 11..13
        end
    endfunction

    genvar i;
    generate
        for (i = 0; i < 14; i = i + 1) begin : gen_bus
            // Los demás miembros del bus, excluido el propio canal.
            wire [13:0] others = bus_mask(i) & ~(14'b1 << i);
            // Los bits ajenos al bus se fuerzan a '1' para no afectar al AND.
            assign rd[i] = &(td | ~others);
        end
    endgenerate

endmodule
