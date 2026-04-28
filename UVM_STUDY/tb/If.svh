interface Top_If(
    input logic clk,
    input logic rst_n   //  externel signal -> input declare.
);

    logic       valid;
    logic       write;
    logic [7:0] addr;
    logic [7:0] rdata;
    logic [7:0] wdata;
    logic       ready;

    // default input #1step sampling * output #0 acting;
    clocking drv_cb @(posedge clk); // Seqeunce -> DUT
        output valid;
        output write;
        output addr;
        output wdata;
        input ready;
        input rdata;
    endclocking

    clocking mon_cb @(posedge clk); // only Observation / Output : Bus (x) Analysis Port (o)
        input rst_n;
        input valid;
        input write;
        input addr;
        input wdata;
        input rdata;
        input ready;
    endclocking


endinterface
