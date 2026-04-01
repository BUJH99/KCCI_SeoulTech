`ifndef TOP_TEST_01_SVH
`define TOP_TEST_01_SVH

class TopTest01 extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP);
    endfunction

    virtual task configure();
        super.configure();
        m_cfg.m_num_transactions = 200;
    endtask
endclass

`endif
