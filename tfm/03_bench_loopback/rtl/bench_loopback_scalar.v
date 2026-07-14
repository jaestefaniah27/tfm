// bench_loopback_scalar.v — mismo loopback, con puertos sueltos.
//
// Los block designs de las variantes GPIO y DMA14 exponen los canales como
// pines escalares (Transceiver_i/TD, Transceiver_i/RD), no como un bus. Conectar
// un vector a pines sueltos en un block design exigiría catorce xlslice y un
// xlconcat; es más limpio envolver el módulo vectorial y exponer 28 pines.

`timescale 1ns / 1ps

module bench_loopback_scalar (
    input  wire td0,  input  wire td1,  input  wire td2,  input  wire td3,
    input  wire td4,  input  wire td5,  input  wire td6,  input  wire td7,
    input  wire td8,  input  wire td9,  input  wire td10, input  wire td11,
    input  wire td12, input  wire td13,

    output wire rd0,  output wire rd1,  output wire rd2,  output wire rd3,
    output wire rd4,  output wire rd5,  output wire rd6,  output wire rd7,
    output wire rd8,  output wire rd9,  output wire rd10, output wire rd11,
    output wire rd12, output wire rd13
);

    wire [13:0] td = {td13, td12, td11, td10, td9, td8, td7,
                      td6,  td5,  td4,  td3,  td2, td1, td0};
    wire [13:0] rd;

    bench_loopback u_loopback (.td(td), .rd(rd));

    assign rd0  = rd[0];   assign rd1  = rd[1];   assign rd2  = rd[2];
    assign rd3  = rd[3];   assign rd4  = rd[4];   assign rd5  = rd[5];
    assign rd6  = rd[6];   assign rd7  = rd[7];   assign rd8  = rd[8];
    assign rd9  = rd[9];   assign rd10 = rd[10];  assign rd11 = rd[11];
    assign rd12 = rd[12];  assign rd13 = rd[13];

endmodule
