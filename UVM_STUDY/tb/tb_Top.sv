module tb_Top;

    import uvm_pkg::*;
    import Top_pkg::*;

    logic clk;
    logic rst_n;

    Top_If vif(
        .clk    (clk),
        .rst_n  (rst_n)
    );

    Top dut(
        .clk    (clk),
        .rst_n  (vif.rst_n),
        .valid  (vif.valid),
        .write  (vif.write),
        .addr   (vif.addr),
        .wdata  (vif.wdata),
        .rdata  (vif.rdata),
        .ready  (vif.ready)
    );

    Assertions u_assert(
        .vif    (vif)
    );


    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
       rst_n = 1'b0;
       repeat (5) @(posedge clk);
       rst_n = 1'b1;
    end

    initial begin
        uvm_config_db#(virtual Top_If)::set(null, "*", "vif", vif);

        run_test("Top_Test");
    end
endmodule
