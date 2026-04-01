`ifndef TOP_TEST_02_SVH
`define TOP_TEST_02_SVH

class TopTest02 extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP);
    endfunction

    virtual task configure();
        super.configure();
        m_cfg.m_num_transactions = 32;
        m_cfg.m_verbose = 1'b0;
    endtask
endclass

`endif
