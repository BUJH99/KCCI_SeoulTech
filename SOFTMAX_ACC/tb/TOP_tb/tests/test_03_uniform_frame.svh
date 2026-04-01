`ifndef TOP_TEST_03_UNIFORM_FRAME_SVH
`define TOP_TEST_03_UNIFORM_FRAME_SVH

class TopTest03UniformFrame extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_03_uniform_frame");
    endfunction

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
        int lengths[7];
        int idx;
        int beatIdx;
    begin
        lengths[0] = 2;
        lengths[1] = 3;
        lengths[2] = 5;
        lengths[3] = 7;
        lengths[4] = 16;
        lengths[5] = 63;
        lengths[6] = 64;
        for (idx = 0; idx < 7; idx++) begin
            values.delete();
            for (beatIdx = 0; beatIdx < lengths[idx]; beatIdx++)
                values.push_back(fp32_bits(0.75));
            txItem = create_frame(
                $sformatf("uniform_len_%0d", lengths[idx]),
                TOP_INPUT_CLASS_UNIFORM,
                TOP_TERM_ILAST_ONLY,
                TOP_STALL_NONE,
                TOP_STALL_LIGHT,
                TOP_KEEP_ALL_F,
                TOP_RESULT_NORMAL
            );
            append_values(txItem, values);
            m_env.m_generator.add_frame(txItem);
        end
    end
    endtask
endclass

`endif
