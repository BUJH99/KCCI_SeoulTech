`ifndef TOP_ENVIRONMENT_SVH
`define TOP_ENVIRONMENT_SVH

class TopEnv;
    TopConfig               m_cfg;
    TopGenerator            m_generator;
    TopDriver               m_driver;
    TopMonitor              m_monitor;
    TopCoverage             m_coverage;
    TopScoreboard           m_scoreboard;
    TopShadowChecker        m_shadowChecker;
    mailbox #(TopFrameTx)   mbx_gen2drv;
    mailbox #(TopFrameTx)   mbx_gen2mon;
    mailbox #(TopObservedFrame) mbx_in2scb;
    mailbox #(TopObservedFrame) mbx_out2scb;
    virtual TOP_if          vif_TOP;

    function new(virtual TOP_if vif_TOP, TopConfig cfg = null);
        this.vif_TOP = vif_TOP;
        if (cfg == null)
            this.m_cfg = new();
        else
            this.m_cfg = cfg;

        mbx_gen2drv = new();
        mbx_gen2mon = new();
        mbx_in2scb = new();
        mbx_out2scb = new();

        m_coverage = new();
        m_generator = new(m_cfg, mbx_gen2drv, mbx_gen2mon);
        m_driver = new(vif_TOP, m_cfg, mbx_gen2drv);
        m_monitor = new(vif_TOP, mbx_gen2mon, mbx_in2scb, mbx_out2scb);
        m_scoreboard = new(vif_TOP, m_cfg, m_coverage, mbx_in2scb, mbx_out2scb);
        m_shadowChecker = new(vif_TOP, m_cfg);
    endfunction

    task automatic run();
    begin
        fork
            m_driver.run();
            m_monitor.run();
            m_scoreboard.run();
            m_shadowChecker.run();
            m_generator.run();
        join_none
    end
    endtask

    task automatic start_traffic();
    begin
        m_generator.start();
    end
    endtask

    task automatic stop();
    begin
        m_driver.stop();
        m_monitor.stop();
        m_scoreboard.stop();
        m_shadowChecker.stop();
    end
    endtask

    function automatic int unsigned get_total_errors();
    begin
        return m_scoreboard.m_error_count +
               vif_TOP.m_dut_assert_error_count +
               vif_TOP.m_env_error_count +
               m_shadowChecker.m_error_count;
    end
    endfunction

    function automatic int unsigned get_checked_count();
        return m_scoreboard.m_checked_count;
    endfunction

    function automatic real get_coverage();
        return m_coverage.get_inst_coverage();
    endfunction

    function automatic bit is_quiescent();
    begin
        return m_generator.is_done() &&
               m_driver.is_source_done() &&
               m_monitor.is_idle() &&
               m_scoreboard.is_idle() &&
               m_shadowChecker.is_idle() &&
               !vif_TOP.iSAxisValid &&
               !vif_TOP.oMAxisValid &&
               !vif_TOP.probe_sub_busy &&
               !vif_TOP.probe_sub_frameStored &&
               !vif_TOP.probe_sub_readPending;
    end
    endfunction

    task automatic wait_for_quiescent(output bit oOk);
        int unsigned stableCycles;
        int unsigned waitedCycles;
        bit foundQuiescent;
    begin
        stableCycles = 0;
        waitedCycles = 0;
        foundQuiescent = 1'b0;
        oOk = 1'b0;

        while ((waitedCycles < m_cfg.m_timeout_cycles) && !foundQuiescent) begin
            @(posedge vif_TOP.iClk);
            if (is_quiescent())
                stableCycles++;
            else
                stableCycles = 0;

            if (stableCycles >= LP_TOP_DRAIN_STABLE_CYCLES) begin
                oOk = 1'b1;
                foundQuiescent = 1'b1;
            end
            waitedCycles++;
        end
    end
    endtask
endclass

`endif
