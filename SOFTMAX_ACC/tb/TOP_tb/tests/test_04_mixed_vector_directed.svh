`ifndef TOP_TEST_04_MIXED_VECTOR_DIRECTED_SVH
`define TOP_TEST_04_MIXED_VECTOR_DIRECTED_SVH

class TopTest04MixedVectorDirected extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_04_mixed_vector_directed");
    endfunction

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
    begin
        values = {};
        values.push_back(fp32_bits(2.0));
        values.push_back(fp32_bits(0.5));
        values.push_back(fp32_bits(-0.5));
        values.push_back(fp32_bits(-1.0));
        txItem = create_frame("mixed_max_first", TOP_INPUT_CLASS_MIXED_SIGN, TOP_TERM_ILAST_ONLY, TOP_STALL_LIGHT, TOP_STALL_NONE);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(fp32_bits(-2.0));
        values.push_back(fp32_bits(1.0));
        values.push_back(fp32_bits(2.25));
        values.push_back(fp32_bits(0.25));
        txItem = create_frame("mixed_max_middle", TOP_INPUT_CLASS_MIXED_SIGN, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_LIGHT);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(fp32_bits(-1.5));
        values.push_back(fp32_bits(-0.25));
        values.push_back(fp32_bits(0.75));
        values.push_back(fp32_bits(2.5));
        txItem = create_frame("mixed_max_last", TOP_INPUT_CLASS_MIXED_SIGN, TOP_TERM_ILAST_ONLY, TOP_STALL_LIGHT, TOP_STALL_LIGHT);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(fp32_bits(0.1250));
        values.push_back(fp32_bits(0.1328));
        values.push_back(fp32_bits(0.1250));
        txItem = create_frame("near_equal_middle", TOP_INPUT_CLASS_NEAR_EQUAL, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_NONE);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(fp32_bits(0.1001));
        values.push_back(fp32_bits(0.1002));
        values.push_back(fp32_bits(0.1000));
        txItem = create_frame("near_equal_tie", TOP_INPUT_CLASS_NEAR_EQUAL, TOP_TERM_ILAST_ONLY, TOP_STALL_NONE, TOP_STALL_NONE);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);
    end
    endtask
endclass

`endif
