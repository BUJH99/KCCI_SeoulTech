class FifoTest extends uvm_test;

    `uvm_component_utils(FifoTest)

    FifoEnv env;

    function new(string name = "FifoTest", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = FifoEnv::type_id::create("env", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        FifoSeq seq;

        phase.raise_objection(this);

        seq = FifoSeq::type_id::create("seq");
        seq.ItemCount = 200;
        seq.Mode      = BasicMode;
        seq.start(env.agent.sequencer);

        repeat (5) begin
            #10ns;
        end

        phase.drop_objection(this);
    endtask

endclass
