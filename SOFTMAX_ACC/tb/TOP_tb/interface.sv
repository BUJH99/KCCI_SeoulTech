interface TOP_if;
    logic        iClk;
    logic        iRstn;

    logic        iSAxisValid;
    logic [31:0] iSAxisData;
    logic        iSAxisLast;
    logic [3:0]  iSAxisKeep;
    logic        oSAxisReady;

    logic        oMAxisValid;
    logic        iMAxisReady;
    logic [31:0] oMAxisData;
    logic        oMAxisLast;
    logic [3:0]  oMAxisKeep;

    logic probe_downscale_valid;
    logic probe_downscale_last;
    logic probe_fanout_ready;
    logic probe_exp_sum_ready;
    logic probe_sub_ready;
    logic probe_exp_sum_valid;
    logic probe_sum_valid;
    logic probe_ln_valid;
    logic probe_sub_valid;
    logic probe_sub_last;
    logic probe_exp_out_valid;
    logic probe_exp_out_last;
    logic probe_u16_fp32_valid;
    logic probe_u16_fp32_last;
    logic probe_sub_frameStored;
    logic probe_sub_busy;
    logic probe_sub_readPending;

    int unsigned m_dut_assert_error_count;
    int unsigned m_env_error_count;

    logic        m_prev_rstn;
    logic        m_prev_output_wait;
    logic        m_prev_input_wait;
    logic        m_prev_oMAxisValid;
    logic [31:0] m_prev_oMAxisData;
    logic        m_prev_oMAxisLast;
    logic [3:0]  m_prev_oMAxisKeep;
    logic [31:0] m_prev_iSAxisData;
    logic        m_prev_iSAxisLast;
    logic [3:0]  m_prev_iSAxisKeep;

    task automatic reset_drive_state();
        iSAxisValid <= 1'b0;
        iSAxisData  <= '0;
        iSAxisLast  <= 1'b0;
        iSAxisKeep  <= 4'hF;
        iMAxisReady <= 1'b0;
    endtask

    task automatic reset_case_state();
        m_dut_assert_error_count = 0;
        m_env_error_count = 0;
        m_prev_rstn = 1'b0;
        m_prev_output_wait = 1'b0;
        m_prev_input_wait = 1'b0;
        m_prev_oMAxisValid = 1'b0;
        m_prev_oMAxisData = '0;
        m_prev_oMAxisLast = 1'b0;
        m_prev_oMAxisKeep = '0;
        m_prev_iSAxisData = '0;
        m_prev_iSAxisLast = 1'b0;
        m_prev_iSAxisKeep = 4'hF;
        reset_drive_state();
    endtask

    function void note_dut_assert(input string iLabel, input string iMessage);
        m_dut_assert_error_count++;
        $display("[TB][ASSERT] %s : %s", iLabel, iMessage);
    endfunction

    function void note_env_error(input string iLabel, input string iMessage);
        m_env_error_count++;
        $display("[TB][ENV] %s : %s", iLabel, iMessage);
    endfunction

    always @(posedge iClk) begin
        if (iRstn) begin
            if ($isunknown({oSAxisReady, oMAxisValid, oMAxisData, oMAxisLast, oMAxisKeep}))
                note_dut_assert("no_xz_dut_outputs", "DUT output channel contains X/Z");
            if (oMAxisKeep !== 4'hF)
                note_dut_assert("output_keep_constant", $sformatf("Expected 4'hF, got 0x%0h", oMAxisKeep));
            if (probe_fanout_ready !== (probe_exp_sum_ready & probe_sub_ready))
                note_dut_assert("fanout_handshake_consistency", "fanout ready is not downstream AND");
        end else begin
            if (oMAxisValid !== 1'b0)
                note_dut_assert("reset_clears_local_valids", "oMAxisValid was not cleared during reset");
            if (probe_downscale_valid || probe_exp_sum_valid || probe_sum_valid || probe_ln_valid ||
                probe_sub_valid || probe_exp_out_valid || probe_u16_fp32_valid)
                note_dut_assert("reset_clears_local_valids", "pipeline valid probe remained high during reset");
            if (probe_sub_frameStored || probe_sub_busy || probe_sub_readPending)
                note_dut_assert("reset_clears_busy_state", "Sub busy/frame state remained high during reset");
        end

        if (m_prev_output_wait && iRstn) begin
            if (oMAxisValid !== 1'b1 || oMAxisData !== m_prev_oMAxisData ||
                oMAxisLast !== m_prev_oMAxisLast || oMAxisKeep !== m_prev_oMAxisKeep)
                note_dut_assert("hold_output_while_wait_ready", "Output channel changed while sink held ready low");
        end

        if (m_prev_input_wait && iRstn) begin
            if (iSAxisData !== m_prev_iSAxisData || iSAxisLast !== m_prev_iSAxisLast || iSAxisKeep !== m_prev_iSAxisKeep)
                note_env_error("hold_input_while_wait_ready", "TB changed input payload while DUT deasserted ready");
        end

        if (!m_prev_rstn && iRstn) begin
            if ($isunknown({iSAxisValid, iSAxisData, iSAxisLast, iSAxisKeep, iMAxisReady}))
                note_env_error("no_tb_protocol_glitch_after_reset_release", "TB drove X/Z on the cycle reset released");
        end

        m_prev_rstn <= iRstn;
        m_prev_output_wait <= oMAxisValid && !iMAxisReady;
        m_prev_input_wait <= iSAxisValid && !oSAxisReady;
        m_prev_oMAxisValid <= oMAxisValid;
        m_prev_oMAxisData <= oMAxisData;
        m_prev_oMAxisLast <= oMAxisLast;
        m_prev_oMAxisKeep <= oMAxisKeep;
        m_prev_iSAxisData <= iSAxisData;
        m_prev_iSAxisLast <= iSAxisLast;
        m_prev_iSAxisKeep <= iSAxisKeep;
    end
endinterface
