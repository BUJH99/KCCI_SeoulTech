class FifoItem extends uvm_sequence_item;

    rand bit                         WrEn;
    rand bit                         RdEn;
    rand bit [FIFO_DATA_WIDTH-1:0]   Data;
    rand int unsigned                IdleCycles;

    logic [FIFO_DATA_WIDTH-1:0]      RData;
    logic                            Full;
    logic                            Empty;
    logic                            PostFull;
    logic                            PostEmpty;

    constraint c_idle_cycles {
        IdleCycles inside {[0:2]};
    }

    constraint c_command_mix {
        {WrEn, RdEn} dist {
            2'b10 := 35,
            2'b01 := 35,
            2'b11 := 20,
            2'b00 := 10
        };
    }

    `uvm_object_utils_begin(FifoItem)
        `uvm_field_int(WrEn,       UVM_ALL_ON)
        `uvm_field_int(RdEn,       UVM_ALL_ON)
        `uvm_field_int(Data,       UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(IdleCycles, UVM_ALL_ON | UVM_DEC)
        `uvm_field_int(RData,      UVM_ALL_ON | UVM_HEX)
        `uvm_field_int(Full,       UVM_ALL_ON)
        `uvm_field_int(Empty,      UVM_ALL_ON)
        `uvm_field_int(PostFull,   UVM_ALL_ON)
        `uvm_field_int(PostEmpty,  UVM_ALL_ON)
    `uvm_object_utils_end

    function new(input string name = "FifoItem");
        super.new(name);
    endfunction

    virtual function string convert2string();
        return $sformatf(
            "WrEn=%0b RdEn=%0b Data=0x%0h RData=0x%0h Full=%0b Empty=%0b PostFull=%0b PostEmpty=%0b IdleCycles=%0d",
            WrEn,
            RdEn,
            Data,
            RData,
            Full,
            Empty,
            PostFull,
            PostEmpty,
            IdleCycles
        );
    endfunction

endclass
