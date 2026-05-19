class FifoSequencer extends uvm_sequencer #(FifoItem);

    `uvm_component_utils(FifoSequencer)

    function new(string name = "FifoSequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction

endclass
