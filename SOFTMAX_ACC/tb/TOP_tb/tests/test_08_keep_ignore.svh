`ifndef TOP_TEST_08_KEEP_IGNORE_SVH
`define TOP_TEST_08_KEEP_IGNORE_SVH

class TopTest08KeepIgnore extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_08_keep_ignore");
    endfunction

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
        TopKeepKindE keepKinds[4];
        int idx;
    begin
        values = {};
        values.push_back(fp32_bits(1.5));
        values.push_back(fp32_bits(-0.5));
        values.push_back(fp32_bits(0.25));
        values.push_back(fp32_bits(0.75));
        keepKinds[0] = TOP_KEEP_ALL_F;
        keepKinds[1] = TOP_KEEP_ALT;
        keepKinds[2] = TOP_KEEP_ZERO;
        keepKinds[3] = TOP_KEEP_RANDOM;

        for (idx = 0; idx < 4; idx++) begin
            txItem = create_frame(
                $sformatf("keep_mode_%0d", idx),
                TOP_INPUT_CLASS_MIXED_SIGN,
                TOP_TERM_ILAST_ONLY,
                TOP_STALL_NONE,
                TOP_STALL_LIGHT,
                keepKinds[idx],
                TOP_RESULT_KEEP_IGNORE
            );
            append_values(txItem, values);
            txItem.apply_keep_kind();
            m_env.m_generator.add_frame(txItem);
        end
    end
    endtask
endclass

`endif
