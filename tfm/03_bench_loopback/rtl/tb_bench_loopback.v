// tb_bench_loopback.v — comprueba que el loopback reproduce los caminos que
// bench_main.c da por supuestos, y que no crea diafonía entre buses.
`timescale 1ns / 1ps

module tb_bench_loopback;

    reg  [13:0] td;
    wire [13:0] rd;
    integer errors = 0;

    bench_loopback dut (.td(td), .rd(rd));

    task check(input [255:0] name, input expected, input actual);
        begin
            if (expected !== actual) begin
                $display("FALLO %0s: esperado %b, obtenido %b", name, expected, actual);
                errors = errors + 1;
            end else begin
                $display("  ok  %0s = %b", name, actual);
            end
        end
    endtask

    initial begin
        // ── Reposo: todo el mundo calla, todas las líneas a '1' ────────────
        td = 14'h3FFF; #1;
        check("reposo rd", 1'b1, &rd);

        // ── T1/T2: el maestro del bus A baja su línea (bit de start) ───────
        td = 14'h3FFF; td[0] = 1'b0; #1;
        check("rd[1] sigue a td[0]", 1'b0, rd[1]);
        check("rd[6] sigue a td[0]", 1'b0, rd[6]);
        check("rd[0] no se oye a si mismo", 1'b1, rd[0]);
        check("rd[8] aislado del bus A",    1'b1, rd[8]);
        check("rd[12] aislado del bus A",   1'b1, rd[12]);

        // ── T3: los tres maestros transmiten a la vez, sin interferirse ────
        td = 14'h3FFF; td[0] = 1'b0; td[7] = 1'b0; td[11] = 1'b0; #1;
        check("bus A: rd[1]",  1'b0, rd[1]);
        check("bus B: rd[8]",  1'b0, rd[8]);
        check("bus C: rd[12]", 1'b0, rd[12]);
        check("maestro A mudo a si mismo",  1'b1, rd[0]);
        check("maestro B mudo a si mismo",  1'b1, rd[7]);
        check("maestro C mudo a si mismo",  1'b1, rd[11]);

        // ── T4: un solo emisor, los seis esclavos del bus A lo oyen ────────
        td = 14'h3FFF; td[0] = 1'b0; #1;
        check("multidrop rd[1..6] todos a 0", 1'b0, |rd[6:1]);

        // ── Un esclavo respondiendo: lo oye el maestro, no los demás buses ─
        td = 14'h3FFF; td[1] = 1'b0; #1;
        check("respuesta: rd[0] oye a td[1]", 1'b0, rd[0]);
        check("respuesta: rd[2] tambien la oye (multidrop)", 1'b0, rd[2]);
        check("respuesta no cruza al bus B", 1'b1, rd[8]);

        if (errors == 0) $display("\nTB OK: 0 fallos");
        else             $display("\nTB CON FALLOS: %0d", errors);
        $finish;
    end

endmodule
