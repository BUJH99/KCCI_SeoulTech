class Top_Sequencer extends uvm_sequencer #(Top_Item);

    `uvm_component_utils(Top_Sequencer)

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
