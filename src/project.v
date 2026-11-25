/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_sensor_preproc (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock (base 10 kHz -> 100 us por ciclo)
    input  wire       rst_n     // reset_n - low to reset
);

    // 100 ciclos a 10 kHz = 10 ms de ventana de captura
    localparam integer WINDOW_CYCLES = 100;

    // Estados de la FSM (2 bits)
    localparam [1:0] ST_IDLE    = 2'd0,
                     ST_CAPTURE = 2'd1,
                     ST_DONE    = 2'd2;

    // Mapeo de entradas desde ui_in:
    // ui_in[2:0] -> sensores A (A3, A2, A1)
    // ui_in[5:3] -> sensores D (D3, D2, D1)
    // ui_in[6]   -> ack desde el microcontrolador
    wire [2:0] a_in = ui_in[2:0];
    wire [2:0] d_in = ui_in[5:3];
    wire       ack  = ui_in[6];

    wire any_sensor = (|a_in) || (|d_in);

    reg [1:0] state;
    reg [6:0] cnt;        // Suficiente para contar hasta 100 ciclos
    reg [2:0] a_cap;      // Acumulador simple de A durante la ventana
    reg [2:0] d_cap;      // Acumulador simple de D durante la ventana

    // Registros de salida retenidos hasta que llegue ACK
    reg [1:0] status_q;
    reg [2:0] zone_q;
    reg       event_q;
    reg       ready_q;

    // Logica combinacional que evalua lo capturado al cerrar la ventana
    reg [1:0] comb_status;
    reg [2:0] comb_zone;
    reg       comb_event;

    always @(*) begin
        comb_status = 2'b00;
        comb_zone   = 3'b000;
        comb_event  = 1'b0;

        if ((a_cap == 3'b000) && (d_cap == 3'b000)) begin
            comb_status = 2'b00;
        end else if ((a_cap != 3'b000) && (a_cap == d_cap)) begin
            // Misma senal activa en A y D (ej. 001, 010 o 100)
            comb_status = 2'b01;
            comb_zone   = a_cap;
            comb_event  = 1'b1;
        end else if ((a_cap == 3'b000) || (d_cap == 3'b000)) begin
            // Solo llego A o solo llego D
            comb_status = 2'b10;
        end else begin
            // Llegaron ambos pero en zonas distintas o combinaciones diferentes
            comb_status = 2'b11;
        end
    end

    // Maquina de estados principal
    always @(posedge clk) begin
        if (!rst_n) begin
            state    <= ST_IDLE;
            cnt      <= 7'd0;
            a_cap    <= 3'b000;
            d_cap    <= 3'b000;
            status_q <= 2'b00;
            zone_q   <= 3'b000;
            event_q  <= 1'b0;
            ready_q  <= 1'b0;
        end else begin
            // El microcontrolador limpia ready_q cuando manda ACK
            if (ack) begin
                ready_q <= 1'b0;
            end

            case (state)
                ST_IDLE: begin
                    cnt <= 7'd0;
                    if (any_sensor && !ready_q) begin
                        a_cap <= a_in;
                        d_cap <= d_in;
                        state <= ST_CAPTURE;
                    end
                end

                ST_CAPTURE: begin
                    a_cap <= a_cap | a_in;
                    d_cap <= d_cap | d_in;

                    if (cnt >= WINDOW_CYCLES - 1) begin
                        state <= ST_DONE;
                    end else begin
                        cnt <= cnt + 7'd1;
                    end
                end

                ST_DONE: begin
                    status_q <= comb_status;
                    zone_q   <= comb_zone;
                    event_q  <= comb_event;
                    ready_q  <= 1'b1;

                    a_cap <= 3'b000;
                    d_cap <= 3'b000;
                    cnt   <= 7'd0;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

    // Asignacion de salidas a uo_out:
    // uo_out[1:0] -> status
    // uo_out[4:2] -> zone
    // uo_out[5]   -> event_ok
    // uo_out[6]   -> data_ready
    // uo_out[7]   -> 0
    assign uo_out[1:0] = status_q;
    assign uo_out[4:2] = zone_q;
    assign uo_out[5]   = event_q;
    assign uo_out[6]   = ready_q;
    assign uo_out[7]   = 1'b0;

    // Pines bidireccionales sin uso
    assign uio_out = 8'b0000_0000;
    assign uio_oe  = 8'b0000_0000;

    // Evita advertencias por entradas no usadas
    wire _unused = &{ena, uio_in, ui_in[7], 1'b0};

endmodule
