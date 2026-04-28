class Top_Test extends uvm_test;

    `uvm_component_utils(Top_Test)

    Top_Env env;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    //build :  create env
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        env = Top_Env::type_id::create("env", this);
    endfunction

    //run : Objection Mechanism, create Seq, seq Start
    task run_phase(uvm_phase phase);
        Top_Seq seq;

        //Do not finish simulation yet
        phase.raise_objection(this);

        //create Seq
        seq = Top_Seq::type_id::create("seq");

        //seq Start Rule : sequence.start(Hierarchy)
        seq.start(env.agent.Sequencer);

        //Finish simulation after scenario done
        phase.drop_objection(this);
    endtask

endclass
