class FifoAgent extends uvm_agent;

    `uvm_component_utils(FifoAgent)

    FifoSequencer sequencer;
    FifoDriver    driver;
    FifoMonitor   monitor;

    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name = "FifoAgent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        void'(uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active));

        monitor = FifoMonitor::type_id::create("monitor", this);

        if (is_active == UVM_ACTIVE) begin
            sequencer = FifoSequencer::type_id::create("sequencer", this);
            driver    = FifoDriver::type_id::create("driver", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction

endclass
