`include "memory.sv"
`include "ws2812b.sv"
`include "controller.sv"
`include "fade.sv"

// Combined LED matrix with PWM color cycling
module top #()(
    input logic     clk, 
    output logic    _48b, 
    output logic    _45a
);

    // Game of Life signals
    logic [7:0] red_data;
    logic [7:0] green_data;
    logic [7:0] blue_data;
    logic pixel_value;
    logic [23:0] colored_pixel_value;
    logic [5:0] mem_address;
    logic [23:0] shift_reg = 24'd0;
    logic load_sreg;
    logic transmit_pixel;
    logic shift;
    logic ws2812b_out;
    logic generation_complete;

    // Memory instances for initial pattern
    memory #(
        .INIT_FILE      ("initial/red.txt")
    ) u1 (
        .clk            (clk), 
        .read_address   (mem_address),
        .read_data      (red_data)
    );

    memory #(
        .INIT_FILE      ("initial/green.txt")
    ) u2 (
        .clk            (clk), 
        .read_address   (mem_address),
        .read_data      (green_data)
    );

    memory #(
        .INIT_FILE      ("initial/blue.txt")
    ) u3 (
        .clk            (clk), 
        .read_address   (mem_address),
        .read_data      (blue_data)
    );

    // WS2812B driver
    ws2812b u4 (
        .clk            (clk), 
        .serial_in      (shift_reg[23]), 
        .transmit       (transmit_pixel), 
        .ws2812b_out    (ws2812b_out), 
        .shift          (shift)
    );

    // Game of Life controller
    controller u5 (
        .clk                (clk), 
        .red_data           (red_data),
        .green_data         (green_data),
        .blue_data          (blue_data),
        .mem_address        (mem_address),
        .load_sreg          (load_sreg), 
        .transmit_pixel     (transmit_pixel),
        .pixel_value        (pixel_value),
        .generation_complete(generation_complete)
    );

    // Cycling through the color wheel
    fade u6 (
        .clk                 (clk),
        .pixel_value         (pixel_value),
        .colored_pixel_value (colored_pixel_value)
    );

    // Shift register for WS2812B transmission
    always_ff @(posedge clk) begin
        if (load_sreg) begin
            shift_reg <= colored_pixel_value;
        end
        else if (shift) begin
            shift_reg <= { shift_reg[22:0], 1'b0 };
        end
    end

    assign _48b = ws2812b_out;
    assign _45a = ~ws2812b_out;

endmodule
