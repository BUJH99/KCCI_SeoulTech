`ifndef TOP_TEST_01_RESET_MATRIX_SVH
`define TOP_TEST_01_RESET_MATRIX_SVH

class TopTest01ResetMatrix extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_01_reset_matrix");
    endfunction

    task automatic inject_reset_when_output_pipeline_active(input int unsigned iCycles = 2);
        int unsigned guardCycles;
        bit hitOutputPath;
    begin
        guardCycles = 0;
        hitOutputPath = 1'b0;
        while ((guardCycles < 2048) && !hitOutputPath) begin
            @(posedge vif_TOP.iClk);
            if (vif_TOP.oMAxisValid || vif_TOP.probe_u16_fp32_valid || vif_TOP.probe_exp_out_valid)
                hitOutputPath = 1'b1;
            guardCycles++;
        end

        m_env.m_driver.pulse_reset_cycles(iCycles);
    end
    endtask

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
        int frameIdx;
    begin
        for (frameIdx = 0; frameIdx < 8; frameIdx++) begin
            values.delete();
            values.push_back(fp32_bits(1.75));
            values.push_back(fp32_bits(-0.50));
            values.push_back(fp32_bits(0.25));
            values.push_back(fp32_bits(2.50));
            values.push_back(fp32_bits(-1.25));
            values.push_back(fp32_bits(0.75));
            values.push_back(fp32_bits(0.00));
            values.push_back(fp32_bits(-2.00));

            txItem = create_frame(
                $sformatf("reset_matrix_%0d", frameIdx),
                TOP_INPUT_CLASS_MIXED_SIGN,
                TOP_TERM_ILAST_ONLY,
                (frameIdx % 2) ? TOP_STALL_LIGHT : TOP_STALL_NONE,
                (frameIdx >= 4) ? TOP_STALL_HEAVY : TOP_STALL_LIGHT,
                TOP_KEEP_ALL_F,
                (frameIdx % 2) ? TOP_RESULT_NORMAL : TOP_RESULT_RESET_ABORTED,
                TOP_RESET_PHASE_NONE,
                TOP_POST_TERM_DELAYED,
                TOP_SPECIAL_NONE,
                1'b0
            );
            append_values(txItem, values);
            m_env.m_generator.add_frame(txItem);
        end
    end
    endtask

    virtual task pre_start_actions();
    begin
        m_env.m_coverage.sample_reset_event(TOP_RESET_PHASE_IDLE, TOP_STALL_NONE, TOP_STALL_NONE, "reset_idle_event");
        m_env.m_driver.pulse_reset_cycles(2);
    end
    endtask

    virtual task start_actions();
    begin
        m_env.start_traffic();
        fork
            begin
                m_env.m_driver.inject_reset_when_phase(TOP_RESET_PHASE_CAPTURE, 2);
                m_env.m_coverage.sample_reset_event(TOP_RESET_PHASE_CAPTURE, TOP_STALL_NONE, TOP_STALL_LIGHT, "reset_capture_event");
                m_env.m_driver.inject_reset_when_phase(TOP_RESET_PHASE_REPLAY, 2);
                m_env.m_coverage.sample_reset_event(TOP_RESET_PHASE_REPLAY, TOP_STALL_LIGHT, TOP_STALL_LIGHT, "reset_replay_event");
                inject_reset_when_output_pipeline_active(2);
                m_env.m_coverage.sample_reset_event(TOP_RESET_PHASE_OUTPUT_VALID, TOP_STALL_LIGHT, TOP_STALL_HEAVY, "reset_output_valid_event");
            end
        join
    end
    endtask
endclass

`endif
