module fade #(
    parameter PWM_INTERVAL = 1000, // CLK frequency is 12Mhz, so the PWM cycle would complete every ~83us
    parameter INC_DEC_INTERVAL = 10000, // CLK frequency is 12Mhz, so the brightness would inc/dec every ~.83ms
    parameter INC_DEC_MAX = 200, // The transition would occur every ~0.16s
    parameter INC_DEC_VAL = PWM_INTERVAL / INC_DEC_MAX // Calculating the value by which the PWM value should change for brightness
) (
    input logic clk,
    output logic [$clog2(PWM_INTERVAL) - 1: 0] pwm_value
);

    // Define the various states
    localparam PWM_INC = 1'b0;
    localparam PWM_DEC = 1'b1;

    logic current_state = PWM_INC;
    logic next_state;

    // Definding variables to keep track of counts, and transitions
    logic [$clog2(INC_DEC_MAX) - 1: 0] inc_dec_count = 0;
    logic [$clog2(INC_DEC_INTERVAL) - 1: 0] clk_count = 0;
    logic time_to_inc_dec = 1'b0;
    logic time_to_transition = 1'b0;

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

endmodule
