`ifndef TOP_TEST_02_SINGLETON_FRAME_SVH
`define TOP_TEST_02_SINGLETON_FRAME_SVH

class TopTest02SingletonFrame extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_02_singleton_frame");
    endfunction

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
    begin
        values.push_back(fp32_bits(1.0));
        txItem = create_frame(
            "singleton_frame",
            TOP_INPUT_CLASS_DOMINANT_PEAK,
            TOP_TERM_ILAST_ONLY,
            TOP_STALL_NONE,
            TOP_STALL_NONE,
            TOP_KEEP_ALL_F,
            TOP_RESULT_NORMAL
        );
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);
    end
    endtask
endclass

`endif
