class FifoMonitor extends uvm_monitor;

    `uvm_component_utils(FifoMonitor)

    protected virtual FifoIf #(FIFO_DATA_WIDTH) vif_fifo;
    protected bit                                    status_valid;
    protected logic                                  pre_full;
    protected logic                                  pre_empty;
    uvm_analysis_port #(FifoItem) ap;

    function new(input string name = "FifoMonitor", input uvm_component parent = null);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(input uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual FifoIf #(FIFO_DATA_WIDTH))::get(this, "", "vif_fifo", vif_fifo)) begin
            `uvm_fatal("FIFO_MON", "virtual interface vif_fifo was not set")
        end
    endfunction

    virtual task run_phase(input uvm_phase phase);
        FifoItem item;

        status_valid = 1'b0;
        pre_full     = 1'b0;
        pre_empty    = 1'b1;

        forever begin
            @(vif_fifo.mon_cb);

            if (!vif_fifo.mon_cb.iRstn) begin
                status_valid = 1'b0;
                pre_full     = 1'b0;
                pre_empty    = 1'b1;
                continue;
            end

            if (!status_valid) begin
                pre_full     = vif_fifo.mon_cb.Full;
                pre_empty    = vif_fifo.mon_cb.Empty;
                status_valid = 1'b1;
                continue;
            end

            item = FifoItem::type_id::create("item", this);
            item.WrEn      = vif_fifo.mon_cb.Wr_En;
            item.RdEn      = vif_fifo.mon_cb.Rd_En;
            item.Data      = vif_fifo.mon_cb.iData;
            item.Full      = pre_full;
            item.Empty     = pre_empty;
            item.RData     = vif_fifo.mon_cb.oData;
            item.PostFull  = vif_fifo.mon_cb.Full;
            item.PostEmpty = vif_fifo.mon_cb.Empty;

            ap.write(item);

            pre_full  = vif_fifo.mon_cb.Full;
            pre_empty = vif_fifo.mon_cb.Empty;
        end
    endtask

endclass
