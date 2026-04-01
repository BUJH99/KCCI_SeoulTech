`ifndef TOP_BASE_TEST_SVH
`define TOP_BASE_TEST_SVH

class TopBaseTest;
    TopConfig       m_cfg;
    TopEnv          m_env;
    virtual TOP_if  vif_TOP;
    string          m_testname;
    int unsigned    m_case_index;
    int unsigned    m_case_count;
    bit             m_case_failed;
    int unsigned    m_last_total_errors;

    function new(virtual TOP_if vif_TOP, string iTestname);
        this.vif_TOP = vif_TOP;
        this.m_testname = iTestname;
        this.m_case_index = 1;
        this.m_case_count = 1;
        this.m_case_failed = 1'b0;
        this.m_last_total_errors = 0;
        this.m_cfg = new(iTestname);
    endfunction

    function void set_case_ordinal(input int unsigned iCaseIndex, input int unsigned iCaseCount);
    begin
        m_case_index = iCaseIndex;
        m_case_count = iCaseCount;
    end
    endfunction

    function bit get_case_failed();
    begin
        return m_case_failed;
    end
    endfunction

    function int unsigned get_last_total_errors();
    begin
        return m_last_total_errors;
    end
    endfunction

    function automatic bit [31:0] fp32_bits(input real iValue);
        shortreal sValue;
    begin
        sValue = iValue;
        return $shortrealtobits(sValue);
    end
    endfunction

    function automatic TopFrameTx create_frame(
        input string iLabel,
        input TopInputClassE iInputClass = TOP_INPUT_CLASS_UNKNOWN,
        input TopTermKindE iTermKind = TOP_TERM_ILAST_ONLY,
        input TopStallModeE iInStall = TOP_STALL_NONE,
        input TopStallModeE iOutStall = TOP_STALL_NONE,
        input TopKeepKindE iKeepKind = TOP_KEEP_ALL_F,
        input TopResultKindE iResultKind = TOP_RESULT_NORMAL,
        input TopResetPhaseE iResetPhase = TOP_RESET_PHASE_NONE,
        input TopPostTermRearmE iPostTermRearm = TOP_POST_TERM_DELAYED,
        input TopSpecialFp32E iSpecialKind = TOP_SPECIAL_NONE,
        input bit iExpectAbort = 1'b0
    );
        TopFrameTx txItem;
    begin
        txItem = new();
        txItem.m_scenario_tag = iLabel;
        txItem.m_input_class = iInputClass;
        txItem.m_term_kind = iTermKind;
        txItem.m_in_stall_mode = iInStall;
        txItem.m_out_stall_mode = iOutStall;
        txItem.m_keep_kind = iKeepKind;
        txItem.m_result_kind = iResultKind;
        txItem.m_reset_phase = iResetPhase;
        txItem.m_post_term_rearm = iPostTermRearm;
        txItem.m_special_kind = iSpecialKind;
        txItem.m_expect_abort_on_reset = iExpectAbort;
        return txItem;
    end
    endfunction

    function automatic void append_values(input TopFrameTx txItem, input bit [31:0] iValues[$]);
        int idx;
    begin
        for (idx = 0; idx < iValues.size(); idx++)
            txItem.append_sample(iValues[idx], 4'hF, 0);
    end
    endfunction

    task automatic set_uniform_gap(input TopFrameTx txItem, input int unsigned iGapCycles);
        int idx;
    begin
        txItem.m_input_gap_cycles.delete();
        for (idx = 0; idx < txItem.size(); idx++)
            txItem.m_input_gap_cycles.push_back(iGapCycles);
    end
    endtask

    task automatic prepare_runtime_dir();
        string cmd;
        integer fd;
    begin
        cmd = {
            "cmd /c if exist \"", m_cfg.m_case_runtime_dir,
            "\" rmdir /s /q \"", m_cfg.m_case_runtime_dir,
            "\" & mkdir \"", m_cfg.m_case_runtime_dir, "\""
        };
        if ($system(cmd) != 0)
            $fatal(1, "[TB] Failed to prepare runtime dir: %s", m_cfg.m_case_runtime_dir);

        fd = $fopen(m_cfg.m_input_jsonl_path, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", m_cfg.m_input_jsonl_path);
        $fclose(fd);
        fd = $fopen(m_cfg.m_expected_jsonl_path, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", m_cfg.m_expected_jsonl_path);
        $fclose(fd);
        fd = $fopen(m_cfg.m_actual_jsonl_path, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", m_cfg.m_actual_jsonl_path);
        $fclose(fd);
        fd = $fopen(m_cfg.m_mismatch_jsonl_path, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", m_cfg.m_mismatch_jsonl_path);
        $fclose(fd);
        fd = $fopen(m_cfg.m_scenario_coverage_jsonl_path, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", m_cfg.m_scenario_coverage_jsonl_path);
        $fclose(fd);
        fd = $fopen(m_cfg.m_scenario_cov_points_jsonl_path, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", m_cfg.m_scenario_cov_points_jsonl_path);
        $fclose(fd);
        fd = $fopen(m_cfg.m_scenario_quality_jsonl_path, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", m_cfg.m_scenario_quality_jsonl_path);
        $fclose(fd);
    end
    endtask

    task automatic apply_case_reset();
    begin
        vif_TOP.reset_case_state();
        vif_TOP.iRstn <= 1'b0;
        repeat (LP_TOP_RESET_CYCLES) @(posedge vif_TOP.iClk);
        vif_TOP.iRstn <= 1'b1;
        repeat (2) @(posedge vif_TOP.iClk);
    end
    endtask

    virtual task configure();
        int unsigned seedDummy;
    begin
        m_cfg.set_case_info(m_testname, m_case_index, m_case_count);
        seedDummy = $urandom(m_cfg.m_seed ^ m_case_index);
    end
    endtask

    virtual task build_scenario();
    endtask

    virtual task pre_start_actions();
    endtask

    virtual task start_actions();
    begin
        m_env.start_traffic();
    end
    endtask

    virtual task post_quiescent_checks();
    endtask

    task automatic report_summary();
        int unsigned totalErrors;
    begin
        totalErrors = m_env.get_total_errors();
        $display(
            "[TB][INFO] ENV report: checked=%0d errors=%0d",
            m_env.get_checked_count(),
            totalErrors
        );
        $display(
            "[TB][INFO] Breakdown: scoreboard=%0d dut_assert=%0d shadow=%0d env=%0d warnings=%0d",
            m_env.m_scoreboard.m_error_count,
            vif_TOP.m_dut_assert_error_count,
            m_env.m_shadowChecker.m_error_count,
            vif_TOP.m_env_error_count,
            m_env.m_scoreboard.m_warning_count
        );
        m_env.m_scoreboard.m_goldenStats.report_summary();
        m_env.m_coverage.report_scenario_breakdown();
        m_env.m_scoreboard.m_goldenStats.report_scenario_breakdown();
        write_report_artifacts(totalErrors);
    end
    endtask

    task automatic write_report_artifacts(
        input int unsigned iTotalErrors
    );
        integer fd;
        string statusText;
        int unsigned coverageTenths;
        int unsigned mismatchRateTenths;
        int unsigned avgRelTenths;
        int unsigned maxRelTenths;
    begin
        m_env.m_coverage.write_scenario_jsonl(m_cfg.m_scenario_coverage_jsonl_path);
        m_env.m_coverage.write_scenario_cov_points_jsonl(m_cfg.m_scenario_cov_points_jsonl_path);
        m_env.m_scoreboard.m_goldenStats.write_scenario_jsonl(m_cfg.m_scenario_quality_jsonl_path);

        statusText = (iTotalErrors == 0) ? "PASS" : "FAIL";
        coverageTenths = m_env.m_coverage.get_inst_coverage_tenths();
        mismatchRateTenths = m_env.m_scoreboard.m_goldenStats.m_total_entry.get_mismatch_rate_tenths();
        avgRelTenths = m_env.m_scoreboard.m_goldenStats.m_total_entry.get_avg_rel_error_tenths();
        maxRelTenths = m_env.m_scoreboard.m_goldenStats.m_total_entry.get_max_rel_error_tenths();

        fd = $fopen(m_cfg.m_summary_json_path, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", m_cfg.m_summary_json_path);

        $fdisplay(
            fd,
            "{\"testname\":\"%s\",\"case_index\":%0d,\"case_count\":%0d,\"seed\":%0d,\"timeout_cycles\":%0d,\"status\":\"%s\",\"runtime_dir\":\"%s\",\"checked_beats\":%0d,\"total_errors\":%0d,\"scoreboard_errors\":%0d,\"dut_assert_errors\":%0d,\"shadow_errors\":%0d,\"env_errors\":%0d,\"warnings\":%0d,\"case_coverage_pct\":%0d.%0d,\"golden_checked_beats\":%0d,\"golden_mismatch_beats\":%0d,\"golden_mismatch_rate_pct\":%0d.%0d,\"golden_numeric_beats\":%0d,\"golden_avg_abs_err\":%0.6e,\"golden_max_abs_err\":%0.6e,\"golden_avg_rel_err_pct\":%0d.%0d,\"golden_max_rel_err_pct\":%0d.%0d,\"golden_failed_frames\":%0d}",
            m_cfg.m_testname,
            m_cfg.m_case_index,
            m_cfg.m_case_count,
            m_cfg.m_seed,
            m_cfg.m_timeout_cycles,
            statusText,
            m_cfg.m_case_runtime_dir,
            m_env.get_checked_count(),
            iTotalErrors,
            m_env.m_scoreboard.m_error_count,
            vif_TOP.m_dut_assert_error_count,
            m_env.m_shadowChecker.m_error_count,
            vif_TOP.m_env_error_count,
            m_env.m_scoreboard.m_warning_count,
            coverageTenths / 10,
            coverageTenths % 10,
            m_env.m_scoreboard.m_goldenStats.m_total_entry.m_checked_beats,
            m_env.m_scoreboard.m_goldenStats.m_total_entry.m_mismatch_beats,
            mismatchRateTenths / 10,
            mismatchRateTenths % 10,
            m_env.m_scoreboard.m_goldenStats.m_total_entry.m_numeric_beats,
            m_env.m_scoreboard.m_goldenStats.m_total_entry.get_avg_abs_error(),
            m_env.m_scoreboard.m_goldenStats.m_total_entry.m_abs_error_max,
            avgRelTenths / 10,
            avgRelTenths % 10,
            maxRelTenths / 10,
            maxRelTenths % 10,
            m_env.m_scoreboard.m_goldenStats.m_total_entry.m_failed_frames
        );
        $fclose(fd);
        `TB_INFO($sformatf("Case artifacts generated: %s", m_cfg.m_case_runtime_dir));
    end
    endtask

    virtual task run();
        bit quiescentOk;
        int unsigned totalErrors;
    begin
        m_case_failed = 1'b0;
        m_last_total_errors = 0;
        configure();
        prepare_runtime_dir();
        apply_case_reset();
        m_env = new(vif_TOP, m_cfg);
        build_scenario();
        m_env.run();
        pre_start_actions();
        start_actions();
        m_env.wait_for_quiescent(quiescentOk);
        if (!quiescentOk)
            vif_TOP.note_env_error("timeout", $sformatf("Case %s did not reach quiescent state", m_testname));
        post_quiescent_checks();
        report_summary();
        totalErrors = m_env.get_total_errors();
        m_last_total_errors = totalErrors;
        m_case_failed = (totalErrors != 0);
        m_env.stop();
        repeat (8) @(posedge vif_TOP.iClk);
        if (m_case_failed)
            $display("[TB][ERROR] Case %s failed with %0d total errors", m_testname, totalErrors);
    end
    endtask
endclass

`endif
