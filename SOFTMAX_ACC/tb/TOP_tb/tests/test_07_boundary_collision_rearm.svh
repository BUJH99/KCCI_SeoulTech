`ifndef TOP_TEST_07_BOUNDARY_COLLISION_REARM_SVH
`define TOP_TEST_07_BOUNDARY_COLLISION_REARM_SVH

class TopTest07BoundaryCollisionRearm extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_07_boundary_collision_rearm");
    endfunction

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
        int idx;
    begin
        values = {};
        for (idx = 0; idx < m_cfg.m_max_frame_len; idx++)
            values.push_back(fp32_bits((idx % 4) * 0.125));
        txItem = create_frame(
            "collision_len_cmax",
            TOP_INPUT_CLASS_DOMINANT_PEAK,
            TOP_TERM_ILAST_AND_CMAX,
            TOP_STALL_NONE,
            TOP_STALL_LIGHT,
            TOP_KEEP_ALL_F,
            TOP_RESULT_NORMAL,
            TOP_RESET_PHASE_NONE,
            TOP_POST_TERM_BACK_TO_BACK
        );
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(fp32_bits(1.0));
        values.push_back(fp32_bits(0.0));
        values.push_back(fp32_bits(-1.0));
        txItem = create_frame(
            "rearm_back_to_back",
            TOP_INPUT_CLASS_MIXED_SIGN,
            TOP_TERM_ILAST_ONLY,
            TOP_STALL_NONE,
            TOP_STALL_NONE,
            TOP_KEEP_ALL_F,
            TOP_RESULT_NORMAL,
            TOP_RESET_PHASE_NONE,
            TOP_POST_TERM_BACK_TO_BACK
        );
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(fp32_bits(-0.5));
        values.push_back(fp32_bits(0.25));
        values.push_back(fp32_bits(0.75));
        txItem = create_frame(
            "rearm_delayed",
            TOP_INPUT_CLASS_MIXED_SIGN,
            TOP_TERM_ILAST_ONLY,
            TOP_STALL_LIGHT,
            TOP_STALL_NONE,
            TOP_KEEP_ALL_F,
            TOP_RESULT_NORMAL,
            TOP_RESET_PHASE_NONE,
            TOP_POST_TERM_DELAYED
        );
        append_values(txItem, values);
        set_uniform_gap(txItem, 1);
        m_env.m_generator.add_frame(txItem);
    end
    endtask
endclass

`endif
