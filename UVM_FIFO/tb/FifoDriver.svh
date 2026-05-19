class FifoDriver extends uvm_driver #(FifoItem);

    `uvm_component_utils(FifoDriver)

    protected virtual FifoIf #(FIFO_DATA_WIDTH) vif_fifo;

    function new(input string name = "FifoDriver", input uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(input uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(virtual FifoIf #(FIFO_DATA_WIDTH))::get(this, "", "vif_fifo", vif_fifo)) begin
            `uvm_fatal("FIFO_DRV", "virtual interface vif_fifo was not set")
        end
    endfunction

    virtual task run_phase(input uvm_phase phase);
        FifoItem item;

        drive_idle();
        wait_for_reset_release();

        forever begin
            seq_item_port.get_next_item(item);
            drive_item(item);
            seq_item_port.item_done();
        end
    endtask

    protected virtual task drive_idle();
        vif_fifo.drv_cb.iData <= '0;
        vif_fifo.drv_cb.Wr_En <= 1'b0;
        vif_fifo.drv_cb.Rd_En <= 1'b0;
    endtask

    protected virtual task wait_for_reset_release();
        wait (vif_fifo.iRstn === 1'b1);
        @(vif_fifo.drv_cb);
    endtask

    protected virtual task drive_item(input FifoItem item);
        repeat (item.IdleCycles) begin
            @(vif_fifo.drv_cb);
            drive_idle();
        end

        @(vif_fifo.drv_cb);
        vif_fifo.drv_cb.iData <= item.Data;
        vif_fifo.drv_cb.Wr_En <= item.WrEn;
        vif_fifo.drv_cb.Rd_En <= item.RdEn;

        @(vif_fifo.drv_cb);
        drive_idle();
    endtask
endclass
