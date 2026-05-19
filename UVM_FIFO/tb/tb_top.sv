`timescale 1ns / 1ps

module TbTop;

    import uvm_pkg::*;
    import fifo_uvm_pkg::*;

    localparam time LP_CLK_PERIOD = 10ns;
    localparam time LP_SIM_TIMEOUT = 100us;

    logic iClk;
    logic iRstn;

    FifoIf #(
        .Width(FIFO_DATA_WIDTH)
    ) vif_fifo (
        .iClk  (iClk),
        .iRstn (iRstn)
    );

    Top #(
        .Width (FIFO_DATA_WIDTH),
        .Depth (FIFO_DEPTH)
    ) dut (
        .iData (vif_fifo.iData),
        .Wr_En (vif_fifo.Wr_En),
        .Rd_En (vif_fifo.Rd_En),
        .iClk  (iClk),
        .iRstn (iRstn),
        .oData (vif_fifo.oData),
        .Full  (vif_fifo.Full),
        .Empty (vif_fifo.Empty)
    );

    FifoAssertions assertions (
        .vif_fifo (vif_fifo)
    );

    initial begin : p_clk_gen
        iClk = 1'b0;
        forever #(LP_CLK_PERIOD / 2) iClk = ~iClk;
    end

    initial begin : p_rst_gen
        iRstn = 1'b0;
        repeat (5) @(posedge iClk);
        iRstn = 1'b1;
    end

    initial begin : p_timeout
        #(LP_SIM_TIMEOUT);
        $fatal(1, "FIFO UVM simulation timeout");
    end

    initial begin : p_wave_dump
        $dumpfile("output/vcs/fifo_uvm.vcd");
        $dumpvars(0, TbTop);

`ifdef FSDB
        $fsdbDumpfile("output/vcs/fifo_uvm.fsdb");
        $fsdbDumpvars(0, TbTop);
`endif
    end

    initial begin : p_run_uvm
        uvm_config_db#(virtual FifoIf #(FIFO_DATA_WIDTH))::set(
            null,
            "*",
            "vif_fifo",
            vif_fifo
        );

        run_test("FifoTest");
    end

endmodule
