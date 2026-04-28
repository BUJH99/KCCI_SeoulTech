class Top_Env extends uvm_env;

    `uvm_component_utils(Top_Env)

    Top_Agent      agent;
    Top_Scoreboard scoreboard;
    Top_Coverage   coverage;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        agent      = Top_Agent      ::type_id::create("agent",     this);
        scoreboard = Top_Scoreboard ::type_id::create("scoreboard",this);
        coverage   = Top_Coverage   ::type_id::create("coverage",  this);
    endfunction

    //connect Agent, Scoreboard
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        //TLM : Sendport.connect.(Receiveport)
        agent.Monitor.ap.connect(scoreboard.imp);
        agent.Monitor.ap.connect(coverage.analysis_export);
    endfunction

endclass
