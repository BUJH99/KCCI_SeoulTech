`ifndef TOP_TEST_10_RANDOM_COV_SVH
`define TOP_TEST_10_RANDOM_COV_SVH

class TopTest10RandomCov extends TopBaseTest;
    function new(virtual TOP_if vif_TOP);
        super.new(vif_TOP, "test_10_random_cov");
    endfunction

    function automatic int unsigned pick_length(input int unsigned iPickIndex);
        int unsigned weighted[10];
    begin
        weighted[0] = 1;
        weighted[1] = 2;
        weighted[2] = 3;
        weighted[3] = 5;
        weighted[4] = 7;
        weighted[5] = 16;
        weighted[6] = 63;
        weighted[7] = 64;
        weighted[8] = m_cfg.m_max_frame_len - 1;
        weighted[9] = m_cfg.m_max_frame_len;
        return weighted[iPickIndex % 10];
    end
    endfunction

    function automatic TopInputClassE pick_class(input int unsigned iPickIndex);
    begin
        case (iPickIndex % 5)
            0: return TOP_INPUT_CLASS_UNIFORM;
            1: return TOP_INPUT_CLASS_MIXED_SIGN;
            2: return TOP_INPUT_CLASS_DOMINANT_PEAK;
            3: return TOP_INPUT_CLASS_NEAR_EQUAL;
            default: return TOP_INPUT_CLASS_SPECIAL_EXP;
        endcase
    end
    endfunction

    function automatic TopSpecialFp32E pick_special_kind(input int unsigned iPickIndex);
    begin
        case (iPickIndex % 6)
            0: return TOP_SPECIAL_ZERO;
            1: return TOP_SPECIAL_LARGE_FINITE;
            2: return TOP_SPECIAL_POS_INF;
            3: return TOP_SPECIAL_NEG_INF;
            4: return TOP_SPECIAL_QNAN;
            default: return TOP_SPECIAL_SNAN;
        endcase
    end
    endfunction

    function automatic bit [31:0] pick_special_value(
        input TopSpecialFp32E iSpecialKind,
        input int unsigned iBeatIndex
    );
    begin
        case (iSpecialKind)
            TOP_SPECIAL_ZERO: begin
                if (iBeatIndex[0])
                    return 32'h3f00_0000;
                return 32'h0000_0000;
            end
            TOP_SPECIAL_LARGE_FINITE: begin
                if (iBeatIndex[0])
                    return 32'hff7f_ffff;
                return 32'h7f7f_ffff;
            end
            TOP_SPECIAL_POS_INF: begin
                if (iBeatIndex[0])
                    return 32'hbf80_0000;
                return 32'h7f80_0000;
            end
            TOP_SPECIAL_NEG_INF: begin
                if (iBeatIndex[0])
                    return 32'h3f80_0000;
                return 32'hff80_0000;
            end
            TOP_SPECIAL_QNAN: begin
                if (iBeatIndex[0])
                    return 32'h7fc0_1000;
                return 32'h7fc0_0001;
            end
            default: begin
                if (iBeatIndex[0])
                    return 32'h7f80_0002;
                return 32'h7f80_0001;
            end
        endcase
    end
    endfunction

    function automatic TopStallModeE pick_stall(input int unsigned iPickIndex);
    begin
        case (iPickIndex % 7)
            0: return TOP_STALL_NONE;
            1: return TOP_STALL_LIGHT;
            2: return TOP_STALL_HEAVY;
            3: return TOP_STALL_ALTERNATE;
            4: return TOP_STALL_BURST;
            5: return TOP_STALL_RANDOM;
            default: return TOP_STALL_SCRIPTED;
        endcase
    end
    endfunction

    task automatic apply_scripted_input_profile(
        input TopFrameTx     txItem,
        input int unsigned   iFrameIdx
    );
        int unsigned beatIdx;
        int unsigned gapCycles;
    begin
        txItem.m_input_gap_cycles.delete();
        for (beatIdx = 0; beatIdx < txItem.size(); beatIdx++) begin
            case ((beatIdx + iFrameIdx) % 5)
                1: gapCycles = 1;
                3: gapCycles = 2;
                default: gapCycles = 0;
            endcase
            txItem.m_input_gap_cycles.push_back(gapCycles);
        end
    end
    endtask

    task automatic apply_scripted_sink_profile(
        input TopFrameTx     txItem,
        input int unsigned   iFrameIdx
    );
        bit readyPattern[$];
        int idx;
    begin
        readyPattern.delete();
        for (idx = 0; idx < 10; idx++) begin
            case ((idx + iFrameIdx) % 6)
                2, 5: readyPattern.push_back(1'b0);
                default: readyPattern.push_back(1'b1);
            endcase
        end
        readyPattern.push_back(1'b1);
        txItem.set_sink_script(readyPattern);
    end
    endtask

    task automatic configure_stall_profile(
        input TopFrameTx     txItem,
        input int unsigned   iFrameIdx
    );
    begin
        if (txItem.m_in_stall_mode == TOP_STALL_SCRIPTED)
            apply_scripted_input_profile(txItem, iFrameIdx);
        if (txItem.m_out_stall_mode == TOP_STALL_SCRIPTED)
            apply_scripted_sink_profile(txItem, iFrameIdx);
    end
    endtask

    virtual task configure();
    begin
        super.configure();
        m_cfg.m_random_frame_count = 49;
    end
    endtask

    virtual task build_scenario();
        TopFrameTx txItem;
        bit [31:0] values[$];
        int unsigned frameIdx;
        int unsigned beatIdx;
        int unsigned frameLen;
        int unsigned maxLenOccurrence;
        int          signedBeatValue;
        TopInputClassE classKind;
        TopSpecialFp32E specialKind;
        TopTermKindE termKind;
        TopPostTermRearmE postTermRearm;
        TopStallModeE inStallMode;
        TopStallModeE outStallMode;
        string scenarioName;
    begin
        maxLenOccurrence = 0;
        for (frameIdx = 0; frameIdx < m_cfg.m_random_frame_count; frameIdx++) begin
            values.delete();
            frameLen = pick_length(frameIdx);
            classKind = pick_class(frameIdx);
            specialKind = TOP_SPECIAL_NONE;
            inStallMode = pick_stall(frameIdx / 7);
            outStallMode = pick_stall(frameIdx);
            scenarioName = $sformatf("random_cov_%0d", frameIdx);

            if (classKind == TOP_INPUT_CLASS_SPECIAL_EXP) begin
                specialKind = pick_special_kind(frameIdx);
                scenarioName = {
                    scenarioName,
                    "_",
                    fnTopSpecialKindName(specialKind)
                };
            end

            for (beatIdx = 0; beatIdx < frameLen; beatIdx++) begin
                case (classKind)
                    TOP_INPUT_CLASS_UNIFORM: begin
                        values.push_back(fp32_bits(0.25));
                    end
                    TOP_INPUT_CLASS_MIXED_SIGN: begin
                        signedBeatValue = int'(beatIdx % 7) - 3;
                        values.push_back(fp32_bits(signedBeatValue * 0.25));
                    end
                    TOP_INPUT_CLASS_DOMINANT_PEAK: begin
                        if (beatIdx == (frameIdx % frameLen))
                            values.push_back(fp32_bits(3.0));
                        else
                            values.push_back(fp32_bits(-0.5 + ((beatIdx % 3) * 0.25)));
                    end
                    TOP_INPUT_CLASS_NEAR_EQUAL: begin
                        if (((frameIdx / 5) % 2) == 0) begin
                            if (beatIdx == (frameLen / 2))
                                values.push_back(fp32_bits(0.1260));
                            else
                                values.push_back(fp32_bits(0.1250 + ((beatIdx % 2) * 0.0002)));
                        end else begin
                            values.push_back(fp32_bits(0.125 + ((beatIdx % 3) * 0.0005)));
                        end
                    end
                    default: begin
                        values.push_back(pick_special_value(specialKind, beatIdx));
                    end
                endcase
            end

            if (frameLen == m_cfg.m_max_frame_len) begin
                case (maxLenOccurrence % 4)
                    0: begin
                        termKind = TOP_TERM_CMAX_ONLY;
                        postTermRearm = TOP_POST_TERM_DELAYED;
                    end
                    1: begin
                        termKind = TOP_TERM_CMAX_ONLY;
                        postTermRearm = TOP_POST_TERM_BACK_TO_BACK;
                    end
                    2: begin
                        termKind = TOP_TERM_ILAST_AND_CMAX;
                        postTermRearm = TOP_POST_TERM_DELAYED;
                    end
                    default: begin
                        termKind = TOP_TERM_ILAST_AND_CMAX;
                        postTermRearm = TOP_POST_TERM_BACK_TO_BACK;
                    end
                endcase
                maxLenOccurrence++;
            end else begin
                termKind = TOP_TERM_ILAST_ONLY;
                postTermRearm = (frameIdx[0]) ? TOP_POST_TERM_BACK_TO_BACK : TOP_POST_TERM_DELAYED;
            end

            txItem = create_frame(
                scenarioName,
                classKind,
                termKind,
                inStallMode,
                outStallMode,
                TopKeepKindE'(frameIdx % 4),
                TOP_RESULT_RANDOM_COV,
                TOP_RESET_PHASE_NONE,
                postTermRearm,
                specialKind
            );
            append_values(txItem, values);
            configure_stall_profile(txItem, frameIdx);
            txItem.apply_keep_kind();
            m_env.m_generator.add_frame(txItem);
        end
    end
    endtask
endclass

`endif
