`ifndef TOP_TRANSACTION_SVH
`define TOP_TRANSACTION_SVH

class TopFrameBase;
    int unsigned       m_frame_id;
    int unsigned       m_reset_epoch;
    string             m_scenario_tag;
    TopInputClassE     m_input_class;
    TopStallModeE      m_in_stall_mode;
    TopStallModeE      m_out_stall_mode;
    TopKeepKindE       m_keep_kind;
    TopResultKindE     m_result_kind;
    TopResetPhaseE     m_reset_phase;
    TopTermKindE       m_term_kind;
    TopPostTermRearmE  m_post_term_rearm;
    TopSpecialFp32E    m_special_kind;
    bit                m_expect_abort_on_reset;
    bit [31:0]         m_samples[$];
    bit [3:0]          m_keeps[$];

    function new();
        m_frame_id = 0;
        m_reset_epoch = 0;
        m_scenario_tag = "";
        m_input_class = TOP_INPUT_CLASS_UNKNOWN;
        m_in_stall_mode = TOP_STALL_NONE;
        m_out_stall_mode = TOP_STALL_NONE;
        m_keep_kind = TOP_KEEP_ALL_F;
        m_result_kind = TOP_RESULT_NORMAL;
        m_reset_phase = TOP_RESET_PHASE_NONE;
        m_term_kind = TOP_TERM_ILAST_ONLY;
        m_post_term_rearm = TOP_POST_TERM_DELAYED;
        m_special_kind = TOP_SPECIAL_NONE;
        m_expect_abort_on_reset = 1'b0;
    endfunction

    virtual function int unsigned size();
        return m_samples.size();
    endfunction

    virtual function string sprint();
        return $sformatf(
            "frame_id=%0d scenario=%s len=%0d in_stall=%s out_stall=%s result=%s",
            m_frame_id,
            m_scenario_tag,
            size(),
            fnTopStallModeName(m_in_stall_mode),
            fnTopStallModeName(m_out_stall_mode),
            fnTopResultKindName(m_result_kind)
        );
    endfunction
endclass

