class Top_Item extends uvm_sequence_item; //Using a libraray

    //(X) Porotcol HandShake Signal, Clk, Rst, Phy Layer
    //DUT Signal
    rand bit        write;
    rand bit [7:0]  addr;
    rand bit [7:0]  wdata;
    rand bit [7:0]  rdata;

    //Register to UVM Factory
    `uvm_object_utils_begin(Top_Item)
        `uvm_field_int(write, UVM_ALL_ON)
        `uvm_field_int(addr, UVM_ALL_ON)
        `uvm_field_int(wdata, UVM_ALL_ON)
        `uvm_field_int(rdata, UVM_ALL_ON)
    `uvm_object_utils_end

    // Object -> name & No Parent
    function new(string name = "Top_Item");
        super.new(name);
    endfunction

endclass
