module fade #(
    parameter PWM_INTERVAL = 1000, // CLK frequency is 12Mhz, so the PWM cycle would complete every ~83us
    parameter INC_DEC_INTERVAL = 10000, // CLK frequency is 12Mhz, so the brightness would inc/dec every ~.83ms
    parameter INC_DEC_MAX = 200, // The transition would occur every ~0.16s
    parameter INC_DEC_VAL = PWM_INTERVAL / INC_DEC_MAX, // Calculating the value by which the PWM value should change for brightness
    parameter ONE_SECOND = 12000000,
    parameter STATE_TRANSITION_INTERVAL = ONE_SECOND / 6 // Change color every ~0.16s
) (
    input logic clk,
    input logic pixel_value,
    output logic [23:0] colored_pixel_value
);

    // Define the various states
    localparam PWM_INC = 1'b0;
    localparam PWM_DEC = 1'b1;
        
    logic current_state = PWM_INC;
    logic next_state;

    // Color state machine
    localparam GREEN_INC = 3'b000;
    localparam RED_DEC = 3'b001;
    localparam BLUE_INC = 3'b010;
    localparam GREEN_DEC = 3'b011;
    localparam RED_INC = 3'b100;
    localparam BLUE_DEC = 3'b101;

    logic [2:0] color_current_state = GREEN_INC;
    logic [2:0] color_next_state;
    logic time_to_switch_state;

    // Definding variables to keep track of counts, and transitions
    logic [$clog2(INC_DEC_MAX) - 1: 0] inc_dec_count = 0;
    logic [$clog2(INC_DEC_INTERVAL) - 1: 0] clk_count = 0;
    logic time_to_inc_dec = 1'b0;
    logic time_to_transition = 1'b0;

    // PWM signals
    logic [$clog2(STATE_TRANSITION_INTERVAL) - 1: 0] count;
    logic [$clog2(PWM_INTERVAL) - 1: 0] pwm_value;
    
    // RGB values derived from PWM intensity and color state
    logic [7:0] pwm_red, pwm_green, pwm_blue;

    initial begin
        count = 0;
    end

    // Convert PWM value to 8-bit intensity for smooth fading
    logic [7:0] pwm_intensity;
    assign pwm_intensity = 8'((pwm_value * 255) / PWM_INTERVAL);
    
    // Initialize the PWM value as 0
    initial begin
        pwm_value = 0;
    end

    // Set the next state according to current state
    always_comb begin
        next_state = 1'bx;
        case (current_state)
            PWM_INC:
                next_state = PWM_DEC;
            PWM_DEC:
                next_state = PWM_INC;
        endcase
    end

    // Increase/decrease the pwm value (brightness)
    always_ff @(posedge time_to_inc_dec) begin
        case (current_state)
            PWM_INC:
                pwm_value <= pwm_value + INC_DEC_VAL;
            PWM_DEC:
                pwm_value <= pwm_value - INC_DEC_VAL;
        endcase
    end

    // Update clk counter every cycle and set time to inc/dec
    always_ff @(posedge clk) begin
        if (clk_count == INC_DEC_INTERVAL - 1) begin
            clk_count <= 0;
            time_to_inc_dec <= 1'b1;
        end
        else begin
            clk_count <= clk_count + 1;
            time_to_inc_dec <= 1'b0;
        end
    end

    // Update the inc_dec_count and set the time_to_transition
    always_ff @(posedge time_to_inc_dec) begin
        if (inc_dec_count == INC_DEC_MAX - 1) begin
            inc_dec_count <= 0;
            time_to_transition <= 1'b1;
        end
        else begin
            inc_dec_count <= inc_dec_count + 1;
            time_to_transition <= 1'b0;
        end
    end

    // Change current state everytime we set time_to_transition
    always_ff @(posedge time_to_transition) begin
        current_state <= next_state;
    end

    // Generate RGB values
    always_comb begin
        color_next_state = 3'bxxx;
        pwm_red = 8'h00;
        pwm_green = 8'h00;
        pwm_blue = 8'h00;
        
        case (color_current_state)
            GREEN_INC: begin
                pwm_red = 8'hFF;                  
                pwm_green = pwm_intensity;        
                pwm_blue = 8'h00;                 
                color_next_state = RED_DEC;             
            end
            RED_DEC: begin
                pwm_red = pwm_intensity;  
                pwm_green = 8'hFF;        
                pwm_blue = 8'h00; 
                color_next_state = BLUE_INC;             
            end
            BLUE_INC: begin
                pwm_red = 8'h00;                  
                pwm_green = 8'hFF;                
                pwm_blue = pwm_intensity;         
                color_next_state = GREEN_DEC;           
            end
            GREEN_DEC: begin
                pwm_red = 8'h00;                  
                pwm_green = pwm_intensity; 
                pwm_blue = 8'hFF;          
                color_next_state = RED_INC;      
            end
            RED_INC: begin
                pwm_red = pwm_intensity;   
                pwm_green = 8'h00;         
                pwm_blue = 8'hFF;          
                color_next_state = BLUE_DEC;     
            end
            BLUE_DEC: begin
                pwm_red = 8'hFF;           
                pwm_green = 8'h00;         
                pwm_blue = pwm_intensity;  
                color_next_state = GREEN_INC;    
            end
            default: begin
                color_next_state = GREEN_INC;
            end
        endcase
    end

    // Combine Game of Life with PWM colors
    assign colored_pixel_value = (pixel_value != 0) ? 
                                 {pwm_green, pwm_red, pwm_blue} :
                                 24'h000000;

    // Color state machine timing 
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
        color_current_state <= color_next_state;
    end

endmodule
