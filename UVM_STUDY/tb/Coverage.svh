class Top_Coverage extends uvm_subscriber #(Top_Item);

    `uvm_component_utils(Top_Coverage)

    //Sample Variables
    bit       sample_write;
    bit [7:0] sample_addr;
    bit [7:0] sample_wdata;
    bit [7:0] sample_rdata;

    covergroup bus_cg;
        // separately Collect per covergroup instance
        option.per_instance = 1;

        // Read / Write Coverage
        cp_write : coverpoint sample_write {
            bins read  = {0};
            bins write = {1};
        }

        // Addr Coverage
        cp_addr : coverpoint sample_addr{
            bins low      = {[8'h00:8'h3F]};
            bins mid      = {[8'h40:8'hBF]};
            bins high     = {[8'hC0:8'hFB]};
            bins boundary = {8'h00, 8'h3F, 8'h40, 8'hBF, 8'hC0, 8'hFF};
            illegal_bins illegal_addr = {[8'hFC:8'hFF]};
        }

        // Write Data pattern coverage
        cp_wdata : coverpoint sample_wdata iff (sample_write) {
            bins zero     = {8'h00};
            bins all_one  = {8'hFF};
            bins pattern_a = {8'hAA};
            bins pattern_5 = {8'h55};
            bins others    = default;
        }
        // Read Data pattern coverage
        cp_rdata : coverpoint sample_rdata iff (!sample_write) {
            bins zero     = {8'h00};
            bins all_one  = {8'hFF};
            bins pattern_a = {8'hAA};
            bins pattern_5 = {8'h55};
            bins others    = default;
            ignore_bins ignored_rdata = {8'hEE};
        }

        //Cross Coverage
        cross_rw_addr : cross cp_write, cp_addr;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        bus_cg=new();
    endfunction

    function void write(Top_Item t);

        //cg Data Mapping from Monitor
        sample_write = t.write;
        sample_addr  = t.addr;
        sample_wdata = t.wdata;
        sample_rdata = t.rdata;

        //Built-in Method : .sample() - capture
        bus_cg.sample();

        //Log Text
        `uvm_info("COV", $sformatf("Sampled coverage : write=%0b addr=0x%0h wdata=0x%0h rdata=0x%0h", 
                    sample_write, sample_addr, sample_wdata, sample_rdata), UVM_HIGH)
    endfunction

endclass
