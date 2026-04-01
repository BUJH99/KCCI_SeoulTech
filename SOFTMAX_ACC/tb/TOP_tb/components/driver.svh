`ifndef TOP_DRIVER_SVH
`define TOP_DRIVER_SVH

class TopDriver;
    virtual TOP_if        vif_TOP;
    TopConfig             m_cfg;
    mailbox #(TopFrameTx) mbx_gen2drv;
    TopFrameTx            m_pending_sink_frames[$];
    bit                   m_stop_requested;
    bit                   m_source_done;
    bit                   m_sink_done;

    function new(
        virtual TOP_if vif_TOP,
        TopConfig cfg,
        mailbox #(TopFrameTx) iMbxGen2Drv
    );
        this.vif_TOP = vif_TOP;
        this.m_cfg = cfg;
        this.mbx_gen2drv = iMbxGen2Drv;
        this.m_stop_requested = 1'b0;
        this.m_source_done = 1'b0;
        this.m_sink_done = 1'b0;
    endfunction

    function automatic TopResetPhaseE fnCurrentResetPhase();
    begin
        if (vif_TOP.oMAxisValid)
            return TOP_RESET_PHASE_OUTPUT_VALID;
        if (vif_TOP.iSAxisValid)
            return TOP_RESET_PHASE_CAPTURE;
        if (vif_TOP.probe_downscale_valid || vif_TOP.probe_exp_sum_valid || vif_TOP.probe_sum_valid ||
            vif_TOP.probe_ln_valid || vif_TOP.probe_sub_valid || vif_TOP.probe_exp_out_valid ||
            vif_TOP.probe_sub_busy || vif_TOP.probe_sub_frameStored || vif_TOP.probe_sub_readPending)
            return TOP_RESET_PHASE_REPLAY;
        return TOP_RESET_PHASE_IDLE;
    end
    endfunction

    function automatic int unsigned fnInputGapCycles(input TopFrameTx txItem, input int unsigned iBeatIndex);
    begin
        if (iBeatIndex < txItem.m_input_gap_cycles.size())
            return txItem.m_input_gap_cycles[iBeatIndex];

        case (txItem.m_in_stall_mode)
            TOP_STALL_LIGHT:     return ((iBeatIndex % 3) == 1) ? 1 : 0;
            TOP_STALL_HEAVY:     return (iBeatIndex % 2) ? 2 : 1;
            TOP_STALL_ALTERNATE: return iBeatIndex[0];
            TOP_STALL_BURST:     return ((iBeatIndex % 5) == 4) ? 3 : 0;
            TOP_STALL_RANDOM:    return ((txItem.m_frame_id + iBeatIndex * 7) % 4);
            default:             return 0;
        endcase
    end
    endfunction

    function automatic bit fnSinkReadyValue(input TopFrameTx txItem, input int unsigned iCycleIndex);
    begin
        if (txItem.m_sink_ready_script.size() > 0) begin
            if (iCycleIndex < txItem.m_sink_ready_script.size())
                return txItem.m_sink_ready_script[iCycleIndex];
            return txItem.m_sink_ready_script[txItem.m_sink_ready_script.size() - 1];
        end

        case (txItem.m_out_stall_mode)
            TOP_STALL_LIGHT:     return ((iCycleIndex % 5) != 2);
            TOP_STALL_HEAVY:     return ((iCycleIndex % 3) == 2);
            TOP_STALL_ALTERNATE: return !iCycleIndex[0];
            TOP_STALL_BURST:     return ((iCycleIndex % 8) < 5);
            TOP_STALL_RANDOM:    return (((txItem.m_frame_id * 13) + iCycleIndex) % 4) != 0;
            default:             return 1'b1;
        endcase
    end
    endfunction

    task automatic wait_reset_release();
    begin
        while (!vif_TOP.iRstn)
            @(posedge vif_TOP.iClk);
    end
    endtask

    task automatic pulse_reset_cycles(input int unsigned iCycles = LP_TOP_RESET_CYCLES);
    begin
        vif_TOP.iSAxisValid <= 1'b0;
        vif_TOP.iSAxisLast <= 1'b0;
        vif_TOP.iSAxisData <= '0;
        vif_TOP.iSAxisKeep <= 4'hF;
        vif_TOP.iMAxisReady <= 1'b0;
        vif_TOP.iRstn <= 1'b0;
        repeat (iCycles) @(posedge vif_TOP.iClk);
        vif_TOP.iRstn <= 1'b1;
        repeat (2) @(posedge vif_TOP.iClk);
    end
    endtask

    task automatic inject_reset_when_phase(
        input TopResetPhaseE iPhase,
        input int unsigned iCycles = LP_TOP_RESET_CYCLES
    );
        int unsigned guardCycles;
        bit timedOut;
    begin
        guardCycles = 0;
        timedOut = 1'b0;
        while ((fnCurrentResetPhase() != iPhase) && !timedOut) begin
            @(posedge vif_TOP.iClk);
            guardCycles++;
            if (guardCycles > m_cfg.m_timeout_cycles) begin
                vif_TOP.note_env_error("inject_reset_when_phase", $sformatf("Timed out waiting for phase=%s", fnTopResetPhaseName(iPhase)));
                timedOut = 1'b1;
            end
        end
        if (!timedOut)
            pulse_reset_cycles(iCycles);
    end
    endtask

    task automatic drive_one(input TopFrameTx txItem);
        int unsigned idx;
        int unsigned gapCycles;
        bit          abortFrame;
        bit          driveLast;
        bit          skipFrame;
    begin
        abortFrame = 1'b0;
        skipFrame = 1'b0;
        if (txItem.size() == 0) begin
            vif_TOP.note_env_error("legal_input_last_generation", "Zero-length frame is illegal");
            skipFrame = 1'b1;
        end

        if (!skipFrame &&
            (txItem.m_term_kind == TOP_TERM_CMAX_ONLY || txItem.m_term_kind == TOP_TERM_ILAST_AND_CMAX) &&
            (txItem.size() != m_cfg.m_max_frame_len))
            vif_TOP.note_env_error("legal_input_last_generation", "cmax termination requires max-length frame");

        if (skipFrame) begin
            vif_TOP.iSAxisValid <= 1'b0;
            vif_TOP.iSAxisLast <= 1'b0;
            vif_TOP.iSAxisData <= '0;
            vif_TOP.iSAxisKeep <= 4'hF;
        end else begin
            m_pending_sink_frames.push_back(txItem.clone());

            for (idx = 0; idx < txItem.size(); idx++) begin
                wait_reset_release();
                gapCycles = fnInputGapCycles(txItem, idx);
                repeat (gapCycles) begin
                    vif_TOP.iSAxisValid <= 1'b0;
                    vif_TOP.iSAxisLast <= 1'b0;
                    vif_TOP.iSAxisData <= '0;
                    vif_TOP.iSAxisKeep <= 4'hF;
                    @(posedge vif_TOP.iClk);
                    if (!vif_TOP.iRstn) begin
                        abortFrame = 1'b1;
                        break;
                    end
                end
                if (abortFrame)
                    break;

                driveLast = (idx == (txItem.size() - 1)) && (txItem.m_term_kind != TOP_TERM_CMAX_ONLY);
                vif_TOP.iSAxisData <= txItem.m_samples[idx];
                vif_TOP.iSAxisKeep <= txItem.m_keeps[idx];
                vif_TOP.iSAxisLast <= driveLast;
                vif_TOP.iSAxisValid <= 1'b1;

                do begin
                    @(posedge vif_TOP.iClk);
                    if (!vif_TOP.iRstn) begin
                        abortFrame = 1'b1;
                        break;
                    end
                end while (!(vif_TOP.iSAxisValid && vif_TOP.oSAxisReady));

                if (abortFrame)
                    break;
            end
        end

        vif_TOP.iSAxisValid <= 1'b0;
        vif_TOP.iSAxisLast <= 1'b0;
        vif_TOP.iSAxisData <= '0;
        vif_TOP.iSAxisKeep <= 4'hF;
    end
    endtask

    virtual task run_source();
        TopFrameTx txItem;
    begin
        m_source_done = 1'b0;
        vif_TOP.iSAxisValid <= 1'b0;
        vif_TOP.iSAxisLast <= 1'b0;
        vif_TOP.iSAxisData <= '0;
        vif_TOP.iSAxisKeep <= 4'hF;

        forever begin
            mbx_gen2drv.get(txItem);
            if (txItem == null) begin
                m_source_done = 1'b1;
                break;
            end
            if (m_stop_requested)
                break;
            drive_one(txItem);
        end
    end
    endtask

    virtual task run_sink();
        TopFrameTx activeTx;
        int unsigned cycleIdx;
        bit startedOutput;
    begin
        activeTx = null;
        cycleIdx = 0;
        startedOutput = 1'b0;
        m_sink_done = 1'b0;
        vif_TOP.iMAxisReady <= 1'b0;

        forever begin
            @(posedge vif_TOP.iClk);

            if (!vif_TOP.iRstn) begin
                vif_TOP.iMAxisReady <= 1'b0;
                activeTx = null;
                cycleIdx = 0;
                startedOutput = 1'b0;
                continue;
            end

            if ((activeTx == null) && (m_pending_sink_frames.size() > 0)) begin
                activeTx = m_pending_sink_frames.pop_front();
                cycleIdx = 0;
                startedOutput = 1'b0;
            end

            if (activeTx == null) begin
                vif_TOP.iMAxisReady <= 1'b1;
                if (m_stop_requested && m_source_done) begin
                    m_sink_done = 1'b1;
                    break;
                end
                continue;
            end

            if (!startedOutput && !vif_TOP.oMAxisValid) begin
                vif_TOP.iMAxisReady <= 1'b1;
                continue;
            end

            startedOutput = startedOutput || vif_TOP.oMAxisValid;
            vif_TOP.iMAxisReady <= fnSinkReadyValue(activeTx, cycleIdx);
            cycleIdx++;

            if (vif_TOP.oMAxisValid && vif_TOP.iMAxisReady && vif_TOP.oMAxisLast) begin
                activeTx = null;
                cycleIdx = 0;
                startedOutput = 1'b0;
            end
        end
    end
    endtask

    virtual task run();
    begin
        fork
            run_source();
            run_sink();
        join_none
    end
    endtask

    task automatic stop();
    begin
        m_stop_requested = 1'b1;
    end
    endtask

    function bit is_source_done();
        return m_source_done;
    endfunction

    function bit is_sink_done();
        return m_sink_done;
    endfunction
endclass

`endif
