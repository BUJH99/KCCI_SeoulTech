class Top_Driver extends uvm_driver #(Top_Item);

    `uvm_component_utils(Top_Driver)

    // Possible to Connect at Runtime
    virtual Top_If vif;

    //Component -> name & parent
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //build : Get to cf_db
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        //#(Type)::get(Req Component, Ins Route, Data key name, Store to Variable)
        if(!uvm_config_db#(virtual Top_If)::get(this, "", "vif", vif)) begin
            //uvm error macro
            `uvm_fatal("DRV", "virtual interface not found");
        end
    endfunction

    //run : Communication [TLM] *SW Role
    task run_phase(uvm_phase phase);
        Top_Item t;

        vif.drv_cb.valid <= 1'b0;
        vif.drv_cb.write <= 1'b0;
        vif.drv_cb.addr <= '0;
        vif.drv_cb.wdata <= '0;

        forever begin
            seq_item_port.get_next_item(t);

            drive_one_transfer(t);

            seq_item_port.item_done();
        end
    endtask

    //HW Rule : Control to Signal
    task drive_one_transfer(Top_Item t);

    //Initial Driving at First Edge
    @(vif.drv_cb);
    vif.drv_cb.valid <= 1'b1;
    vif.drv_cb.write <= t.write;
    vif.drv_cb.addr  <= t.addr;
    vif.drv_cb.wdata <= t.wdata;

    //Loop
    do begin
        @(vif.drv_cb);
    end while (!vif.drv_cb.ready);

    // Exit Loop
    t.rdata = vif.drv_cb.rdata;

    vif.drv_cb.valid <= 1'b0;
    vif.drv_cb.write <= 1'b0;
    vif.drv_cb.addr  <= '0;
    vif.drv_cb.wdata <= '0;

    endtask

endclass
