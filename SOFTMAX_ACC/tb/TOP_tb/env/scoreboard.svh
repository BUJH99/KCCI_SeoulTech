`ifndef TOP_SCOREBOARD_SVH
`define TOP_SCOREBOARD_SVH

function automatic real fnTopAbsReal(input real iValue);
begin
    if (iValue < 0.0)
        return -iValue;
    return iValue;
end
endfunction

class TopGoldenStatsEntry;
    string           m_scenario_tag;
    int unsigned     m_checked_beats;
    int unsigned     m_mismatch_beats;
    int unsigned     m_numeric_beats;
    int unsigned     m_failed_frames;
    real             m_abs_error_sum;
    real             m_abs_error_max;
    real             m_rel_error_sum_pct;
    real             m_rel_error_max_pct;

    function new(string iScenarioTag = "");
        m_scenario_tag = iScenarioTag;
        m_checked_beats = 0;
        m_mismatch_beats = 0;
        m_numeric_beats = 0;
        m_failed_frames = 0;
        m_abs_error_sum = 0.0;
        m_abs_error_max = 0.0;
        m_rel_error_sum_pct = 0.0;
        m_rel_error_max_pct = 0.0;
    endfunction

    function automatic void note_beat(
        input bit  iBeatMismatch,
        input bit  iHasNumeric,
        input real iAbsErr,
        input real iRelErrPct
    );
    begin
        m_checked_beats++;
        if (iBeatMismatch)
            m_mismatch_beats++;
        if (iHasNumeric) begin
            m_numeric_beats++;
            m_abs_error_sum += iAbsErr;
            m_rel_error_sum_pct += iRelErrPct;
            if (iAbsErr > m_abs_error_max)
                m_abs_error_max = iAbsErr;
            if (iRelErrPct > m_rel_error_max_pct)
                m_rel_error_max_pct = iRelErrPct;
        end
    end
    endfunction

    function automatic void note_frame_result(input bit iFrameFailed);
    begin
        if (iFrameFailed)
            m_failed_frames++;
    end
    endfunction

    function automatic int unsigned get_mismatch_rate_tenths();
        real rateValue;
    begin
        if (m_checked_beats == 0)
            return 0;
        rateValue = (m_mismatch_beats * 100.0) / m_checked_beats;
        return $rtoi((rateValue * 10.0) + 0.5);
    end
    endfunction

    function automatic real get_avg_abs_error();
    begin
        if (m_numeric_beats == 0)
            return 0.0;
        return m_abs_error_sum / m_numeric_beats;
    end
    endfunction

    function automatic int unsigned get_avg_rel_error_tenths();
        real avgRelValue;
    begin
        if (m_numeric_beats == 0)
            return 0;
        avgRelValue = m_rel_error_sum_pct / m_numeric_beats;
        return $rtoi((avgRelValue * 10.0) + 0.5);
    end
    endfunction

    function automatic int unsigned get_max_rel_error_tenths();
    begin
        return $rtoi((m_rel_error_max_pct * 10.0) + 0.5);
    end
    endfunction
endclass

