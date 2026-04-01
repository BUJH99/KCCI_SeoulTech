`ifndef TOP_TEST_05_BACKPRESSURE_PROTOCOL_SVH
`define TOP_TEST_05_BACKPRESSURE_PROTOCOL_SVH

class TopTest05BackpressureProtocol extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_05_backpressure_protocol");
    endfunction

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
        bit readyPattern[$];
    begin
        values = {};
        values.push_back(fp32_bits(1.0));
        values.push_back(fp32_bits(0.0));
        values.push_back(fp32_bits(-1.0));
        values.push_back(fp32_bits(2.0));
        txItem = create_frame("bp_light_alt", TOP_INPUT_CLASS_MIXED_SIGN, TOP_TERM_ILAST_ONLY, TOP_STALL_LIGHT, TOP_STALL_ALTERNATE, TOP_KEEP_ALL_F, TOP_RESULT_PROTOCOL);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(fp32_bits(0.5));
        values.push_back(fp32_bits(0.25));
        values.push_back(fp32_bits(-0.25));
        values.push_back(fp32_bits(-0.75));
        values.push_back(fp32_bits(1.25));
        txItem = create_frame("bp_heavy_heavy", TOP_INPUT_CLASS_MIXED_SIGN, TOP_TERM_ILAST_ONLY, TOP_STALL_HEAVY, TOP_STALL_HEAVY, TOP_KEEP_ALL_F, TOP_RESULT_PROTOCOL);
        append_values(txItem, values);
        m_env.m_generator.add_frame(txItem);

        values = {};
        values.push_back(fp32_bits(-0.5));
        values.push_back(fp32_bits(0.5));
        values.push_back(fp32_bits(1.5));
        values.push_back(fp32_bits(-1.5));
        txItem = create_frame("bp_scripted", TOP_INPUT_CLASS_MIXED_SIGN, TOP_TERM_ILAST_ONLY, TOP_STALL_SCRIPTED, TOP_STALL_SCRIPTED, TOP_KEEP_ALL_F, TOP_RESULT_PROTOCOL);
        append_values(txItem, values);
        txItem.m_input_gap_cycles.delete();
        txItem.m_input_gap_cycles.push_back(0);
        txItem.m_input_gap_cycles.push_back(1);
        txItem.m_input_gap_cycles.push_back(0);
        txItem.m_input_gap_cycles.push_back(2);
        readyPattern.push_back(1'b1);
        readyPattern.push_back(1'b0);
        readyPattern.push_back(1'b0);
        readyPattern.push_back(1'b1);
        readyPattern.push_back(1'b1);
        readyPattern.push_back(1'b0);
        readyPattern.push_back(1'b1);
        txItem.set_sink_script(readyPattern);
        m_env.m_generator.add_frame(txItem);
    end
    endtask
endclass

`endif
