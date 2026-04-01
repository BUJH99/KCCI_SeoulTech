`ifndef TOP_TEST_09_SPECIAL_FP32_POLICY_SVH
`define TOP_TEST_09_SPECIAL_FP32_POLICY_SVH

class TopTest09SpecialFp32Policy extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_09_special_fp32_policy");
    endfunction

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
    begin
        values = {};
        values.push_back(32'h0000_0000);
        values.push_back(fp32_bits(0.5));
        txItem = create_frame("special_zero", TOP_INPUT_CLASS_SPECIAL_EXP, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_NONE, TOP_KEEP_ALL_F, TOP_RESULT_SPECIAL, TOP_RESET_PHASE_NONE, TOP_POST_TERM_DELAYED, TOP_SPECIAL_ZERO);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(32'h7f7f_ffff);
        values.push_back(32'hff7f_ffff);
        txItem = create_frame("special_large_finite_pair", TOP_INPUT_CLASS_SPECIAL_EXP, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_LIGHT, TOP_KEEP_ALL_F, TOP_RESULT_SPECIAL, TOP_RESET_PHASE_NONE, TOP_POST_TERM_DELAYED, TOP_SPECIAL_LARGE_FINITE);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(32'h7f80_0000);
        values.push_back(32'hbf80_0000);
        txItem = create_frame("special_pos_inf_pair", TOP_INPUT_CLASS_SPECIAL_EXP, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_NONE, TOP_KEEP_ALL_F, TOP_RESULT_SPECIAL, TOP_RESET_PHASE_NONE, TOP_POST_TERM_DELAYED, TOP_SPECIAL_POS_INF);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(32'hff80_0000);
        values.push_back(32'h3f80_0000);
        txItem = create_frame("special_neg_inf_pair", TOP_INPUT_CLASS_SPECIAL_EXP, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_LIGHT, TOP_KEEP_ALL_F, TOP_RESULT_SPECIAL, TOP_RESET_PHASE_NONE, TOP_POST_TERM_DELAYED, TOP_SPECIAL_NEG_INF);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(32'h7fc0_0001);
        values.push_back(32'h7fc0_1000);
        txItem = create_frame("special_qnan_pair", TOP_INPUT_CLASS_SPECIAL_EXP, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_NONE, TOP_KEEP_ALL_F, TOP_RESULT_SPECIAL, TOP_RESET_PHASE_NONE, TOP_POST_TERM_DELAYED, TOP_SPECIAL_QNAN);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(32'h7f80_0001);
        values.push_back(32'h7f80_0002);
        txItem = create_frame("special_snan_pair", TOP_INPUT_CLASS_SPECIAL_EXP, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_LIGHT, TOP_KEEP_ALL_F, TOP_RESULT_SPECIAL, TOP_RESET_PHASE_NONE, TOP_POST_TERM_DELAYED, TOP_SPECIAL_SNAN);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);
    end
    endtask
endclass

`endif
