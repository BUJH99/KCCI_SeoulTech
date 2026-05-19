typedef enum int unsigned {
    BasicMode,
    RandomMode
} SeqMode;

class FifoSeq extends uvm_sequence #(FifoItem);

    int unsigned ItemCount = 200;
    SeqMode      Mode      = BasicMode;

    `uvm_object_utils_begin(FifoSeq)
        `uvm_field_enum(SeqMode, Mode, UVM_ALL_ON)
        `uvm_field_int(ItemCount, UVM_ALL_ON | UVM_DEC)
    `uvm_object_utils_end

    function new(input string name = "FifoSeq");
        super.new(name);
    endfunction

    virtual task body();
        case (Mode)
            BasicMode: begin
                run_basic_seq();
            end

            RandomMode: begin
                run_random_seq();
            end

            default: begin
                `uvm_fatal("FIFO_SEQ", $sformatf("Unknown FifoSeq mode: %0d", Mode))
            end
        endcase
    endtask

    protected virtual task run_basic_seq();

        //Write
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            send_item(1'b1, 1'b0, i % (1 << FIFO_DATA_WIDTH), 0);
        end

        //Read
        send_item(1'b1, 1'b0, 'hF, 0);

        //Overflow
        for (int i = 0; i < FIFO_DEPTH; i++) begin
            send_item(1'b0, 1'b1, '0, 0);
        end

        //Underflow
        send_item(1'b0, 1'b1, '0, 1);

        //Write, Read
        send_item(1'b1, 1'b0, 'hA, 0);
        send_item(1'b1, 1'b0, 'h5, 0);
        send_item(1'b1, 1'b1, 'hC, 0);
        send_item(1'b1, 1'b1, 'h3, 0);
        send_item(1'b0, 1'b1, '0, 0);
        send_item(1'b0, 1'b1, '0, 0);
    endtask

    protected virtual task run_random_seq();
        FifoItem item;

        repeat (ItemCount) begin
            item = FifoItem::type_id::create("item");
            start_item(item);
            if (!item.randomize()) begin
                `uvm_error("FIFO_SEQ", "FifoItem randomization failed")
            end
            finish_item(item);
        end
    endtask

    protected virtual task send_item(
        input bit                       WrEn,
        input bit                       RdEn,
        input bit [FIFO_DATA_WIDTH-1:0] Data,
        input int unsigned              IdleCycles
    );
        FifoItem item;

        item = FifoItem::type_id::create("item");
        start_item(item);
        item.WrEn       = WrEn;
        item.RdEn       = RdEn;
        item.Data       = Data;
        item.IdleCycles = IdleCycles;
        finish_item(item);
    endtask

endclass
