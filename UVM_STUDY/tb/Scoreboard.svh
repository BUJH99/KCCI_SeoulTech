class Top_Scoreboard extends uvm_scoreboard;

    `uvm_component_utils(Top_Scoreboard)

    // imp Receive Data from Monitor
    uvm_analysis_imp #(Top_Item, Top_Scoreboard) imp;

    bit [7:0] model [0:255];

    function new(string name, uvm_component parent);
        super.new(name, parent);
        imp = new("imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        //Golden Logic Initial Setup
        for (int i = 0; i < 256; i++) begin
            model[i] = 8'h00;
        end
    endfunction

    //Write Function
    function void write(Top_Item t);

        //Write : Making Golden
        if(t.write) begin
            model[t.addr] = t.wdata;

            `uvm_info("SCB", $sformatf("WRITE addr=0x%0h data = 0x%0h", tr.addr, tr.wdata), UVM_MEDIUM)
        end
        else begin

            //Read : Compare
            if (t.rdata !== model[t.addr]) begin
                `uvm_error("SCB", $sformatf("READ MISMATCH addr=0x%0h expected = 0x%0h actual=0x%0h", t.addr, model[t.addr], t.rdata))
            end
            else begin
                `uvm_info("SCB", $sformatf("READ PASS addr=0x%0h data = 0x%0h", t.addr, t.rdata), UVM_MEDIUM)
            end
        end
    endfunction

endclass
