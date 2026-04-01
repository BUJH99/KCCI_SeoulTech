`ifndef TOP_TEST_06_FRAME_BOUNDARY_CMAX_SVH
`define TOP_TEST_06_FRAME_BOUNDARY_CMAX_SVH

class TopTest06FrameBoundaryCmax extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_06_frame_boundary_cmax");
    endfunction

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
        int idx;
    begin
        values = {};
        values.push_back(fp32_bits(0.25));
        values.push_back(fp32_bits(-0.25));
        txItem = create_frame("boundary_len2", TOP_INPUT_CLASS_MIXED_SIGN, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_NONE);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        for (idx = 0; idx < (m_cfg.m_max_frame_len - 1); idx++)
            values.push_back(fp32_bits((idx % 2) ? 0.25 : -0.25));
        txItem = create_frame("boundary_len_cmax_minus_1", TOP_INPUT_CLASS_UNIFORM, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_LIGHT);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        for (idx = 0; idx < m_cfg.m_max_frame_len; idx++)
            values.push_back(fp32_bits(0.0));
        txItem = create_frame("boundary_cmax_only", TOP_INPUT_CLASS_UNIFORM, TOP_TERM_CMAX_ONLY, TOP_STALL_NONE, TOP_STALL_NONE);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);
    end
    endtask
endclass

`endif
