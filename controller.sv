module controller (
    input logic clk,
    input logic [7:0] red_matrix [0:7][0:7],
    input logic [7:0] green_matrix [0:7][0:7],
    input logic [7:0] blue_matrix [0:7][0:7],
    input logic red_init_done,
    input logic green_init_done,
    input logic blue_init_done,
    output logic load_sreg,
    output logic transmit_pixel,
    output logic [23:0] pixel_value
);



endmodule
