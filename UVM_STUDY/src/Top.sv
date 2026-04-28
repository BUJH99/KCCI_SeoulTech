module Top(
        input logic        clk,
        input logic        rst_n,

        input logic        valid,
        input logic        write,
        input logic [7:0]  addr,
        input logic [7:0]  wdata,
        output logic [7:0] rdata,
        output logic       ready
);

        logic [7:0] mem [0:255];

        assign ready = 1'b1;

        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                rdata <= 8'h00;
                for (int i=0; i < 256; i++) begin
                    mem[i] <= 8'h00;
                end
            end
            else if (valid && ready) begin
                if (write) begin
                    mem [addr] <= wdata;
                end
                else begin
                    rdata <= mem[addr];
                end
            end
        end
endmodule
