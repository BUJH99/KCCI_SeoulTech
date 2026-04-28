class Top_Monitor extends uvm_monitor;

    `uvm_component_utils(Top_Monitor)

    virtual Top_If vif;

    //ap Transnfer Data to Scoreboard, coverage collector
    uvm_analysis_port #(Top_Item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this); //Gen ap
    endfunction

    //Reuse : build_phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if(!uvm_config_db#(virtual Top_If)::get(this, "", "vif", vif)) begin
             `uvm_fatal("MON", "virtual interface not found")
        end
    endfunction

    // Monitoring Logic
    task run_phase(uvm_phase phase);
    Top_Item t;

    forever begin
       @(vif.mon_cb);

       if(!vif.mon_cb.rst_n) begin
            continue;
       end

       if(vif.mon_cb.valid && vif.mon_cb.ready) begin
        //Look at the signal -> Make a new t
        t = Top_Item::type_id::create("t");

        //Store the Signal Values into t
        t.write = vif.mon_cb.write;
        t.addr  = vif.mon_cb.addr;
        t.wdata = vif.mon_cb.wdata;
        t.rdata = vif.mon_cb.rdata;

        //Transfer to other component
        ap.write(t);
       end

    end
    endtask

endclass
