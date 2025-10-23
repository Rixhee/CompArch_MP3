module controller (
    input logic clk,
    input logic [7:0] red_data,
    input logic [7:0] green_data,
    input logic [7:0] blue_data,
    output logic [5:0] mem_address,
    output logic load_sreg,
    output logic transmit_pixel,
    output logic pixel_value,
    output logic generation_complete
);

    // Transmission timing parameters
    localparam [2:0] READ_CH_VALS   = 3'b001;
    localparam [2:0] LOAD_SREG      = 3'b010;
    localparam [2:0] TRANSMIT_PIXEL = 3'b100;
    localparam [8:0] TRANSMIT_CYCLES = 9'd360;       // 24 bits/pixel x 15 cycles/bit
    localparam [17:0] IDLE_CYCLES = 18'd187140;      // 0.25 second per generation (16 frames × 0.015625s each)
    localparam [4:0] MAX_FRAME_COUNT = 5'd16;

    typedef enum logic[3:0] {
        BUILD_MATRIX,         // Set memory address
        BUILD_MATRIX_WAIT,    // Wait for memory read
        GAME_LOGIC_COUNT,     // Count neighbors for current cell
        GAME_LOGIC_UPDATE,    // Apply rules and update next_matrix
        COPY_MATRIX,          // Copy next_matrix to current_matrix
        TRANSMIT_FRAME,       // Transmit pixel values to the board
        IDLE                  // Wait before next frame
    } state_t;

    state_t current_state = BUILD_MATRIX;

    logic current_matrix [7:0][7:0]; 
    logic next_matrix [7:0][7:0];    
    logic [3:0] neighbor_count = 4'd0;
    logic [2:0] row = 0;
    logic [2:0] col = 0;
    
    // Initialize matrices to zero (all dead)
    initial begin
        for (int i = 0; i < 8; i++) begin
            for (int j = 0; j < 8; j++) begin
                current_matrix[i][j] = 1'b0;
                next_matrix[i][j] = 1'b0;
            end
        end
    end

    // Transmission control
    logic [2:0] transmit_phase = READ_CH_VALS;
    logic [5:0] pixel_counter = 6'd0;
    logic [4:0] frame_counter = 5'd0;
    logic [8:0] transmit_counter = 9'd0;
    logic [17:0] idle_counter = 18'd0;
    
    logic transmit_pixel_done;
    logic idle_done;

    assign transmit_pixel_done = (transmit_counter == TRANSMIT_CYCLES - 1);
    assign idle_done = (idle_counter == IDLE_CYCLES - 1);
    assign generation_complete = (frame_counter == MAX_FRAME_COUNT - 1);
    
    always_ff @(posedge clk) begin
        case (current_state)
            BUILD_MATRIX: begin
                // Adding one cycle delay for memory read
                current_state <= BUILD_MATRIX_WAIT;
            end
            
            BUILD_MATRIX_WAIT: begin
                // Memory data is now valid, convert RGB to life bit
                // If any color channel is non-zero, cell is alive
                if (green_data != 8'h00 || red_data != 8'h00 || blue_data != 8'h00) begin
                    current_matrix[row][col] <= 1'b1;
                end else begin
                    current_matrix[row][col] <= 1'b0;
                end
                
                // Move to next position
                if (col == 7) begin
                    col <= 0;
                    if (row == 7) begin
                        row <= 0;
                        col <= 0;
                        current_state <= TRANSMIT_FRAME; 
                        frame_counter <= 5'd0;
                    end else begin
                        row <= row + 1;
                        current_state <= BUILD_MATRIX;
                    end
                end else begin
                    col <= col + 1;
                    current_state <= BUILD_MATRIX;
                end
            end
            
            GAME_LOGIC_COUNT: begin
                // Calculate neighbor count for current cell
                neighbor_count <= 
                    (current_matrix[(row == 0) ? 7 : row - 1][(col == 0) ? 7 : col - 1] ? 1 : 0) +
                    (current_matrix[(row == 0) ? 7 : row - 1][col] ? 1 : 0) +
                    (current_matrix[(row == 0) ? 7 : row - 1][(col == 7) ? 0 : col + 1] ? 1 : 0) +
                    (current_matrix[row][(col == 0) ? 7 : col - 1] ? 1 : 0) +
                    (current_matrix[row][(col == 7) ? 0 : col + 1] ? 1 : 0) +
                    (current_matrix[(row == 7) ? 0 : row + 1][(col == 0) ? 7 : col - 1] ? 1 : 0) +
                    (current_matrix[(row == 7) ? 0 : row + 1][col] ? 1 : 0) +
                    (current_matrix[(row == 7) ? 0 : row + 1][(col == 7) ? 0 : col + 1] ? 1 : 0);
                
                current_state <= GAME_LOGIC_UPDATE;
            end
            
            GAME_LOGIC_UPDATE: begin
                // Apply Game of Life rules to next_matrix
                if (current_matrix[row][col]) begin
                    // Cell is currently alive
                    if (neighbor_count == 2 || neighbor_count == 3) begin
                        next_matrix[row][col] <= 1'b1; 
                    end else begin
                        next_matrix[row][col] <= 1'b0; 
                    end
                end else begin
                    // Cell is currently dead
                    if (neighbor_count == 3) begin
                        next_matrix[row][col] <= 1'b1; 
                    end else begin
                        next_matrix[row][col] <= 1'b0; 
                    end
                end
                
                // Move to next cell
                if (col == 7) begin
                    col <= 0;
                    if (row == 7) begin
                        // Finished calculating next generation, go to matrix copy state
                        current_state <= COPY_MATRIX;
                        row <= 0;
                        frame_counter <= 5'd0;
                    end else begin
                        row <= row + 1;
                        current_state <= GAME_LOGIC_COUNT;
                    end
                end else begin
                    col <= col + 1;
                    current_state <= GAME_LOGIC_COUNT;
                end
            end
            
            COPY_MATRIX: begin
                // Copy next_matrix to current_matrix
                current_matrix[row][col] <= next_matrix[row][col];
                
                // Move to next cell
                if (col == 7) begin
                    col <= 0;
                    if (row == 7) begin
                        // Finished copying matrix
                        current_state <= TRANSMIT_FRAME;
                        row <= 0;
                    end else begin
                        row <= row + 1;
                    end
                end else begin
                    col <= col + 1;
                end
            end
            
            TRANSMIT_FRAME: begin
                // Transmit the while frame, pixel by pixel
                case (transmit_phase)
                    READ_CH_VALS: begin
                        transmit_phase <= LOAD_SREG;
                    end
                    LOAD_SREG: begin
                        transmit_phase <= TRANSMIT_PIXEL;
                    end
                    TRANSMIT_PIXEL: begin
                        if (transmit_pixel_done) begin
                            transmit_phase <= READ_CH_VALS;
                            pixel_counter <= pixel_counter + 1;
                            if (pixel_counter == 6'd63) begin
                                pixel_counter <= 6'd0;
                                current_state <= IDLE;
                            end
                        end
                    end
                    default: begin
                        transmit_phase <= READ_CH_VALS;
                    end
                endcase
            end
            
            IDLE: begin
                // Wait time between every frame
                if (idle_done) begin
                    frame_counter <= frame_counter + 1;
                    if (generation_complete) begin
                        row <= 0;
                        col <= 0;
                        current_state <= GAME_LOGIC_COUNT;
                        frame_counter <= 5'd0;
                    end else begin
                        current_state <= TRANSMIT_FRAME;
                    end
                end
            end
            default: begin
                current_state <= BUILD_MATRIX;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (transmit_phase == TRANSMIT_PIXEL) begin
            transmit_counter <= transmit_counter + 1;
        end else begin
            transmit_counter <= 9'd0;
        end
    end

    always_ff @(posedge clk) begin
        if (current_state == IDLE) begin
            idle_counter <= idle_counter + 1;
        end else begin
            idle_counter <= 18'd0;
        end
    end

    // Convert linear pixel counter to row/col for matrix access
    logic [2:0] current_pixel_row;
    logic [2:0] current_pixel_col;
    assign current_pixel_row = pixel_counter[5:3]; // Upper 3 bits for row (0-7)
    assign current_pixel_col = pixel_counter[2:0]; // Lower 3 bits for col (0-7)

    // Output assignments
    assign mem_address = (current_state == BUILD_MATRIX || current_state == BUILD_MATRIX_WAIT) ? {row, col} : 6'd0;
    assign pixel_value = current_matrix[current_pixel_row][current_pixel_col];
    assign load_sreg = (transmit_phase == LOAD_SREG);
    assign transmit_pixel = (transmit_phase == TRANSMIT_PIXEL);

endmodule
