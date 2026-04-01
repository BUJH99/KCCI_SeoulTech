`ifndef TOP_MONITOR_SVH
`define TOP_MONITOR_SVH

class TopMonitor;
    virtual TOP_if             vif_TOP;
    mailbox #(TopFrameTx)      mbx_gen2mon;
    mailbox #(TopObservedFrame) mbx_in2scb;
    mailbox #(TopObservedFrame) mbx_out2scb;
    TopFrameTx                 m_plan_queue[$];
    TopFrameTx                 m_active_plan;
    TopObservedFrame           m_input_frame;
    TopObservedFrame           m_output_frame;
    int unsigned               m_reset_epoch;
    bit                        m_stop_requested;
    bit                        m_metadata_done;
    bit                        m_prev_rstn;

    function new(
        virtual TOP_if vif_TOP,
        mailbox #(TopFrameTx) iMbxGen2Mon,
        mailbox #(TopObservedFrame) iMbxIn2Scb,
        mailbox #(TopObservedFrame) iMbxOut2Scb
    );
        this.vif_TOP = vif_TOP;
        this.mbx_gen2mon = iMbxGen2Mon;
        this.mbx_in2scb = iMbxIn2Scb;
        this.mbx_out2scb = iMbxOut2Scb;
        this.m_reset_epoch = 0;
        this.m_stop_requested = 1'b0;
        this.m_metadata_done = 1'b0;
        this.m_prev_rstn = 1'b0;
        this.m_active_plan = null;
        this.m_input_frame = null;
        this.m_output_frame = null;
    endfunction

    task automatic fetch_metadata();
        TopFrameTx txItem;
    begin
        if (mbx_gen2mon.try_get(txItem)) begin
            if (txItem == null)
                m_metadata_done = 1'b1;
            else
                m_plan_queue.push_back(txItem.clone());
        end
    end
    endtask

    function automatic TopFrameTx pop_plan();
    begin
        if (m_plan_queue.size() == 0)
            return null;
        return m_plan_queue.pop_front();
    end
    endfunction

    task automatic discard_partials_on_reset();
    begin
        if (m_input_frame != null)
            `TB_WARN($sformatf("Dropping partial input frame on reset, epoch=%0d", m_reset_epoch));
        if (m_output_frame != null)
            `TB_WARN($sformatf("Dropping partial output frame on reset, epoch=%0d", m_reset_epoch));
        m_input_frame = null;
        m_output_frame = null;
        m_active_plan = null;
    end
    endtask

    function automatic bit is_idle();
        return (m_input_frame == null) && (m_output_frame == null);
    endfunction

    task automatic stop();
    begin
        m_stop_requested = 1'b1;
    end
    endtask

    virtual task run();
    begin
        forever begin
            @(posedge vif_TOP.iClk);
            fetch_metadata();

            if (m_prev_rstn && !vif_TOP.iRstn) begin
                m_reset_epoch++;
                discard_partials_on_reset();
            end

            if (vif_TOP.iRstn && vif_TOP.iSAxisValid && vif_TOP.oSAxisReady) begin
                if (m_input_frame == null) begin
                    m_input_frame = new();
                    m_active_plan = pop_plan();
                    if (m_active_plan != null) begin
                        m_input_frame.m_frame_id = m_active_plan.m_frame_id;
                        m_input_frame.m_scenario_tag = m_active_plan.m_scenario_tag;
                        m_input_frame.m_input_class = m_active_plan.m_input_class;
                        m_input_frame.m_in_stall_mode = m_active_plan.m_in_stall_mode;
                        m_input_frame.m_out_stall_mode = m_active_plan.m_out_stall_mode;
                        m_input_frame.m_keep_kind = m_active_plan.m_keep_kind;
                        m_input_frame.m_result_kind = m_active_plan.m_result_kind;
                        m_input_frame.m_reset_phase = m_active_plan.m_reset_phase;
                        m_input_frame.m_term_kind = m_active_plan.m_term_kind;
                        m_input_frame.m_post_term_rearm = m_active_plan.m_post_term_rearm;
                        m_input_frame.m_special_kind = m_active_plan.m_special_kind;
                        m_input_frame.m_expect_abort_on_reset = m_active_plan.m_expect_abort_on_reset;
                    end
                    m_input_frame.m_reset_epoch = m_reset_epoch;
                end
                m_input_frame.append_observed(vif_TOP.iSAxisData, vif_TOP.iSAxisKeep, vif_TOP.iSAxisLast);
                if (vif_TOP.iSAxisLast || (m_input_frame.size() == 1024)) begin
                    mbx_in2scb.put(m_input_frame.clone());
                    m_input_frame = null;
                    m_active_plan = null;
                end
            end

            if (vif_TOP.iRstn && vif_TOP.oMAxisValid && vif_TOP.iMAxisReady) begin
                if (m_output_frame == null) begin
                    m_output_frame = new();
                    m_output_frame.m_reset_epoch = m_reset_epoch;
                end
                m_output_frame.append_observed(vif_TOP.oMAxisData, vif_TOP.oMAxisKeep, vif_TOP.oMAxisLast);
                if (vif_TOP.oMAxisLast) begin
                    mbx_out2scb.put(m_output_frame.clone());
                    m_output_frame = null;
                end
            end

            m_prev_rstn = vif_TOP.iRstn;

            if (m_stop_requested && m_metadata_done && is_idle())
                break;
        end
    end
    endtask
endclass

`endif
