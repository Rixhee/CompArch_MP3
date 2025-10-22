`include "memory.sv"
`include "ws2812b.sv"
`include "controller.sv"

// led_matrix top level module

module top(
    input logic     clk, 
    output logic    _48b, 
    output logic    _45a
);

    logic [7:0] red_matrix [0:7][0:7];
    logic [7:0] green_matrix [0:7][0:7];
    logic [7:0] blue_matrix [0:7][0:7];
    logic [23:0] pixel_value = 24'd0;

    logic [23:0] shift_reg = 24'd0;
    logic load_sreg;
    logic red_init_done;
    logic green_init_done;
    logic blue_init_done;
    logic transmit_pixel;
    logic shift;
    logic ws2812b_out;

    // Instance initial memory for red channel
    memory #(
        .INIT_FILE      ("initial/red.txt")
    ) u1 (
        .clk            (clk), 
        .matrix         (red_matrix),
        .init_done      (red_init_done)
    );

    // Instance initial memory for green channel
    memory #(
        .INIT_FILE      ("initial/green.txt")
    ) u2 (
        .clk            (clk), 
        .matrix         (green_matrix),
        .init_done      (green_init_done)
    );

    // Instance initial memory for blue channel
    memory #(
        .INIT_FILE      ("initial/blue.txt")
    ) u3 (
        .clk            (clk), 
        .matrix         (blue_matrix), 
        .init_done      (blue_init_done)
    );

    // Instance the WS2812B output driver
    ws2812b u4 (
        .clk            (clk), 
        .serial_in      (shift_reg[23]), 
        .transmit       (transmit_pixel), 
        .ws2812b_out    (ws2812b_out), 
        .shift          (shift)
    );

    // Instance the controller
    controller u5 (
        .clk                (clk), 
        .red_matrix         (red_matrix),
        .green_matrix       (green_matrix),
        .blue_matrix        (blue_matrix),
        .red_init_done      (red_init_done),
        .green_init_done    (green_init_done),
        .blue_init_done     (blue_init_done),
        .load_sreg          (load_sreg), 
        .transmit_pixel     (transmit_pixel),
        .pixel_value        (pixel_value)
    );

    always_ff @(posedge clk) begin
        if (load_sreg) begin
            shift_reg <= pixel_value;
        end
        else if (shift) begin
            shift_reg <= { shift_reg[22:0], 1'b0 };
        end
    end

    assign _48b = ws2812b_out;
    assign _45a = ~ws2812b_out;

endmodule
