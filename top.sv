`include "memory.sv"
`include "ws2812b.sv"
`include "controller.sv"
`include "fade.sv"

// Combined LED matrix with PWM color cycling
module top #(
    parameter PWM_INTERVAL = 1000,
    parameter ONE_SECOND = 12000000,
    parameter STATE_TRANSITION_INTERVAL = ONE_SECOND / 6 // Change color every ~0.16s
)(
    input logic     clk, 
    output logic    _48b, 
    output logic    _45a
);

    // Game of Life signals
    logic [7:0] red_data;
    logic [7:0] green_data;
    logic [7:0] blue_data;
    logic pixel_value;
    logic [5:0] mem_address;
    logic [23:0] shift_reg = 24'd0;
    logic load_sreg;
    logic transmit_pixel;
    logic shift;
    logic ws2812b_out;
    logic generation_complete;

    // PWM signals
    logic [$clog2(PWM_INTERVAL) - 1: 0] pwm_value;
    logic [$clog2(STATE_TRANSITION_INTERVAL) - 1: 0] count;
    
    // Color state machine - your original 6 states
    localparam GREEN_INC = 3'b000;
    localparam RED_DEC = 3'b001;
    localparam BLUE_INC = 3'b010;
    localparam GREEN_DEC = 3'b011;
    localparam RED_INC = 3'b100;
    localparam BLUE_DEC = 3'b101;

    logic [2:0] current_state = GREEN_INC;
    logic [2:0] next_state;
    logic time_to_switch_state;
    
    // RGB values derived from PWM intensity and color state
    logic [7:0] pwm_red, pwm_green, pwm_blue;
    logic [23:0] colored_pixel_value;

    initial begin
        count = 0;
    end

    // Convert PWM value to 8-bit intensity for smooth fading
    logic [7:0] pwm_intensity;
    assign pwm_intensity = 8'((pwm_value * 255) / PWM_INTERVAL);
    
    // Generate RGB values using your original color wheel states, modulated by PWM intensity
    always_comb begin
        next_state = 3'bxxx;
        pwm_red = 8'h00;
        pwm_green = 8'h00;
        pwm_blue = 8'h00;
        
        case (current_state)
            GREEN_INC: begin
                pwm_red = 8'hFF;                  
                pwm_green = pwm_intensity;        
                pwm_blue = 8'h00;                 
                next_state = RED_DEC;             
            end
            RED_DEC: begin
                pwm_red = pwm_intensity;  
                pwm_green = 8'hFF;        
                pwm_blue = 8'h00; 
                next_state = BLUE_INC;             
            end
            BLUE_INC: begin
                pwm_red = 8'h00;                  
                pwm_green = 8'hFF;                
                pwm_blue = pwm_intensity;         
                next_state = GREEN_DEC;           
            end
            GREEN_DEC: begin
                pwm_red = 8'h00;                  
                pwm_green = pwm_intensity; 
                pwm_blue = 8'hFF;          
                next_state = RED_INC;      
            end
            RED_INC: begin
                pwm_red = pwm_intensity;   
                pwm_green = 8'h00;         
                pwm_blue = 8'hFF;          
                next_state = BLUE_DEC;     
            end
            BLUE_DEC: begin
                pwm_red = 8'hFF;           
                pwm_green = 8'h00;         
                pwm_blue = pwm_intensity;  
                next_state = GREEN_INC;    
            end
            default: begin
                next_state = GREEN_INC;
            end
        endcase
    end

    // Combine Game of Life with PWM colors
    // If pixel is alive (non-zero), use PWM colors; if dead, use black
    assign colored_pixel_value = (pixel_value != 0) ? 
                                 {pwm_green, pwm_red, pwm_blue} :
                                 24'h000000;

    // Color state machine timing - change every 1 second
    always_ff @(posedge clk) begin
        if (count == ($clog2(STATE_TRANSITION_INTERVAL))'(STATE_TRANSITION_INTERVAL - 1)) begin
            count <= 0;
            time_to_switch_state <= 1'b1;
        end
        else begin
            count <= count + 1;
            time_to_switch_state <= 1'b0;
        end
    end

    always_ff @(posedge time_to_switch_state) begin
        current_state <= next_state;
    end

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
    fade #(
        .PWM_INTERVAL (PWM_INTERVAL)
    ) u6 (
        .clk (clk),
        .pwm_value (pwm_value)
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
