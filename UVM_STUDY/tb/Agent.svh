class Top_Agent extends uvm_agent;

    `uvm_component_utils(Top_Agent)

    //Agent Component
    Top_Sequencer Sequencer;
    Top_Driver    Driver;
    Top_Monitor   Monitor;

    //enum : Active or Passive
    uvm_active_passive_enum is_active = UVM_ACTIVE;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //build :  create Sequencer, Driver, Monitor
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Get setting in config_db
        void'(uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active));

        //ClassName::type_id::create("InstacneName", Parent Component)

        // Always Create : Active * Passive
        Monitor   = Top_Monitor  ::type_id::create("Monitor",   this);

        // IF Active, create
        if (is_active == UVM_ACTIVE) begin
            Sequencer = Top_Sequencer::type_id::create("Sequencer", this);
            Driver    = Top_Driver   ::type_id::create("Driver",    this);
        end
    endfunction

    //connect = Connect, TLM Export
    function void connect_phase (uvm_phase phase);
        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE) begin
        //TLM Export : Seqeuncer -> Driver
            Driver.seq_item_port.connect(Sequencer.seq_item_export);
        end
    endfunction
endclass
