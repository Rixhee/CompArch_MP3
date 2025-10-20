
module memory #(
    parameter INIT_FILE = ""
)(
    input logic clk,
    input logic [5:0] read_address,
    output logic [7:0] matrix [0:7][0:7],
    output logic init_done
);

    logic [7:0] mem [0:63];
    logic [2: 0] row_counter = 0;  // 3 bits for 0-7
    logic [2: 0] col_counter = 0;  // 3 bits for 0-7
    logic [5: 0] val_counter = 0;  // 6 bits for 0-63
    logic [0:0] initializing = 1;

    initial if (INIT_FILE) begin
        $readmemh(INIT_FILE, mem);
    end

    always_ff @(posedge clk) begin
        if (initializing) begin
           matrix[row_counter][col_counter] <= mem[val_counter];

           if (col_counter == 7) begin 
                col_counter <= 0;
                row_counter <= row_counter + 1;
           end else begin
                col_counter <= col_counter + 1;
           end

           if (val_counter == 63) begin
                initializing <= 0;
           end else begin
                val_counter <= val_counter + 1;
           end
        end
    end

    assign init_done = ~initializing;

endmodule