class TopGoldenStats;
    static TopGoldenStats       sg_global_stats;
    TopGoldenStatsEntry      m_total_entry;
    TopGoldenStatsEntry      m_scenario_entries[string];
    string                   m_scenario_order[$];

    function new();
        m_total_entry = new("__total__");
    endfunction

    static function void set_global_stats(input TopGoldenStats iStatsObj);
    begin
        sg_global_stats = iStatsObj;
    end
    endfunction

    function automatic string fnScenarioKey(input string iScenarioTag);
    begin
        if (iScenarioTag.len() == 0)
            return "unnamed";
        return iScenarioTag;
    end
    endfunction

    function automatic TopGoldenStatsEntry fnGetScenarioEntry(input string iScenarioTag);
        string key;
    begin
        key = fnScenarioKey(iScenarioTag);
        if (!m_scenario_entries.exists(key)) begin
            m_scenario_entries[key] = new(key);
            m_scenario_order.push_back(key);
        end
        return m_scenario_entries[key];
    end
    endfunction

    function automatic void note_beat(
        input string iScenarioTag,
        input bit    iBeatMismatch,
        input bit    iHasNumeric,
        input real   iAbsErr,
        input real   iRelErrPct
    );
        TopGoldenStatsEntry scenarioEntry;
    begin
        if ((sg_global_stats != null) && (sg_global_stats != this))
            sg_global_stats.note_beat(iScenarioTag, iBeatMismatch, iHasNumeric, iAbsErr, iRelErrPct);
        m_total_entry.note_beat(iBeatMismatch, iHasNumeric, iAbsErr, iRelErrPct);
        scenarioEntry = fnGetScenarioEntry(iScenarioTag);
        scenarioEntry.note_beat(iBeatMismatch, iHasNumeric, iAbsErr, iRelErrPct);
    end
    endfunction

    function automatic void note_frame_result(input string iScenarioTag, input bit iFrameFailed);
        TopGoldenStatsEntry scenarioEntry;
    begin
        if ((sg_global_stats != null) && (sg_global_stats != this))
            sg_global_stats.note_frame_result(iScenarioTag, iFrameFailed);
        m_total_entry.note_frame_result(iFrameFailed);
        scenarioEntry = fnGetScenarioEntry(iScenarioTag);
        scenarioEntry.note_frame_result(iFrameFailed);
    end
    endfunction

    task automatic report_summary();
        int unsigned mismatchRateTenths;
        int unsigned avgRelTenths;
        int unsigned maxRelTenths;
    begin
        mismatchRateTenths = m_total_entry.get_mismatch_rate_tenths();
        avgRelTenths = m_total_entry.get_avg_rel_error_tenths();
        maxRelTenths = m_total_entry.get_max_rel_error_tenths();
        $display(
            "[TB][INFO] Golden report: checked_beats=%0d mismatch_beats=%0d mismatch_rate=%0d.%0d%% numeric_beats=%0d avg_abs_err=%0.6e max_abs_err=%0.6e avg_rel_err=%0d.%0d%% max_rel_err=%0d.%0d%% failed_frames=%0d",
            m_total_entry.m_checked_beats,
            m_total_entry.m_mismatch_beats,
            mismatchRateTenths / 10,
            mismatchRateTenths % 10,
            m_total_entry.m_numeric_beats,
            m_total_entry.get_avg_abs_error(),
            m_total_entry.m_abs_error_max,
            avgRelTenths / 10,
            avgRelTenths % 10,
            maxRelTenths / 10,
            maxRelTenths % 10,
            m_total_entry.m_failed_frames
        );
    end
    endtask

    task automatic report_scenario_breakdown();
        int idx;
        string key;
        TopGoldenStatsEntry scenarioEntry;
        int unsigned mismatchRateTenths;
        int unsigned avgRelTenths;
        int unsigned maxRelTenths;
    begin
        if (m_scenario_order.size() == 0)
            return;

        `TB_INFO("Scenario quality start");
        for (idx = 0; idx < m_scenario_order.size(); idx++) begin
            key = m_scenario_order[idx];
            scenarioEntry = m_scenario_entries[key];
            mismatchRateTenths = scenarioEntry.get_mismatch_rate_tenths();
            avgRelTenths = scenarioEntry.get_avg_rel_error_tenths();
            maxRelTenths = scenarioEntry.get_max_rel_error_tenths();
            $display(
                "[TB][INFO] Scenario quality: name=%s checked_beats=%0d mismatch_beats=%0d mismatch_rate=%0d.%0d%% numeric_beats=%0d avg_abs_err=%0.6e max_abs_err=%0.6e avg_rel_err=%0d.%0d%% max_rel_err=%0d.%0d%% failed_frames=%0d",
                key,
                scenarioEntry.m_checked_beats,
                scenarioEntry.m_mismatch_beats,
                mismatchRateTenths / 10,
                mismatchRateTenths % 10,
                scenarioEntry.m_numeric_beats,
                scenarioEntry.get_avg_abs_error(),
                scenarioEntry.m_abs_error_max,
                avgRelTenths / 10,
                avgRelTenths % 10,
                maxRelTenths / 10,
                maxRelTenths % 10,
                scenarioEntry.m_failed_frames
            );
        end
        `TB_INFO("Scenario quality end");
    end
    endtask

    task automatic write_scenario_jsonl(input string iPath);
        integer fd;
        int idx;
        string key;
        TopGoldenStatsEntry scenarioEntry;
        int unsigned mismatchRateTenths;
        int unsigned avgRelTenths;
        int unsigned maxRelTenths;
    begin
        fd = $fopen(iPath, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", iPath);

        for (idx = 0; idx < m_scenario_order.size(); idx++) begin
            key = m_scenario_order[idx];
            scenarioEntry = m_scenario_entries[key];
            mismatchRateTenths = scenarioEntry.get_mismatch_rate_tenths();
            avgRelTenths = scenarioEntry.get_avg_rel_error_tenths();
            maxRelTenths = scenarioEntry.get_max_rel_error_tenths();
            $fdisplay(
                fd,
                "{\"name\":\"%s\",\"checked_beats\":%0d,\"mismatch_beats\":%0d,\"mismatch_rate_pct\":%0d.%0d,\"numeric_beats\":%0d,\"avg_abs_err\":%0.6e,\"max_abs_err\":%0.6e,\"avg_rel_err_pct\":%0d.%0d,\"max_rel_err_pct\":%0d.%0d,\"failed_frames\":%0d}",
                key,
                scenarioEntry.m_checked_beats,
                scenarioEntry.m_mismatch_beats,
                mismatchRateTenths / 10,
                mismatchRateTenths % 10,
                scenarioEntry.m_numeric_beats,
                scenarioEntry.get_avg_abs_error(),
                scenarioEntry.m_abs_error_max,
                avgRelTenths / 10,
                avgRelTenths % 10,
                maxRelTenths / 10,
                maxRelTenths % 10,
                scenarioEntry.m_failed_frames
            );
        end
        $fclose(fd);
    end
    endtask
endclass

class TopScoreboard;
    virtual TOP_if              vif_TOP;
    TopConfig                   m_cfg;
    TopCoverage                 m_coverage;
    TopGoldenStats              m_goldenStats;
    mailbox #(TopObservedFrame) mbx_in2scb;
    mailbox #(TopObservedFrame) mbx_out2scb;
    TopExpectedFrame            m_expected_queue[$];
    int unsigned                m_checked_count;
    int unsigned                m_error_count;
    int unsigned                m_warning_count;
    int unsigned                m_reset_epoch;
    bit                         m_prev_rstn;
    bit                         m_stop_requested;
    bit                         m_busy_python_call;

    function new(
        virtual TOP_if vif_TOP,
        TopConfig cfg,
        TopCoverage coverageObj,
        mailbox #(TopObservedFrame) iMbxIn2Scb,
        mailbox #(TopObservedFrame) iMbxOut2Scb
    );
        this.vif_TOP = vif_TOP;
        this.m_cfg = cfg;
        this.m_coverage = coverageObj;
        this.m_goldenStats = new();
        this.mbx_in2scb = iMbxIn2Scb;
        this.mbx_out2scb = iMbxOut2Scb;
        this.m_checked_count = 0;
        this.m_error_count = 0;
        this.m_warning_count = 0;
        this.m_reset_epoch = 0;
        this.m_prev_rstn = 1'b0;
        this.m_stop_requested = 1'b0;
        this.m_busy_python_call = 1'b0;
    endfunction

    function automatic int fnFind(input string iHaystack, input string iNeedle);
        int idx;
    begin
        if (iNeedle.len() == 0)
            return 0;
        for (idx = 0; idx <= (iHaystack.len() - iNeedle.len()); idx++) begin
            if (iHaystack.substr(idx, idx + iNeedle.len() - 1) == iNeedle)
                return idx;
        end
        return -1;
    end
    endfunction

    function automatic string fnJsonString(input string iLine, input string iKey);
        string token;
        int startIdx;
        int endIdx;
    begin
        token = {"\"", iKey, "\":\""};
        startIdx = fnFind(iLine, token);
        if (startIdx < 0)
            return "";
        startIdx += token.len();
        endIdx = startIdx;
        while ((endIdx < iLine.len()) && (iLine.getc(endIdx) != 34))
            endIdx++;
        if (endIdx <= startIdx)
            return "";
        return iLine.substr(startIdx, endIdx - 1);
    end
    endfunction

    function automatic integer fnJsonInt(input string iLine, input string iKey);
        string token;
        int startIdx;
        int endIdx;
        integer value;
        integer scanCount;
    begin
        token = {"\"", iKey, "\":"};
        startIdx = fnFind(iLine, token);
        if (startIdx < 0)
            return 0;
        startIdx += token.len();
        endIdx = startIdx;
        while ((endIdx < iLine.len()) &&
               (iLine.getc(endIdx) == 45 || (iLine.getc(endIdx) >= 48 && iLine.getc(endIdx) <= 57)))
            endIdx++;
        value = 0;
        scanCount = 0;
        if (endIdx > startIdx)
            scanCount = $sscanf(iLine.substr(startIdx, endIdx - 1), "%d", value);
        return value;
    end
    endfunction

    function automatic string fnHexCsv32(input bit [31:0] iValues[$]);
        int idx;
        string csv;
    begin
        csv = "";
        for (idx = 0; idx < iValues.size(); idx++) begin
            if (idx != 0)
                csv = {csv, ","};
            csv = {csv, $sformatf("%08x", iValues[idx])};
        end
        return csv;
    end
    endfunction

    function automatic string fnHexCsv4(input bit [3:0] iValues[$]);
        int idx;
        string csv;
    begin
        csv = "";
        for (idx = 0; idx < iValues.size(); idx++) begin
            if (idx != 0)
                csv = {csv, ","};
            csv = {csv, $sformatf("%01x", iValues[idx])};
        end
        return csv;
    end
    endfunction

    function automatic void fnSplitCsvHex32(input string iCsv, ref bit [31:0] oValues[$]);
        int idx;
        int value;
        int scanCount;
        string token;
    begin
        oValues.delete();
        token = "";
        for (idx = 0; idx <= iCsv.len(); idx++) begin
            if ((idx == iCsv.len()) || (iCsv.getc(idx) == 44)) begin
                if (token.len() > 0) begin
                    value = 0;
                    scanCount = $sscanf(token, "%h", value);
                    oValues.push_back(value[31:0]);
                end
                token = "";
            end else begin
                token = {token, iCsv.substr(idx, idx)};
            end
        end
    end
    endfunction

    function automatic void fnSplitCsvHex4(input string iCsv, ref bit [3:0] oValues[$]);
        int idx;
        int value;
        int scanCount;
        string token;
    begin
        oValues.delete();
        token = "";
        for (idx = 0; idx <= iCsv.len(); idx++) begin
            if ((idx == iCsv.len()) || (iCsv.getc(idx) == 44)) begin
                if (token.len() > 0) begin
                    value = 0;
                    scanCount = $sscanf(token, "%h", value);
                    oValues.push_back(value[3:0]);
                end
                token = "";
            end else begin
                token = {token, iCsv.substr(idx, idx)};
            end
        end
    end
    endfunction

    function automatic void fnSplitCsvInt(input string iCsv, ref int unsigned oValues[$]);
        int idx;
        integer value;
        integer scanCount;
        string token;
    begin
        oValues.delete();
        token = "";
        for (idx = 0; idx <= iCsv.len(); idx++) begin
            if ((idx == iCsv.len()) || (iCsv.getc(idx) == 44)) begin
                if (token.len() > 0) begin
                    value = 0;
                    scanCount = $sscanf(token, "%d", value);
                    oValues.push_back(value);
                end
                token = "";
            end else begin
                token = {token, iCsv.substr(idx, idx)};
            end
        end
    end
    endfunction

    function automatic shortreal fnSumProb(input bit [31:0] iValues[$]);
        int idx;
        shortreal sumValue;
    begin
        sumValue = 0.0;
        for (idx = 0; idx < iValues.size(); idx++)
            sumValue += fnTopBitsToShortreal(iValues[idx]);
        return sumValue;
    end
    endfunction

    function automatic int unsigned fnActualArgmax(input bit [31:0] iValues[$]);
        int idx;
        int unsigned maxIdx;
        shortreal maxValue;
        shortreal curValue;
    begin
        maxIdx = 0;
        maxValue = -1.0;
        for (idx = 0; idx < iValues.size(); idx++) begin
            curValue = fnTopBitsToShortreal(iValues[idx]);
            if ((idx == 0) || (curValue > maxValue)) begin
                maxValue = curValue;
                maxIdx = idx;
            end
        end
        return maxIdx;
    end
    endfunction

    function automatic bit fnIndexInSet(input int unsigned iIndex, input int unsigned iSet[$]);
        int idx;
    begin
        for (idx = 0; idx < iSet.size(); idx++) begin
            if (iSet[idx] == iIndex)
                return 1'b1;
        end
        return 1'b0;
    end
    endfunction

    function automatic void report_mismatch(
        input string iReason,
        input TopExpectedFrame expFrame,
        input TopObservedFrame obsFrame,
        input int unsigned iBeatIndex
    );
    begin
        m_error_count++;
        $display(
            "[TB][ERROR] %s frame_id=%0d beat=%0d scenario=%s input_csv=%s expected_csv=%s actual_csv=%s",
            iReason,
            expFrame.m_frame_id,
            iBeatIndex,
            expFrame.m_scenario_tag,
            fnHexCsv32(expFrame.m_input_samples),
            fnHexCsv32(expFrame.m_output_samples),
            (obsFrame == null) ? "<none>" : fnHexCsv32(obsFrame.m_samples)
        );
        append_mismatch_event(iReason, expFrame, obsFrame, iBeatIndex);
    end
    endfunction

    function automatic string build_input_json_line(input TopObservedFrame inFrame);
    begin
        return {
            "{\"frame_id\":", $sformatf("%0d", inFrame.m_frame_id),
            ",\"reset_epoch\":", $sformatf("%0d", inFrame.m_reset_epoch),
            ",\"scenario\":\"", inFrame.m_scenario_tag, "\"",
            ",\"input_class\":\"", fnTopInputClassName(inFrame.m_input_class), "\"",
            ",\"in_stall\":\"", fnTopStallModeName(inFrame.m_in_stall_mode), "\"",
            ",\"out_stall\":\"", fnTopStallModeName(inFrame.m_out_stall_mode), "\"",
            ",\"keep_kind\":\"", fnTopKeepKindName(inFrame.m_keep_kind), "\"",
            ",\"result_kind\":\"", fnTopResultKindName(inFrame.m_result_kind), "\"",
            ",\"reset_phase\":\"", fnTopResetPhaseName(inFrame.m_reset_phase), "\"",
            ",\"term_kind\":\"", fnTopTermKindName(inFrame.m_term_kind), "\"",
            ",\"post_term_rearm\":\"", fnTopPostTermRearmName(inFrame.m_post_term_rearm), "\"",
            ",\"special_kind\":\"", fnTopSpecialKindName(inFrame.m_special_kind), "\"",
            ",\"data_hex_csv\":\"", fnHexCsv32(inFrame.m_samples), "\"",
            ",\"keep_hex_csv\":\"", fnHexCsv4(inFrame.m_keeps), "\"",
            "}"
        };
    end
    endfunction

    function automatic int append_input_frame(input TopObservedFrame inFrame);
        integer fd;
        string jsonLine;
    begin
        jsonLine = build_input_json_line(inFrame);
        fd = $fopen(m_cfg.m_input_jsonl_path, "a");
        if (fd == 0) begin
            m_error_count++;
            $display("[TB][ERROR] Failed to open %s", m_cfg.m_input_jsonl_path);
            return 1;
        end
        $fdisplay(fd, "%s", jsonLine);
        $fclose(fd);
        return 0;
    end
    endfunction

    function automatic string build_actual_json_line(
        input TopExpectedFrame expFrame,
        input TopObservedFrame obsFrame,
        input bit iFrameFailed,
        input int unsigned iCheckedBeats,
        input int unsigned iMismatchBeats,
        input int unsigned iNumericBeats,
        input real iAvgAbsErr,
        input real iMaxAbsErr,
        input real iAvgRelErrPct,
        input real iMaxRelErrPct
    );
    begin
        return {
            "{\"frame_id\":", $sformatf("%0d", expFrame.m_frame_id),
            ",\"reset_epoch\":", $sformatf("%0d", obsFrame.m_reset_epoch),
            ",\"scenario\":\"", expFrame.m_scenario_tag, "\"",
            ",\"checked_beats\":", $sformatf("%0d", iCheckedBeats),
            ",\"mismatch_beats\":", $sformatf("%0d", iMismatchBeats),
            ",\"numeric_beats\":", $sformatf("%0d", iNumericBeats),
            ",\"avg_abs_err\":", $sformatf("%0.6e", iAvgAbsErr),
            ",\"max_abs_err\":", $sformatf("%0.6e", iMaxAbsErr),
            ",\"avg_rel_err_pct\":", $sformatf("%0.6e", iAvgRelErrPct),
            ",\"max_rel_err_pct\":", $sformatf("%0.6e", iMaxRelErrPct),
            ",\"frame_failed\":", iFrameFailed ? "1" : "0",
            ",\"last_count\":", $sformatf("%0d", obsFrame.m_last_count),
            ",\"data_hex_csv\":\"", fnHexCsv32(obsFrame.m_samples), "\"",
            ",\"keep_hex_csv\":\"", fnHexCsv4(obsFrame.m_keeps), "\"",
            "}"
        };
    end
    endfunction

    function automatic void append_actual_frame(
        input TopExpectedFrame expFrame,
        input TopObservedFrame obsFrame,
        input bit iFrameFailed,
        input int unsigned iCheckedBeats,
        input int unsigned iMismatchBeats,
        input int unsigned iNumericBeats,
        input real iAvgAbsErr,
        input real iMaxAbsErr,
        input real iAvgRelErrPct,
        input real iMaxRelErrPct
    );
        integer fd;
        string jsonLine;
    begin
        jsonLine = build_actual_json_line(
            expFrame,
            obsFrame,
            iFrameFailed,
            iCheckedBeats,
            iMismatchBeats,
            iNumericBeats,
            iAvgAbsErr,
            iMaxAbsErr,
            iAvgRelErrPct,
            iMaxRelErrPct
        );
        fd = $fopen(m_cfg.m_actual_jsonl_path, "a");
        if (fd == 0) begin
            m_error_count++;
            $display("[TB][ERROR] Failed to open %s", m_cfg.m_actual_jsonl_path);
            return;
        end
        $fdisplay(fd, "%s", jsonLine);
        $fclose(fd);
    end
    endfunction

    function automatic void append_mismatch_event(
        input string iReason,
        input TopExpectedFrame expFrame,
        input TopObservedFrame obsFrame,
        input int unsigned iBeatIndex
    );
        integer fd;
        string jsonLine;
    begin
        jsonLine = {
            "{\"frame_id\":", $sformatf("%0d", expFrame.m_frame_id),
            ",\"beat\":", $sformatf("%0d", iBeatIndex),
            ",\"reason\":\"", iReason, "\"",
            ",\"scenario\":\"", expFrame.m_scenario_tag, "\"",
            ",\"input_hex_csv\":\"", fnHexCsv32(expFrame.m_input_samples), "\"",
            ",\"expected_hex_csv\":\"", fnHexCsv32(expFrame.m_output_samples), "\"",
            ",\"actual_hex_csv\":\"", (obsFrame == null) ? "<none>" : fnHexCsv32(obsFrame.m_samples), "\"",
            "}"
        };
        fd = $fopen(m_cfg.m_mismatch_jsonl_path, "a");
        if (fd == 0) begin
            m_error_count++;
            $display("[TB][ERROR] Failed to open %s", m_cfg.m_mismatch_jsonl_path);
            return;
        end
        $fdisplay(fd, "%s", jsonLine);
        $fclose(fd);
    end
    endfunction

    function automatic int run_python_model();
        string cmd;
        int rc;
    begin
        cmd = {
            "\"", m_cfg.m_python_launcher_path, "\" -E -I",
            " \"", m_cfg.m_python_tool_path, "\"",
            " --in \"", m_cfg.m_input_jsonl_path, "\"",
            " --out \"", m_cfg.m_expected_jsonl_path, "\"",
            " --policy rtl_saturate"
        };
        rc = $system(cmd);
        if (rc != 0) begin
            m_error_count++;
            $display("[TB][ERROR] Golden model failed rc=%0d cmd=%s", rc, cmd);
        end
        return rc;
    end
    endfunction

    function automatic TopExpectedFrame parse_expected_line(input string iLine);
        TopExpectedFrame expFrame;
    begin
        expFrame = new();
        expFrame.m_frame_id = fnJsonInt(iLine, "frame_id");
        expFrame.m_scenario_tag = fnJsonString(iLine, "scenario");
        expFrame.m_input_class = fnTopParseInputClass(fnJsonString(iLine, "input_class"));
        expFrame.m_in_stall_mode = fnTopParseStallMode(fnJsonString(iLine, "in_stall"));
        expFrame.m_out_stall_mode = fnTopParseStallMode(fnJsonString(iLine, "out_stall"));
        expFrame.m_keep_kind = fnTopParseKeepKind(fnJsonString(iLine, "keep_kind"));
        expFrame.m_result_kind = fnTopParseResultKind(fnJsonString(iLine, "result_kind"));
        expFrame.m_reset_phase = fnTopParseResetPhase(fnJsonString(iLine, "reset_phase"));
        expFrame.m_term_kind = fnTopParseTermKind(fnJsonString(iLine, "term_kind"));
        expFrame.m_post_term_rearm = fnTopParsePostTermRearm(fnJsonString(iLine, "post_term_rearm"));
        expFrame.m_special_kind = fnTopParseSpecialKind(fnJsonString(iLine, "special_kind"));
        expFrame.m_reset_epoch = fnJsonInt(iLine, "reset_epoch");
        expFrame.m_scalar_q78 = fnJsonInt(iLine, "scalar_q78");
        expFrame.m_sum_q78 = fnJsonInt(iLine, "sum_q78");
        expFrame.m_raw_argmax = fnJsonInt(iLine, "raw_argmax");
        fnSplitCsvHex32(fnJsonString(iLine, "input_hex_csv"), expFrame.m_input_samples);
        fnSplitCsvHex32(fnJsonString(iLine, "output_hex_csv"), expFrame.m_output_samples);
        fnSplitCsvHex4(fnJsonString(iLine, "keep_hex_csv"), expFrame.m_output_keeps);
        fnSplitCsvInt(fnJsonString(iLine, "argmax_csv"), expFrame.m_quantized_argmax_set);
        return expFrame;
    end
    endfunction

    function automatic TopExpectedFrame load_expected_frame(input int unsigned iFrameId);
        integer fd;
        integer readCount;
        string line;
        TopExpectedFrame expFrame;
    begin
        fd = $fopen(m_cfg.m_expected_jsonl_path, "r");
        if (fd == 0) begin
            m_error_count++;
            $display("[TB][ERROR] Failed to open expected file %s", m_cfg.m_expected_jsonl_path);
            return null;
        end

        expFrame = null;
        while (!$feof(fd)) begin
            line = "";
            readCount = $fgets(line, fd);
            if (line.len() == 0)
                continue;
            if (fnJsonInt(line, "frame_id") == iFrameId)
                expFrame = parse_expected_line(line);
        end
        $fclose(fd);
        return expFrame;
    end
    endfunction

    task automatic build_expected_from_input(input TopObservedFrame inFrame);
        TopExpectedFrame expFrame;
        bit dropFrame;
    begin
        dropFrame = (inFrame.m_reset_epoch != m_reset_epoch);
        if (dropFrame) begin
            `TB_WARN($sformatf("Dropping input frame_id=%0d from stale epoch=%0d", inFrame.m_frame_id, inFrame.m_reset_epoch));
        end else begin
            m_busy_python_call = 1'b1;
            if (append_input_frame(inFrame) == 0) begin
                if (run_python_model() == 0) begin
                    expFrame = load_expected_frame(inFrame.m_frame_id);
                    if (expFrame == null) begin
                        m_error_count++;
                        $display("[TB][ERROR] Missing expected frame_id=%0d in %s", inFrame.m_frame_id, m_cfg.m_expected_jsonl_path);
                    end else begin
                        m_expected_queue.push_back(expFrame);
                        `TB_INFO($sformatf("SCB queued expected frame_id=%0d", expFrame.m_frame_id));
                    end
                end
            end
            m_busy_python_call = 1'b0;
        end
    end
    endtask

    task automatic compare_output_frame(input TopObservedFrame obsFrame);
        TopExpectedFrame expFrame;
        int idx;
        int unsigned actualArgmax;
        int unsigned checkedThisFrame;
        bit frameFailed;
        bit beatMismatch;
        bit hasNumeric;
        shortreal sumProb;
        real expectedReal;
        real actualReal;
        real absErr;
        real relErrPct;
        real relDenom;
        real absErrSumFrame;
        real absErrMaxFrame;
        real relErrSumPctFrame;
        real relErrMaxPctFrame;
        int unsigned mismatchBeatsFrame;
        int unsigned numericBeatsFrame;
        real avgAbsErrFrame;
        real avgRelErrPctFrame;
        bit ignoreFrame;
    begin
        ignoreFrame = (obsFrame == null);
        checkedThisFrame = 0;
        frameFailed = 1'b0;
        absErrSumFrame = 0.0;
        absErrMaxFrame = 0.0;
        relErrSumPctFrame = 0.0;
        relErrMaxPctFrame = 0.0;
        mismatchBeatsFrame = 0;
        numericBeatsFrame = 0;
        if (!ignoreFrame && (obsFrame.m_reset_epoch != m_reset_epoch)) begin
            `TB_WARN($sformatf("Ignoring stale output frame from epoch=%0d", obsFrame.m_reset_epoch));
            ignoreFrame = 1'b1;
        end

        if (!ignoreFrame) begin
            if (m_expected_queue.size() == 0) begin
                m_error_count++;
                $display("[TB][ERROR] Output frame arrived with empty expected queue: actual=%s", obsFrame.sprint());
            end else begin
                expFrame = m_expected_queue.pop_front();

                if (obsFrame.m_samples.size() != expFrame.m_output_samples.size()) begin
                    frameFailed = 1'b1;
                    report_mismatch("output_length", expFrame, obsFrame, 0);
                end

                for (idx = 0; idx < expFrame.m_output_samples.size(); idx++) begin
                    m_checked_count++;
                    checkedThisFrame++;
                    beatMismatch = 1'b0;
                    hasNumeric = 1'b0;
                    absErr = 0.0;
                    relErrPct = 0.0;

                    if (idx < obsFrame.m_samples.size()) begin
                        expectedReal = fnTopBitsToShortreal(expFrame.m_output_samples[idx]);
                        actualReal = fnTopBitsToShortreal(obsFrame.m_samples[idx]);
                        absErr = fnTopAbsReal(actualReal - expectedReal);
                        relDenom = fnTopAbsReal(expectedReal);
                        if (relDenom <= 1.0e-12) begin
                            if (absErr <= 1.0e-12)
                                relErrPct = 0.0;
                            else
                                relErrPct = 100.0;
                        end else begin
                            relErrPct = (absErr * 100.0) / relDenom;
                        end
                        hasNumeric = 1'b1;
                        numericBeatsFrame++;
                        absErrSumFrame += absErr;
                        relErrSumPctFrame += relErrPct;
                        if (absErr > absErrMaxFrame)
                            absErrMaxFrame = absErr;
                        if (relErrPct > relErrMaxPctFrame)
                            relErrMaxPctFrame = relErrPct;
                    end

                    if ((idx >= obsFrame.m_samples.size()) || (obsFrame.m_samples[idx] !== expFrame.m_output_samples[idx])) begin
                        beatMismatch = 1'b1;
                        frameFailed = 1'b1;
                        mismatchBeatsFrame++;
                        report_mismatch("output_data", expFrame, obsFrame, idx);
                    end else if ((idx >= obsFrame.m_keeps.size()) || (obsFrame.m_keeps[idx] !== expFrame.m_output_keeps[idx])) begin
                        beatMismatch = 1'b1;
                        frameFailed = 1'b1;
                        mismatchBeatsFrame++;
                        report_mismatch("output_keep", expFrame, obsFrame, idx);
                    end

                    m_goldenStats.note_beat(expFrame.m_scenario_tag, beatMismatch, hasNumeric, absErr, relErrPct);
                end

                if (obsFrame.m_last_count != 1) begin
                    frameFailed = 1'b1;
                    report_mismatch("output_last_count", expFrame, obsFrame, 0);
                end

                actualArgmax = fnActualArgmax(obsFrame.m_samples);
                if (!fnIndexInSet(actualArgmax, expFrame.m_quantized_argmax_set)) begin
                    m_warning_count++;
                    $display(
                        "[TB][WARN] Actual argmax=%0d not in quantized argmax set for frame_id=%0d",
                        actualArgmax,
                        expFrame.m_frame_id
                    );
                end

                sumProb = fnSumProb(obsFrame.m_samples);
                if (((sumProb - 1.0) > LP_TOP_SUM_TOLERANCE) || ((1.0 - sumProb) > LP_TOP_SUM_TOLERANCE)) begin
                    frameFailed = 1'b1;
                    report_mismatch("sum_probability", expFrame, obsFrame, 0);
                end

                avgAbsErrFrame = 0.0;
                avgRelErrPctFrame = 0.0;
                if (numericBeatsFrame != 0) begin
                    avgAbsErrFrame = absErrSumFrame / numericBeatsFrame;
                    avgRelErrPctFrame = relErrSumPctFrame / numericBeatsFrame;
                end

                m_goldenStats.note_frame_result(expFrame.m_scenario_tag, frameFailed);
                append_actual_frame(
                    expFrame,
                    obsFrame,
                    frameFailed,
                    checkedThisFrame,
                    mismatchBeatsFrame,
                    numericBeatsFrame,
                    avgAbsErrFrame,
                    absErrMaxFrame,
                    avgRelErrPctFrame,
                    relErrMaxPctFrame
                );

                if (m_coverage != null)
                    m_coverage.note_checked_beats(expFrame.m_scenario_tag, checkedThisFrame);

                if (m_coverage != null)
                    m_coverage.sample_frame(expFrame, obsFrame);

                if (frameFailed) begin
                    `TB_INFO($sformatf(
                        "SCB FAIL frame_id=%0d checked_beats=%0d mismatch_beats=%0d",
                        expFrame.m_frame_id,
                        obsFrame.m_samples.size(),
                        mismatchBeatsFrame
                    ));
                end else begin
                    `TB_INFO($sformatf(
                        "SCB PASS frame_id=%0d checked_beats=%0d",
                        expFrame.m_frame_id,
                        obsFrame.m_samples.size()
                    ));
                end
            end
        end
    end
    endtask

    task automatic watch_reset();
    begin
        if (m_prev_rstn && !vif_TOP.iRstn) begin
            m_reset_epoch++;
            if (m_expected_queue.size() > 0)
                `TB_WARN($sformatf("Reset flush dropped %0d expected frame(s)", m_expected_queue.size()));
            m_expected_queue.delete();
        end
        m_prev_rstn = vif_TOP.iRstn;
    end
    endtask

    function bit is_idle();
        return (m_expected_queue.size() == 0) && !m_busy_python_call;
    endfunction

    task automatic stop();
    begin
        m_stop_requested = 1'b1;
    end
    endtask

    virtual task run();
        TopObservedFrame inputFrame;
        TopObservedFrame outputFrame;
    begin
        forever begin
            @(posedge vif_TOP.iClk);
            watch_reset();

            if (mbx_in2scb.try_get(inputFrame))
                build_expected_from_input(inputFrame);

            if (mbx_out2scb.try_get(outputFrame))
                compare_output_frame(outputFrame);

            if (m_stop_requested && is_idle())
                break;
        end
    end
    endtask
endclass

`endif
