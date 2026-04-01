`ifndef TOP_SHADOW_CHECKER_SVH
`define TOP_SHADOW_CHECKER_SVH

class TopShadowChecker;
    virtual TOP_if vif_TOP;
    TopConfig      m_cfg;
    int unsigned   m_error_count;
    bit            m_prev_rstn;
    bit            m_input_frame_active;
    bit            m_output_frame_active;
    int unsigned   m_input_beat_count;
    int unsigned   m_output_last_count;
    int unsigned   m_frames_pending_output;
    bit            m_waiting_post_reset_input;
    bit            m_stop_requested;

    function new(virtual TOP_if vif_TOP, TopConfig cfg);
        this.vif_TOP = vif_TOP;
        this.m_cfg = cfg;
        this.m_error_count = 0;
        this.m_prev_rstn = 1'b0;
        this.m_input_frame_active = 1'b0;
        this.m_output_frame_active = 1'b0;
        this.m_input_beat_count = 0;
        this.m_output_last_count = 0;
        this.m_frames_pending_output = 0;
        this.m_waiting_post_reset_input = 0;
        this.m_stop_requested = 1'b0;
    endfunction

    function void note_error(input string iLabel, input string iMessage);
    begin
        m_error_count++;
        $display("[TB][SHADOW] %s : %s", iLabel, iMessage);
    end
    endfunction

    function bit is_idle();
        return !m_input_frame_active && !m_output_frame_active && (m_frames_pending_output == 0);
    endfunction

    task automatic stop();
    begin
        m_stop_requested = 1'b1;
    end
    endtask

    virtual task run();
        bit inputAccept;
        bit inputFrameStart;
        bit inputFrameDone;
        bit outputAccept;
        bit outputLast;
    begin
        forever begin
            @(posedge vif_TOP.iClk);

            inputAccept = vif_TOP.iRstn && vif_TOP.iSAxisValid && vif_TOP.oSAxisReady;
            outputAccept = vif_TOP.iRstn && vif_TOP.oMAxisValid && vif_TOP.iMAxisReady;
            outputLast = outputAccept && vif_TOP.oMAxisLast;
            inputFrameStart = inputAccept && !m_input_frame_active;
            inputFrameDone = inputAccept &&
                             ((m_input_beat_count + 1) == m_cfg.m_max_frame_len || vif_TOP.iSAxisLast);

            if (m_prev_rstn && !vif_TOP.iRstn) begin
                m_input_frame_active = 1'b0;
                m_output_frame_active = 1'b0;
                m_input_beat_count = 0;
                m_output_last_count = 0;
                m_frames_pending_output = 0;
                m_waiting_post_reset_input = 1'b1;
            end

            if (outputAccept) begin
                if (m_waiting_post_reset_input)
                    note_error("no_stale_output_after_reset", "Observed accepted output before the first post-reset input frame");

                if (!m_output_frame_active) begin
                    m_output_frame_active = 1'b1;
                    m_output_last_count = 0;
                    if (m_frames_pending_output == 0)
                        note_error("post_reset_frame_isolation", "Observed output with no accepted input frame pending");
                end

                if (outputLast)
                    m_output_last_count++;

                if (outputLast) begin
                    if (m_output_last_count != 1)
                        note_error("one_last_per_accepted_output_frame", "Output frame had missing or duplicate LAST");
                    m_output_frame_active = 1'b0;
                    m_output_last_count = 0;
                    if (m_frames_pending_output == 0)
                        note_error("accepted_frame_abort_on_reset", "Output completion saw no pending input frame");
                    else
                        m_frames_pending_output--;
                end
            end

            if (inputAccept) begin
                if (inputFrameStart) begin
                    // The DUT can hold one extra frame in Downscale while an older frame
                    // is still completing downstream. Reject only deeper overlap.
                    if (m_frames_pending_output > 2)
                        note_error(
                            "no_new_frame_accept_before_old_frame_done",
                            "Accepted a fourth overlapping frame before older buffered frames completed"
                        );
                    m_input_frame_active = 1'b1;
                    m_input_beat_count = 0;
                    if (m_waiting_post_reset_input)
                        m_waiting_post_reset_input = 1'b0;
                end

                m_input_beat_count++;

                if (inputFrameDone) begin
                    m_input_frame_active = 1'b0;
                    m_input_beat_count = 0;
                    m_frames_pending_output++;
                end
            end

            m_prev_rstn = vif_TOP.iRstn;

            if (m_stop_requested && is_idle())
                break;
        end
    end
    endtask
endclass

`endif