class TopFrameTx extends TopFrameBase;
    int unsigned m_input_gap_cycles[$];
    bit          m_sink_ready_script[$];

    function new();
        super.new();
    endfunction

    function void append_sample(
        input bit [31:0] iData,
        input bit [3:0]  iKeep = 4'hF,
        input int unsigned iInputGapCycles = 0
    );
    begin
        m_samples.push_back(iData);
        m_keeps.push_back(iKeep);
        m_input_gap_cycles.push_back(iInputGapCycles);
    end
    endfunction

    function void set_sink_script(input bit iPattern[$]);
        int idx;
    begin
        m_sink_ready_script.delete();
        for (idx = 0; idx < iPattern.size(); idx++)
            m_sink_ready_script.push_back(iPattern[idx]);
        m_out_stall_mode = TOP_STALL_SCRIPTED;
    end
    endfunction

    function void apply_keep_kind();
        int idx;
        bit [3:0] keepValue;
    begin
        if (m_keeps.size() != m_samples.size()) begin
            m_keeps.delete();
            for (idx = 0; idx < m_samples.size(); idx++)
                m_keeps.push_back(4'hF);
        end
        for (idx = 0; idx < m_samples.size(); idx++) begin
            case (m_keep_kind)
                TOP_KEEP_ALT: begin
                    if (idx[0])
                        keepValue = 4'h5;
                    else
                        keepValue = 4'hA;
                end
                TOP_KEEP_ZERO: begin
                    keepValue = 4'h0;
                end
                TOP_KEEP_RANDOM: begin
                    keepValue = $urandom_range(0, 15);
                end
                default: begin
                    keepValue = 4'hF;
                end
            endcase
            m_keeps[idx] = keepValue;
        end
    end
    endfunction

    function TopFrameTx clone();
        TopFrameTx txClone;
        int idx;
    begin
        txClone = new();
        txClone.m_frame_id = m_frame_id;
        txClone.m_reset_epoch = m_reset_epoch;
        txClone.m_scenario_tag = m_scenario_tag;
        txClone.m_input_class = m_input_class;
        txClone.m_in_stall_mode = m_in_stall_mode;
        txClone.m_out_stall_mode = m_out_stall_mode;
        txClone.m_keep_kind = m_keep_kind;
        txClone.m_result_kind = m_result_kind;
        txClone.m_reset_phase = m_reset_phase;
        txClone.m_term_kind = m_term_kind;
        txClone.m_post_term_rearm = m_post_term_rearm;
        txClone.m_special_kind = m_special_kind;
        txClone.m_expect_abort_on_reset = m_expect_abort_on_reset;
        for (idx = 0; idx < m_samples.size(); idx++)
            txClone.m_samples.push_back(m_samples[idx]);
        for (idx = 0; idx < m_keeps.size(); idx++)
            txClone.m_keeps.push_back(m_keeps[idx]);
        for (idx = 0; idx < m_input_gap_cycles.size(); idx++)
            txClone.m_input_gap_cycles.push_back(m_input_gap_cycles[idx]);
        for (idx = 0; idx < m_sink_ready_script.size(); idx++)
            txClone.m_sink_ready_script.push_back(m_sink_ready_script[idx]);
        return txClone;
    end
    endfunction
endclass

class TopObservedFrame extends TopFrameBase;
    bit          m_seen_last;
    int unsigned m_last_count;

    function new();
        super.new();
        m_seen_last = 1'b0;
        m_last_count = 0;
    endfunction

    function void append_observed(input bit [31:0] iData, input bit [3:0] iKeep, input bit iLast);
    begin
        m_samples.push_back(iData);
        m_keeps.push_back(iKeep);
        if (iLast) begin
            m_seen_last = 1'b1;
            m_last_count++;
        end
    end
    endfunction

    function TopObservedFrame clone();
        TopObservedFrame frameClone;
        int idx;
    begin
        frameClone = new();
        frameClone.m_frame_id = m_frame_id;
        frameClone.m_reset_epoch = m_reset_epoch;
        frameClone.m_scenario_tag = m_scenario_tag;
        frameClone.m_input_class = m_input_class;
        frameClone.m_in_stall_mode = m_in_stall_mode;
        frameClone.m_out_stall_mode = m_out_stall_mode;
        frameClone.m_keep_kind = m_keep_kind;
        frameClone.m_result_kind = m_result_kind;
        frameClone.m_reset_phase = m_reset_phase;
        frameClone.m_term_kind = m_term_kind;
        frameClone.m_post_term_rearm = m_post_term_rearm;
        frameClone.m_special_kind = m_special_kind;
        frameClone.m_expect_abort_on_reset = m_expect_abort_on_reset;
        frameClone.m_seen_last = m_seen_last;
        frameClone.m_last_count = m_last_count;
        for (idx = 0; idx < m_samples.size(); idx++)
            frameClone.m_samples.push_back(m_samples[idx]);
        for (idx = 0; idx < m_keeps.size(); idx++)
            frameClone.m_keeps.push_back(m_keeps[idx]);
        return frameClone;
    end
    endfunction
endclass

class TopExpectedFrame extends TopFrameBase;
    bit [31:0]      m_input_samples[$];
    bit [31:0]      m_output_samples[$];
    bit [3:0]       m_output_keeps[$];
    int unsigned    m_quantized_argmax_set[$];
    int signed      m_scalar_q78;
    int signed      m_sum_q78;
    int unsigned    m_raw_argmax;

    function new();
        super.new();
        m_scalar_q78 = 0;
        m_sum_q78 = 0;
        m_raw_argmax = 0;
    endfunction

    function string sprint();
        return $sformatf(
            "frame_id=%0d scenario=%s out_len=%0d argmax_csv_size=%0d result=%s",
            m_frame_id,
            m_scenario_tag,
            m_output_samples.size(),
            m_quantized_argmax_set.size(),
            fnTopResultKindName(m_result_kind)
        );
    endfunction
endclass

`endif
