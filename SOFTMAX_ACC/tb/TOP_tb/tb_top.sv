`timescale 1ns / 1ps

module TbTop;
    import TOP_tb_pkg::*;

    localparam int unsigned LP_CLK_PERIOD  = 10;
    localparam int unsigned LP_SIM_TIMEOUT = 200_000_000;

    TOP_if uIf();
    TopCoverage uSuiteCoverage;
    TopGoldenStats uSuiteGoldenStats;
    string uExecutedCaseList[$];
    string uFailedCaseList[$];
    int unsigned uSuiteFailedCases;
    int unsigned uSuiteFailedErrors;
    int unsigned uSuiteTotalErrors;
    TOP #(
        .P_C_MAX (1024),
        .P_ADDR_W(10)
    ) uDut (
        .iClk       (uIf.iClk),
        .iRstn      (uIf.iRstn),
        .iSAxisValid(uIf.iSAxisValid),
        .oSAxisReady(uIf.oSAxisReady),
        .iSAxisData (uIf.iSAxisData),
        .iSAxisLast (uIf.iSAxisLast),
        .iSAxisKeep (uIf.iSAxisKeep),
        .oMAxisValid(uIf.oMAxisValid),
        .iMAxisReady(uIf.iMAxisReady),
        .oMAxisData (uIf.oMAxisData),
        .oMAxisLast (uIf.oMAxisLast),
        .oMAxisKeep (uIf.oMAxisKeep)
    );

    assign uIf.probe_downscale_valid   = uDut.wDownscale2Fanout_Valid;
    assign uIf.probe_downscale_last    = uDut.wDownscale2Fanout_Last;
    assign uIf.probe_fanout_ready      = uDut.wDownscale2Fanout_Ready;
    assign uIf.probe_exp_sum_ready     = uDut.wDownscale2ExpSum_Ready;
    assign uIf.probe_sub_ready         = uDut.wDownscale2Sub_Ready;
    assign uIf.probe_exp_sum_valid     = uDut.wExpSum2Sum_Valid;
    assign uIf.probe_sum_valid         = uDut.wSum2Ln_Valid;
    assign uIf.probe_ln_valid          = uDut.wLn2Sub_Valid;
    assign uIf.probe_sub_valid         = uDut.wSub2ExpOut_Valid;
    assign uIf.probe_sub_last          = uDut.wSub2ExpOut_Last;
    assign uIf.probe_exp_out_valid     = uDut.wExpOut2U16ToFp32_Valid;
    assign uIf.probe_exp_out_last      = uDut.wExpOut2U16ToFp32_Last;
    assign uIf.probe_u16_fp32_valid    = uDut.oMAxisValid;
    assign uIf.probe_u16_fp32_last     = uDut.oMAxisLast;
    assign uIf.probe_sub_frameStored   = uDut.uSub.frameStored;
    assign uIf.probe_sub_busy          = uDut.uSub.busy;
    assign uIf.probe_sub_readPending   = uDut.uSub.readPending;

    initial begin
        uIf.iClk = 1'b0;
        forever #(LP_CLK_PERIOD / 2.0) uIf.iClk = ~uIf.iClk;
    end

    initial begin
        uIf.reset_case_state();
        uIf.iRstn = 1'b0;
        repeat (5) @(posedge uIf.iClk);
        uIf.iRstn = 1'b1;
    end

    task automatic run_one_case(input string iCaseName, input int unsigned iCaseIndex, input int unsigned iCaseCount);
        TopBaseTest tbTest;
    begin
        $display("[TB][INFO] RUN CASE %0d / %0d", iCaseIndex, iCaseCount);
        $display("[TB][INFO] Selected TESTNAME=%s", iCaseName);
        tbTest = fnCreateTest(iCaseName, uIf);
        if (tbTest == null)
            $fatal(1, "[TB] Unsupported TESTNAME=%s", iCaseName);
        tbTest.set_case_ordinal(iCaseIndex, iCaseCount);
        tbTest.run();
        uSuiteTotalErrors += tbTest.get_last_total_errors();
        if (tbTest.get_case_failed()) begin
            uSuiteFailedCases++;
            uSuiteFailedErrors += tbTest.get_last_total_errors();
            uFailedCaseList.push_back(iCaseName);
            $display(
                "[TB][ERROR] Suite recorded failing case=%s total_errors=%0d",
                iCaseName,
                tbTest.get_last_total_errors()
            );
        end
        repeat (10) @(posedge uIf.iClk);
    end
    endtask

    task automatic run_requested_cases(input string iRequestedTest);
        string caseList[$];
        int unsigned idx;
    begin
        uExecutedCaseList.delete();
        if (iRequestedTest == "all") begin
            caseList.push_back("test_01_reset_matrix");
            caseList.push_back("test_02_singleton_frame");
            caseList.push_back("test_03_uniform_frame");
            caseList.push_back("test_04_mixed_vector_directed");
            caseList.push_back("test_05_backpressure_protocol");
            caseList.push_back("test_06_frame_boundary_cmax");
            caseList.push_back("test_07_boundary_collision_rearm");
            caseList.push_back("test_08_keep_ignore");
            caseList.push_back("test_09_special_fp32_policy");
            caseList.push_back("test_10_random_cov");
        end else begin
            caseList.push_back(iRequestedTest);
        end

        for (idx = 0; idx < caseList.size(); idx++) begin
            uExecutedCaseList.push_back(caseList[idx]);
            run_one_case(caseList[idx], idx + 1, caseList.size());
        end
    end
    endtask

    task automatic report_suite_summary(input string iRequestedTest);
        int unsigned coverageTenths;
        int unsigned builtinCoverageTenths;
        int unsigned mismatchRateTenths;
        int unsigned avgRelTenths;
        int unsigned maxRelTenths;
    begin
        coverageTenths = uSuiteCoverage.get_merged_coverage_tenths();
        builtinCoverageTenths = coverageTenths;
        mismatchRateTenths = uSuiteGoldenStats.m_total_entry.get_mismatch_rate_tenths();
        avgRelTenths = uSuiteGoldenStats.m_total_entry.get_avg_rel_error_tenths();
        maxRelTenths = uSuiteGoldenStats.m_total_entry.get_max_rel_error_tenths();

        $display(
            "[TB][INFO] SUITE report: test=%s cases=%0d failed_cases=%0d checked=%0d errors=%0d coverage=%0d.%0d%%",
            iRequestedTest,
            uExecutedCaseList.size(),
            uSuiteFailedCases,
            uSuiteGoldenStats.m_total_entry.m_checked_beats,
            uSuiteTotalErrors,
            coverageTenths / 10,
            coverageTenths % 10
        );
        $display(
            "[TB][INFO] SUITE quality: mismatch_rate=%0d.%0d%% avg_rel=%0d.%0d%% max_rel=%0d.%0d%% failed_frames=%0d",
            mismatchRateTenths / 10,
            mismatchRateTenths % 10,
            avgRelTenths / 10,
            avgRelTenths % 10,
            maxRelTenths / 10,
            maxRelTenths % 10,
            uSuiteGoldenStats.m_total_entry.m_failed_frames
        );
    end
    endtask

    task automatic generate_master_report(input string iRequestedTest);
        TopConfig reportCfg;
        integer fd;
        string suiteSummaryPath;
        string suiteCovHitPath;
        string suiteCovUnionIdPath;
        string suiteCovBreakdownPath;
        string masterReportPath;
        int unsigned coverageTenths;
        int unsigned builtinCoverageTenths;
        int unsigned mismatchRateTenths;
        int unsigned avgRelTenths;
        int unsigned maxRelTenths;
        string caseNamesCsv;
        string failedCaseNamesCsv;
        string cmd;
    begin
        reportCfg = new(iRequestedTest);
        suiteSummaryPath = fnTopRuntimeSuiteSummaryPath(iRequestedTest);
        suiteCovHitPath = fnTopJoinPath(
            fnTopRuntimeRoot(),
            {"suite_cov_hits_", fnTopSanitizeName(iRequestedTest), ".txt"}
        );
        suiteCovUnionIdPath = fnTopJoinPath(
            fnTopRuntimeRoot(),
            {"suite_cov_union_ids_", fnTopSanitizeName(iRequestedTest), ".txt"}
        );
        suiteCovBreakdownPath = fnTopJoinPath(
            fnTopRuntimeRoot(),
            {"suite_cov_breakdown_", fnTopSanitizeName(iRequestedTest), ".txt"}
        );
        masterReportPath = fnTopRuntimeMasterReportPath(iRequestedTest);
        coverageTenths = uSuiteCoverage.get_merged_coverage_tenths();
        builtinCoverageTenths = coverageTenths;
        mismatchRateTenths = uSuiteGoldenStats.m_total_entry.get_mismatch_rate_tenths();
        avgRelTenths = uSuiteGoldenStats.m_total_entry.get_avg_rel_error_tenths();
        maxRelTenths = uSuiteGoldenStats.m_total_entry.get_max_rel_error_tenths();
        caseNamesCsv = "";
        for (int unsigned idx = 0; idx < uExecutedCaseList.size(); idx++) begin
            if (idx != 0)
                caseNamesCsv = {caseNamesCsv, ","};
            caseNamesCsv = {caseNamesCsv, uExecutedCaseList[idx]};
        end
        failedCaseNamesCsv = "";
        for (int unsigned idx = 0; idx < uFailedCaseList.size(); idx++) begin
            if (idx != 0)
                failedCaseNamesCsv = {failedCaseNamesCsv, ","};
            failedCaseNamesCsv = {failedCaseNamesCsv, uFailedCaseList[idx]};
        end

        fd = $fopen(suiteSummaryPath, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create suite summary: %s", suiteSummaryPath);
        $fdisplay(
            fd,
            "{\"requested_test\":\"%s\",\"case_names_csv\":\"%s\",\"failed_case_names_csv\":\"%s\",\"failed_case_count\":%0d,\"failed_error_total\":%0d,\"suite_coverage_pct\":%0d.%0d,\"merged_scenario_coverage_pct\":%0d.%0d,\"vivado_builtin_coverage_pct\":%0d.%0d,\"rtl_checked_beats\":%0d,\"rtl_mismatch_beats\":%0d,\"rtl_mismatch_rate_pct\":%0d.%0d,\"rtl_numeric_beats\":%0d,\"rtl_avg_abs_err\":%0.6e,\"rtl_max_abs_err\":%0.6e,\"rtl_avg_rel_err_pct\":%0d.%0d,\"rtl_max_rel_err_pct\":%0d.%0d,\"rtl_failed_frames\":%0d}",
            iRequestedTest,
            caseNamesCsv,
            failedCaseNamesCsv,
            uSuiteFailedCases,
            uSuiteFailedErrors,
            coverageTenths / 10,
            coverageTenths % 10,
            coverageTenths / 10,
            coverageTenths % 10,
            builtinCoverageTenths / 10,
            builtinCoverageTenths % 10,
            uSuiteGoldenStats.m_total_entry.m_checked_beats,
            uSuiteGoldenStats.m_total_entry.m_mismatch_beats,
            mismatchRateTenths / 10,
            mismatchRateTenths % 10,
            uSuiteGoldenStats.m_total_entry.m_numeric_beats,
            uSuiteGoldenStats.m_total_entry.get_avg_abs_error(),
            uSuiteGoldenStats.m_total_entry.m_abs_error_max,
            avgRelTenths / 10,
            avgRelTenths % 10,
            maxRelTenths / 10,
            maxRelTenths % 10,
            uSuiteGoldenStats.m_total_entry.m_failed_frames
        );
        $fclose(fd);
        uSuiteCoverage.write_total_hit_keys(suiteCovHitPath);
        uSuiteCoverage.write_total_union_ids(suiteCovUnionIdPath);
        uSuiteCoverage.write_total_builtin_breakdown(suiteCovBreakdownPath);

        cmd = {
            "\"", reportCfg.m_python_launcher_path, "\" -E -I",
            " \"", reportCfg.m_report_tool_path, "\"",
            " --runtime-root \"", reportCfg.m_runtime_root, "\"",
            " --testname ", iRequestedTest
        };
        if ($system(cmd) != 0)
            $fatal(1, "[TB] Failed to generate master HTML report: %s", cmd);
        $display("[TB][INFO] Master HTML report generated: %s", masterReportPath);
        $display("[TB][INFO] Suite coverage hit dump generated: %s", suiteCovHitPath);
        $display("[TB][INFO] Suite coverage union-id dump generated: %s", suiteCovUnionIdPath);
        $display("[TB][INFO] Suite coverage breakdown generated: %s", suiteCovBreakdownPath);
    end
    endtask

    initial begin
        string testname;
        string failedCaseNamesCsv;
        uSuiteCoverage = new();
        uSuiteGoldenStats = new();
        uSuiteFailedCases = 0;
        uSuiteFailedErrors = 0;
        uSuiteTotalErrors = 0;
        uFailedCaseList.delete();
        TopCoverage::set_global_coverage(uSuiteCoverage);
        TopGoldenStats::set_global_stats(uSuiteGoldenStats);
        @(posedge uIf.iRstn);
        if (!$value$plusargs("TESTNAME=%s", testname))
            testname = "all";
        run_requested_cases(testname);
        report_suite_summary(testname);
        generate_master_report(testname);
        if (uSuiteFailedCases != 0) begin
            failedCaseNamesCsv = "";
            for (int unsigned idx = 0; idx < uFailedCaseList.size(); idx++) begin
                if (idx != 0)
                    failedCaseNamesCsv = {failedCaseNamesCsv, ","};
                failedCaseNamesCsv = {failedCaseNamesCsv, uFailedCaseList[idx]};
            end
            $fatal(
                1,
                "[TB] Suite completed with %0d failing case(s), total_errors=%0d, failed_cases=%s",
                uSuiteFailedCases,
                uSuiteFailedErrors,
                failedCaseNamesCsv
            );
        end
        repeat (20) @(posedge uIf.iClk);
        $finish;
    end

    initial begin
        #(LP_SIM_TIMEOUT);
        $fatal(1, "[TB] Timeout reached: %0d ns", LP_SIM_TIMEOUT);
    end

    initial begin
        $dumpfile("TOP_tb_wave.vcd");
        $dumpvars(0, TbTop);
    end
endmodule
