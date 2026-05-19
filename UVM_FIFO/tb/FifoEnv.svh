class FifoEnv extends uvm_env;

    `uvm_component_utils(FifoEnv)

    FifoAgent      agent;
    FifoScoreboard scoreboard;
    FifoCoverage   coverage;

    function new(string name = "FifoEnv", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(input uvm_phase phase);
        super.build_phase(phase);

        agent      = FifoAgent::type_id::create("agent", this);
        scoreboard = FifoScoreboard::type_id::create("scoreboard", this);
        coverage   = FifoCoverage::type_id::create("coverage", this);
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        agent.monitor.ap.connect(scoreboard.imp);
        agent.monitor.ap.connect(coverage.analysis_export);
    endfunction

endclass
