`ifndef TOP_COVERAGE_SVH
`define TOP_COVERAGE_SVH

class TopCoverageEntry;
    string           m_scenario_tag;
    int unsigned     m_checked_count;
    int unsigned     m_frame_sample_count;
    int unsigned     m_reset_sample_count;
    int unsigned     m_cov_hit_count;
    int unsigned     m_frame_len;
    int              m_frame_len_idx;
    int              m_union_point_id;
    int              m_reset_phase;
    int              m_term_kind;
    int              m_post_term_rearm;
    int              m_input_class;
    int              m_max_pos_kind;
    int              m_in_stall;
    int              m_out_stall;
    int              m_keep_kind;
    int              m_special_kind;
    int              m_result_kind;
    int              m_output_last_kind;
    int              m_reset_result_combo;
    int              m_len_term_combo;
    int              m_term_rearm_combo;
    int              m_class_maxpos_combo;
    int              m_stall_pair_combo;
    int              m_len_result_combo;
    bit              m_cov_point_hit[string];
    bit              m_union_point_hit[int];
    bit              m_union_goal_hit[166];

    covergroup cg_top_frame;
        option.per_instance = 1;
        option.comment = "Sign-off coverage on reachable scenario space";

        // Keep xsim raw coverage aligned with the intended state space by
        // marking non-applicable samples as ignored and everything else as illegal.
        cp_reset_phase: coverpoint m_reset_phase {
            bins b_idle         = {TOP_RESET_PHASE_IDLE};
            bins b_capture      = {TOP_RESET_PHASE_CAPTURE};
            bins b_replay       = {TOP_RESET_PHASE_REPLAY};
            bins b_output_valid = {TOP_RESET_PHASE_OUTPUT_VALID};
            ignore_bins b_none  = {TOP_RESET_PHASE_NONE};
            illegal_bins b_invalid = default;
        }

        cp_frame_len: coverpoint m_frame_len_idx {
            bins b_1        = {0};
            bins b_2        = {1};
            bins b_3        = {2};
            bins b_5        = {3};
            bins b_7        = {4};
            bins b_16       = {5};
            bins b_63       = {6};
            bins b_64       = {7};
            bins b_cmax_m1  = {8};
            bins b_cmax     = {9};
            ignore_bins b_not_in_goal = {-1};
            illegal_bins b_invalid = default;
        }

        cp_term_kind: coverpoint m_term_kind {
            bins b_iLast_only     = {TOP_TERM_ILAST_ONLY};
            bins b_cmax_only      = {TOP_TERM_CMAX_ONLY};
            bins b_iLast_and_cmax = {TOP_TERM_ILAST_AND_CMAX};
            illegal_bins b_invalid = default;
        }

        cp_post_term_rearm: coverpoint m_post_term_rearm {
            bins b_delayed      = {TOP_POST_TERM_DELAYED};
            bins b_back_to_back = {TOP_POST_TERM_BACK_TO_BACK};
            illegal_bins b_invalid = default;
        }

        cp_input_class: coverpoint m_input_class {
            bins b_uniform       = {TOP_INPUT_CLASS_UNIFORM};
            bins b_mixed_sign    = {TOP_INPUT_CLASS_MIXED_SIGN};
            bins b_dominant_peak = {TOP_INPUT_CLASS_DOMINANT_PEAK};
            bins b_near_equal    = {TOP_INPUT_CLASS_NEAR_EQUAL};
            bins b_special_exp   = {TOP_INPUT_CLASS_SPECIAL_EXP};
            ignore_bins b_unknown = {TOP_INPUT_CLASS_UNKNOWN};
            illegal_bins b_invalid = default;
        }

        cp_max_pos: coverpoint m_max_pos_kind {
            bins b_first  = {0};
            bins b_middle = {1};
            bins b_last   = {2};
            bins b_tie    = {3};
            ignore_bins b_not_applicable = {4};
            illegal_bins b_invalid = default;
        }

        cp_in_stall: coverpoint m_in_stall {
            bins b_none      = {TOP_STALL_NONE};
            bins b_light     = {TOP_STALL_LIGHT};
            bins b_heavy     = {TOP_STALL_HEAVY};
            bins b_alternate = {TOP_STALL_ALTERNATE};
            bins b_burst     = {TOP_STALL_BURST};
            bins b_random    = {TOP_STALL_RANDOM};
            bins b_scripted  = {TOP_STALL_SCRIPTED};
            illegal_bins b_invalid = default;
        }

        cp_out_stall: coverpoint m_out_stall {
            bins b_none      = {TOP_STALL_NONE};
            bins b_light     = {TOP_STALL_LIGHT};
            bins b_heavy     = {TOP_STALL_HEAVY};
            bins b_alternate = {TOP_STALL_ALTERNATE};
            bins b_burst     = {TOP_STALL_BURST};
            bins b_random    = {TOP_STALL_RANDOM};
            bins b_scripted  = {TOP_STALL_SCRIPTED};
            illegal_bins b_invalid = default;
        }

        cp_keep_kind: coverpoint m_keep_kind {
            bins b_all_f = {TOP_KEEP_ALL_F};
            bins b_alt   = {TOP_KEEP_ALT};
            bins b_zero  = {TOP_KEEP_ZERO};
            bins b_rand  = {TOP_KEEP_RANDOM};
            illegal_bins b_invalid = default;
        }

        cp_special_fp32: coverpoint m_special_kind {
            bins b_none         = {TOP_SPECIAL_NONE};
            bins b_zero         = {TOP_SPECIAL_ZERO};
            bins b_large_finite = {TOP_SPECIAL_LARGE_FINITE};
            bins b_pos_inf      = {TOP_SPECIAL_POS_INF};
            bins b_neg_inf      = {TOP_SPECIAL_NEG_INF};
            bins b_qnan         = {TOP_SPECIAL_QNAN};
            bins b_snan         = {TOP_SPECIAL_SNAN};
            illegal_bins b_invalid = default;
        }

        cp_result_kind: coverpoint m_result_kind {
            bins b_normal        = {TOP_RESULT_NORMAL};
            bins b_reset_aborted = {TOP_RESULT_RESET_ABORTED};
            bins b_keep_ignore   = {TOP_RESULT_KEEP_IGNORE};
            bins b_special       = {TOP_RESULT_SPECIAL};
            bins b_protocol      = {TOP_RESULT_PROTOCOL};
            bins b_random_cov    = {TOP_RESULT_RANDOM_COV};
            illegal_bins b_invalid = default;
        }

        cp_output_last: coverpoint m_output_last_kind {
            bins b_missing = {0};
            bins b_single  = {1};
            illegal_bins b_dup = {2};
            illegal_bins b_invalid = default;
        }

        cp_reset_phase_result_combo: coverpoint m_reset_result_combo {
            bins b_combo[4] = {[0:3]};
            ignore_bins b_not_in_goal = {-1};
            illegal_bins b_invalid = default;
        }

        cp_len_term_combo: coverpoint m_len_term_combo {
            bins b_combo[11] = {[0:10]};
            ignore_bins b_not_in_goal = {-1};
            illegal_bins b_invalid = default;
        }

        cp_term_rearm_combo: coverpoint m_term_rearm_combo {
            bins b_combo[6] = {[0:5]};
            ignore_bins b_not_in_goal = {-1};
            illegal_bins b_invalid = default;
        }

        cp_class_maxpos_combo: coverpoint m_class_maxpos_combo {
            bins b_combo[13] = {[0:12]};
            ignore_bins b_not_in_goal = {-1};
            illegal_bins b_invalid = default;
        }

        cp_stall_pair_combo: coverpoint m_stall_pair_combo {
            bins b_combo[49] = {[0:48]};
            illegal_bins b_invalid = default;
        }

        cp_len_result_combo: coverpoint m_len_result_combo {
            bins b_combo[22] = {[0:21]};
            ignore_bins b_not_in_goal = {-1};
            illegal_bins b_invalid = default;
        }
    endgroup

    covergroup cg_union_goal_inst with function sample(input int iUnionPointId);
        option.per_instance = 1;
        option.comment = "Per-instance union coverage over sign-off scenario goals";

        cp_goal_id: coverpoint iUnionPointId {
            bins b_goal[] = {[0:165]};
            illegal_bins b_invalid = default;
        }
    endgroup

    covergroup cg_union_goal_merged with function sample(input int iUnionPointId);
        option.per_instance = 1;
        type_option.merge_instances = 1;
        option.comment = "Merged union coverage over sign-off scenario goals";

        cp_goal_id: coverpoint iUnionPointId {
            bins b_goal[] = {[0:165]};
            illegal_bins b_invalid = default;
        }
    endgroup

    covergroup cg_union_goal_a with function sample(input int iUnionPointId);
        option.per_instance = 1;
        option.comment = "Union coverage chunk 0-41";

        cp_goal_chunk: coverpoint iUnionPointId {
            bins b_goal_000 = {0};
            bins b_goal_001 = {1};
            bins b_goal_002 = {2};
            bins b_goal_003 = {3};
            bins b_goal_004 = {4};
            bins b_goal_005 = {5};
            bins b_goal_006 = {6};
            bins b_goal_007 = {7};
            bins b_goal_008 = {8};
            bins b_goal_009 = {9};
            bins b_goal_010 = {10};
            bins b_goal_011 = {11};
            bins b_goal_012 = {12};
            bins b_goal_013 = {13};
            bins b_goal_014 = {14};
            bins b_goal_015 = {15};
            bins b_goal_016 = {16};
            bins b_goal_017 = {17};
            bins b_goal_018 = {18};
            bins b_goal_019 = {19};
            bins b_goal_020 = {20};
            bins b_goal_021 = {21};
            bins b_goal_022 = {22};
            bins b_goal_023 = {23};
            bins b_goal_024 = {24};
            bins b_goal_025 = {25};
            bins b_goal_026 = {26};
            bins b_goal_027 = {27};
            bins b_goal_028 = {28};
            bins b_goal_029 = {29};
            bins b_goal_030 = {30};
            bins b_goal_031 = {31};
            bins b_goal_032 = {32};
            bins b_goal_033 = {33};
            bins b_goal_034 = {34};
            bins b_goal_035 = {35};
            bins b_goal_036 = {36};
            bins b_goal_037 = {37};
            bins b_goal_038 = {38};
            bins b_goal_039 = {39};
            bins b_goal_040 = {40};
            bins b_goal_041 = {41};
            illegal_bins b_invalid = default;
        }
    endgroup

    covergroup cg_union_goal_b with function sample(input int iUnionPointId);
        option.per_instance = 1;
        option.comment = "Union coverage chunk 42-83";

        cp_goal_chunk: coverpoint iUnionPointId {
            bins b_goal_042 = {42};
            bins b_goal_043 = {43};
            bins b_goal_044 = {44};
            bins b_goal_045 = {45};
            bins b_goal_046 = {46};
            bins b_goal_047 = {47};
            bins b_goal_048 = {48};
            bins b_goal_049 = {49};
            bins b_goal_050 = {50};
            bins b_goal_051 = {51};
            bins b_goal_052 = {52};
            bins b_goal_053 = {53};
            bins b_goal_054 = {54};
            bins b_goal_055 = {55};
            bins b_goal_056 = {56};
            bins b_goal_057 = {57};
            bins b_goal_058 = {58};
            bins b_goal_059 = {59};
            bins b_goal_060 = {60};
            bins b_goal_061 = {61};
            bins b_goal_062 = {62};
            bins b_goal_063 = {63};
            bins b_goal_064 = {64};
            bins b_goal_065 = {65};
            bins b_goal_066 = {66};
            bins b_goal_067 = {67};
            bins b_goal_068 = {68};
            bins b_goal_069 = {69};
            bins b_goal_070 = {70};
            bins b_goal_071 = {71};
            bins b_goal_072 = {72};
            bins b_goal_073 = {73};
            bins b_goal_074 = {74};
            bins b_goal_075 = {75};
            bins b_goal_076 = {76};
            bins b_goal_077 = {77};
            bins b_goal_078 = {78};
            bins b_goal_079 = {79};
            bins b_goal_080 = {80};
            bins b_goal_081 = {81};
            bins b_goal_082 = {82};
            bins b_goal_083 = {83};
            illegal_bins b_invalid = default;
        }
    endgroup

    covergroup cg_union_goal_c with function sample(input int iUnionPointId);
        option.per_instance = 1;
        option.comment = "Union coverage chunk 84-124";

        cp_goal_chunk: coverpoint iUnionPointId {
            bins b_goal_084 = {84};
            bins b_goal_085 = {85};
            bins b_goal_086 = {86};
            bins b_goal_087 = {87};
            bins b_goal_088 = {88};
            bins b_goal_089 = {89};
            bins b_goal_090 = {90};
            bins b_goal_091 = {91};
            bins b_goal_092 = {92};
            bins b_goal_093 = {93};
            bins b_goal_094 = {94};
            bins b_goal_095 = {95};
            bins b_goal_096 = {96};
            bins b_goal_097 = {97};
            bins b_goal_098 = {98};
            bins b_goal_099 = {99};
            bins b_goal_100 = {100};
            bins b_goal_101 = {101};
            bins b_goal_102 = {102};
            bins b_goal_103 = {103};
            bins b_goal_104 = {104};
            bins b_goal_105 = {105};
            bins b_goal_106 = {106};
            bins b_goal_107 = {107};
            bins b_goal_108 = {108};
            bins b_goal_109 = {109};
            bins b_goal_110 = {110};
            bins b_goal_111 = {111};
            bins b_goal_112 = {112};
            bins b_goal_113 = {113};
            bins b_goal_114 = {114};
            bins b_goal_115 = {115};
            bins b_goal_116 = {116};
            bins b_goal_117 = {117};
            bins b_goal_118 = {118};
            bins b_goal_119 = {119};
            bins b_goal_120 = {120};
            bins b_goal_121 = {121};
            bins b_goal_122 = {122};
            bins b_goal_123 = {123};
            bins b_goal_124 = {124};
            illegal_bins b_invalid = default;
        }
    endgroup

    covergroup cg_union_goal_d with function sample(input int iUnionPointId);
        option.per_instance = 1;
        option.comment = "Union coverage chunk 125-165";

        cp_goal_chunk: coverpoint iUnionPointId {
            bins b_goal_125 = {125};
            bins b_goal_126 = {126};
            bins b_goal_127 = {127};
            bins b_goal_128 = {128};
            bins b_goal_129 = {129};
            bins b_goal_130 = {130};
            bins b_goal_131 = {131};
            bins b_goal_132 = {132};
            bins b_goal_133 = {133};
            bins b_goal_134 = {134};
            bins b_goal_135 = {135};
            bins b_goal_136 = {136};
            bins b_goal_137 = {137};
            bins b_goal_138 = {138};
            bins b_goal_139 = {139};
            bins b_goal_140 = {140};
            bins b_goal_141 = {141};
            bins b_goal_142 = {142};
            bins b_goal_143 = {143};
            bins b_goal_144 = {144};
            bins b_goal_145 = {145};
            bins b_goal_146 = {146};
            bins b_goal_147 = {147};
            bins b_goal_148 = {148};
            bins b_goal_149 = {149};
            bins b_goal_150 = {150};
            bins b_goal_151 = {151};
            bins b_goal_152 = {152};
            bins b_goal_153 = {153};
            bins b_goal_154 = {154};
            bins b_goal_155 = {155};
            bins b_goal_156 = {156};
            bins b_goal_157 = {157};
            bins b_goal_158 = {158};
            bins b_goal_159 = {159};
            bins b_goal_160 = {160};
            bins b_goal_161 = {161};
            bins b_goal_162 = {162};
            bins b_goal_163 = {163};
            bins b_goal_164 = {164};
            bins b_goal_165 = {165};
            illegal_bins b_invalid = default;
        }
    endgroup

    function new(string iScenarioTag = "");
        m_scenario_tag = iScenarioTag;
        m_checked_count = 0;
        m_frame_sample_count = 0;
        m_reset_sample_count = 0;
        m_cov_hit_count = 0;
        foreach (m_union_goal_hit[idx])
            m_union_goal_hit[idx] = 1'b0;
        cg_top_frame = new();
        cg_union_goal_inst = new();
        cg_union_goal_merged = new();
        cg_union_goal_a = new();
        cg_union_goal_b = new();
        cg_union_goal_c = new();
        cg_union_goal_d = new();
        reset_sample_fields();
    endfunction

    function automatic void reset_sample_fields();
    begin
        m_reset_phase = TOP_RESET_PHASE_NONE;
        m_frame_len = 0;
        m_frame_len_idx = -1;
        m_union_point_id = -1;
        m_term_kind = TOP_TERM_ILAST_ONLY;
        m_post_term_rearm = TOP_POST_TERM_DELAYED;
        m_input_class = TOP_INPUT_CLASS_UNKNOWN;
        m_max_pos_kind = 4;
        m_in_stall = TOP_STALL_NONE;
        m_out_stall = TOP_STALL_NONE;
        m_keep_kind = TOP_KEEP_ALL_F;
        m_special_kind = TOP_SPECIAL_NONE;
        m_result_kind = TOP_RESULT_NORMAL;
        m_output_last_kind = 0;
        m_reset_result_combo = -1;
        m_len_term_combo = -1;
        m_term_rearm_combo = -1;
        m_class_maxpos_combo = -1;
        m_stall_pair_combo = -1;
        m_len_result_combo = -1;
    end
    endfunction

    function automatic int fnResetResultCombo();
    begin
        if (m_result_kind != TOP_RESULT_RESET_ABORTED)
            return -1;
        case (m_reset_phase)
            TOP_RESET_PHASE_IDLE:         return 0;
            TOP_RESET_PHASE_CAPTURE:      return 1;
            TOP_RESET_PHASE_REPLAY:       return 2;
            TOP_RESET_PHASE_OUTPUT_VALID: return 3;
            default:                      return -1;
        endcase
    end
    endfunction

    function automatic int fnLenTermCombo();
    begin
        case (m_frame_len)
            1:    return (m_term_kind == TOP_TERM_ILAST_ONLY) ? 0  : -1;
            2:    return (m_term_kind == TOP_TERM_ILAST_ONLY) ? 1  : -1;
            3:    return (m_term_kind == TOP_TERM_ILAST_ONLY) ? 2  : -1;
            5:    return (m_term_kind == TOP_TERM_ILAST_ONLY) ? 3  : -1;
            7:    return (m_term_kind == TOP_TERM_ILAST_ONLY) ? 4  : -1;
            16:   return (m_term_kind == TOP_TERM_ILAST_ONLY) ? 5  : -1;
            63:   return (m_term_kind == TOP_TERM_ILAST_ONLY) ? 6  : -1;
            64:   return (m_term_kind == TOP_TERM_ILAST_ONLY) ? 7  : -1;
            1023: return (m_term_kind == TOP_TERM_ILAST_ONLY) ? 8  : -1;
            1024: begin
                if (m_term_kind == TOP_TERM_CMAX_ONLY)
                    return 9;
                if (m_term_kind == TOP_TERM_ILAST_AND_CMAX)
                    return 10;
                return -1;
            end
            default: return -1;
        endcase
    end
    endfunction

    function automatic int fnTermRearmCombo();
    begin
        case (m_term_kind)
            TOP_TERM_ILAST_ONLY: begin
                if (m_post_term_rearm == TOP_POST_TERM_DELAYED)
                    return 0;
                if (m_post_term_rearm == TOP_POST_TERM_BACK_TO_BACK)
                    return 1;
            end
            TOP_TERM_CMAX_ONLY: begin
                if (m_post_term_rearm == TOP_POST_TERM_DELAYED)
                    return 2;
                if (m_post_term_rearm == TOP_POST_TERM_BACK_TO_BACK)
                    return 3;
            end
            TOP_TERM_ILAST_AND_CMAX: begin
                if (m_post_term_rearm == TOP_POST_TERM_DELAYED)
                    return 4;
                if (m_post_term_rearm == TOP_POST_TERM_BACK_TO_BACK)
                    return 5;
            end
            default: begin
            end
        endcase
        return -1;
    end
    endfunction

    function automatic int fnClassMaxPosCombo();
    begin
        case (m_input_class)
            TOP_INPUT_CLASS_UNIFORM: begin
                if (m_max_pos_kind == 3)
                    return 0;
            end
            TOP_INPUT_CLASS_MIXED_SIGN: begin
                if ((m_max_pos_kind >= 0) && (m_max_pos_kind <= 3))
                    return 1 + m_max_pos_kind;
            end
            TOP_INPUT_CLASS_DOMINANT_PEAK: begin
                if ((m_max_pos_kind >= 0) && (m_max_pos_kind <= 2))
                    return 5 + m_max_pos_kind;
            end
            TOP_INPUT_CLASS_NEAR_EQUAL: begin
                if (m_max_pos_kind == 1)
                    return 8;
                if (m_max_pos_kind == 3)
                    return 9;
            end
            TOP_INPUT_CLASS_SPECIAL_EXP: begin
                if (m_max_pos_kind == 0)
                    return 10;
                if (m_max_pos_kind == 2)
                    return 11;
                if (m_max_pos_kind == 3)
                    return 12;
            end
            default: begin
            end
        endcase
        return -1;
    end
    endfunction

    function automatic int fnStallPairCombo();
    begin
        if ((m_in_stall < TOP_STALL_NONE) || (m_in_stall > TOP_STALL_SCRIPTED))
            return -1;
        if ((m_out_stall < TOP_STALL_NONE) || (m_out_stall > TOP_STALL_SCRIPTED))
            return -1;
        return (m_in_stall * 7) + m_out_stall;
    end
    endfunction

    function automatic int fnFrameLenIndex();
    begin
        case (m_frame_len)
            1:    return 0;
            2:    return 1;
            3:    return 2;
            5:    return 3;
            7:    return 4;
            16:   return 5;
            63:   return 6;
            64:   return 7;
            1023: return 8;
            1024: return 9;
            default: return -1;
        endcase
    end
    endfunction

    function automatic int fnLenResultCombo();
        int lenIdx;
    begin
        lenIdx = fnFrameLenIndex();
        case (m_result_kind)
            TOP_RESULT_NORMAL: begin
                if (lenIdx >= 0)
                    return lenIdx;
            end
            TOP_RESULT_RESET_ABORTED: begin
                if (m_frame_len == 1)
                    return 10;
            end
            TOP_RESULT_SPECIAL: begin
                if (m_frame_len == 2)
                    return 11;
            end
            TOP_RESULT_RANDOM_COV: begin
                if (lenIdx >= 0)
                    return 12 + lenIdx;
            end
            default: begin
            end
        endcase
        return -1;
    end
    endfunction

    function automatic int fnMaxPosKind(input TopExpectedFrame expFrame);
        int maxIdx;
    begin
        if (expFrame.m_quantized_argmax_set.size() == 0)
            return 4;
        if (expFrame.m_quantized_argmax_set.size() > 1)
            return 3;
        maxIdx = expFrame.m_quantized_argmax_set[0];
        if (maxIdx == 0)
            return 0;
        if (maxIdx == (expFrame.m_input_samples.size() - 1))
            return 2;
        return 1;
    end
    endfunction

    function automatic string fnFrameLenBinName(input int unsigned iFrameLen);
    begin
        case (iFrameLen)
            1:    return "1";
            2:    return "2";
            3:    return "3";
            5:    return "5";
            7:    return "7";
            16:   return "16";
            63:   return "63";
            64:   return "64";
            1023: return "1023";
            1024: return "1024";
            default: return "other";
        endcase
    end
    endfunction

    function automatic string fnMaxPosBinName(input int iMaxPosKind);
    begin
        case (iMaxPosKind)
            0: return "first";
            1: return "middle";
            2: return "last";
            3: return "tie";
            default: return "none";
        endcase
    end
    endfunction

    function automatic string fnOutputLastBinName(input int iOutputLastKind);
    begin
        case (iOutputLastKind)
            1: return "single";
            2: return "dup";
            default: return "missing";
        endcase
    end
    endfunction

    function automatic int unsigned fnTotalCovPointCount();
    begin
        return 267;
    end
    endfunction

    function automatic int unsigned fnTotalUnionGoalCount();
    begin
        return 166;
    end
    endfunction

    function automatic int unsigned fnCoverageTenthsFromReal(input real iCoverageValue);
        real coverageValue;
        int unsigned scaledValue;
    begin
        coverageValue = iCoverageValue;
        if (coverageValue < 0.0)
            coverageValue = 0.0;
        if (coverageValue > 100.0)
            coverageValue = 100.0;
        scaledValue = $rtoi((coverageValue * 10.0) + 0.5);
        return scaledValue;
    end
    endfunction

    function automatic int fnResetPhasePointId();
    begin
        if ((m_reset_phase >= TOP_RESET_PHASE_IDLE) && (m_reset_phase <= TOP_RESET_PHASE_OUTPUT_VALID))
            return m_reset_phase;
        return -1;
    end
    endfunction

    function automatic int fnFrameLenPointId();
    begin
        if (m_frame_len_idx >= 0)
            return 4 + m_frame_len_idx;
        return -1;
    end
    endfunction

    function automatic int fnTermKindPointId();
    begin
        if ((m_term_kind >= TOP_TERM_ILAST_ONLY) && (m_term_kind <= TOP_TERM_ILAST_AND_CMAX))
            return 14 + m_term_kind;
        return -1;
    end
    endfunction

    function automatic int fnPostTermRearmPointId();
    begin
        if ((m_post_term_rearm >= TOP_POST_TERM_DELAYED) && (m_post_term_rearm <= TOP_POST_TERM_BACK_TO_BACK))
            return 17 + m_post_term_rearm;
        return -1;
    end
    endfunction

    function automatic int fnInputClassPointId();
    begin
        case (m_input_class)
            TOP_INPUT_CLASS_UNIFORM:       return 19;
            TOP_INPUT_CLASS_MIXED_SIGN:    return 20;
            TOP_INPUT_CLASS_DOMINANT_PEAK: return 21;
            TOP_INPUT_CLASS_NEAR_EQUAL:    return 22;
            TOP_INPUT_CLASS_SPECIAL_EXP:   return 23;
            default:                       return -1;
        endcase
    end
    endfunction

    function automatic int fnMaxPosPointId();
    begin
        if ((m_max_pos_kind >= 0) && (m_max_pos_kind <= 3))
            return 24 + m_max_pos_kind;
        return -1;
    end
    endfunction

    function automatic int fnInStallPointId();
    begin
        if ((m_in_stall >= TOP_STALL_NONE) && (m_in_stall <= TOP_STALL_SCRIPTED))
            return 28 + m_in_stall;
        return -1;
    end
    endfunction

    function automatic int fnOutStallPointId();
    begin
        if ((m_out_stall >= TOP_STALL_NONE) && (m_out_stall <= TOP_STALL_SCRIPTED))
            return 35 + m_out_stall;
        return -1;
    end
    endfunction

    function automatic int fnKeepKindPointId();
    begin
        if ((m_keep_kind >= TOP_KEEP_ALL_F) && (m_keep_kind <= TOP_KEEP_RANDOM))
            return 42 + m_keep_kind;
        return -1;
    end
    endfunction

    function automatic int fnSpecialPointId();
    begin
        if ((m_special_kind >= TOP_SPECIAL_NONE) && (m_special_kind <= TOP_SPECIAL_SNAN))
            return 46 + m_special_kind;
        return -1;
    end
    endfunction

    function automatic int fnResultPointId();
    begin
        if ((m_result_kind >= TOP_RESULT_NORMAL) && (m_result_kind <= TOP_RESULT_RANDOM_COV))
            return 53 + m_result_kind;
        return -1;
    end
    endfunction

    function automatic int fnOutputLastPointId();
    begin
        if ((m_output_last_kind == 0) || (m_output_last_kind == 1))
            return 59 + m_output_last_kind;
        return -1;
    end
    endfunction

    function automatic int fnResetResultComboPointId();
    begin
        if (m_reset_result_combo >= 0)
            return 61 + m_reset_result_combo;
        return -1;
    end
    endfunction

    function automatic int fnLenTermComboPointId();
    begin
        if (m_len_term_combo >= 0)
            return 65 + m_len_term_combo;
        return -1;
    end
    endfunction

    function automatic int fnTermRearmComboPointId();
    begin
        if (m_term_rearm_combo >= 0)
            return 76 + m_term_rearm_combo;
        return -1;
    end
    endfunction

    function automatic int fnClassMaxPosComboPointId();
    begin
        if (m_class_maxpos_combo >= 0)
            return 82 + m_class_maxpos_combo;
        return -1;
    end
    endfunction

    function automatic int fnStallPairComboPointId();
    begin
        if (m_stall_pair_combo >= 0)
            return 95 + m_stall_pair_combo;
        return -1;
    end
    endfunction

    function automatic int fnLenResultComboPointId();
    begin
        if (m_len_result_combo >= 0)
            return 144 + m_len_result_combo;
        return -1;
    end
    endfunction

    function automatic void note_cov_point(input string iPointKey, input int iPointId = -1);
    begin
        if (!m_cov_point_hit.exists(iPointKey)) begin
            m_cov_point_hit[iPointKey] = 1'b1;
            m_cov_hit_count++;
            if (iPointId >= 0) begin
                m_union_point_hit[iPointId] = 1'b1;
                m_union_point_id = iPointId;
                cg_union_goal_inst.sample(iPointId);
                cg_union_goal_merged.sample(iPointId);
            end
        end
    end
    endfunction

    function automatic void note_sample_points();
        string resetPhaseName;
        string frameLenName;
        string termName;
        string postTermRearmName;
        string inputClassName;
        string maxPosName;
        string inStallName;
        string outStallName;
        string keepKindName;
        string specialKindName;
        string resultKindName;
        string outputLastName;
        bit    resetPhaseValid;
        bit    inputClassValid;
    begin
        resetPhaseValid = (m_reset_phase >= 0);
        inputClassValid = (m_input_class != TOP_INPUT_CLASS_UNKNOWN);
        resetPhaseName = fnTopResetPhaseName(TopResetPhaseE'(m_reset_phase));
        frameLenName = fnFrameLenBinName(m_frame_len);
        termName = fnTopTermKindName(TopTermKindE'(m_term_kind));
        postTermRearmName = fnTopPostTermRearmName(TopPostTermRearmE'(m_post_term_rearm));
        inputClassName = fnTopInputClassName(TopInputClassE'(m_input_class));
        maxPosName = fnMaxPosBinName(m_max_pos_kind);
        inStallName = fnTopStallModeName(TopStallModeE'(m_in_stall));
        outStallName = fnTopStallModeName(TopStallModeE'(m_out_stall));
        keepKindName = fnTopKeepKindName(TopKeepKindE'(m_keep_kind));
        specialKindName = fnTopSpecialKindName(TopSpecialFp32E'(m_special_kind));
        resultKindName = fnTopResultKindName(TopResultKindE'(m_result_kind));
        outputLastName = fnOutputLastBinName(m_output_last_kind);
        m_frame_len_idx = fnFrameLenIndex();
        m_reset_result_combo = fnResetResultCombo();
        m_len_term_combo = fnLenTermCombo();
        m_term_rearm_combo = fnTermRearmCombo();
        m_class_maxpos_combo = fnClassMaxPosCombo();
        m_stall_pair_combo = fnStallPairCombo();
        m_len_result_combo = fnLenResultCombo();

        if (resetPhaseValid)
            note_cov_point({"cp_reset_phase:", resetPhaseName}, fnResetPhasePointId());
        note_cov_point({"cp_frame_len:", frameLenName}, fnFrameLenPointId());
        note_cov_point({"cp_term_kind:", termName}, fnTermKindPointId());
        note_cov_point({"cp_post_term_rearm:", postTermRearmName}, fnPostTermRearmPointId());
        if (inputClassValid)
            note_cov_point({"cp_input_class:", inputClassName}, fnInputClassPointId());
        note_cov_point({"cp_max_pos:", maxPosName}, fnMaxPosPointId());
        note_cov_point({"cp_in_stall:", inStallName}, fnInStallPointId());
        note_cov_point({"cp_out_stall:", outStallName}, fnOutStallPointId());
        note_cov_point({"cp_keep_kind:", keepKindName}, fnKeepKindPointId());
        note_cov_point({"cp_special_fp32:", specialKindName}, fnSpecialPointId());
        note_cov_point({"cp_result_kind:", resultKindName}, fnResultPointId());
        note_cov_point({"cp_output_last:", outputLastName}, fnOutputLastPointId());

        if (m_reset_result_combo >= 0)
            note_cov_point({"cp_reset_phase_result_combo:", $sformatf("%0d", m_reset_result_combo)}, fnResetResultComboPointId());
        if (m_len_term_combo >= 0)
            note_cov_point({"cp_len_term_combo:", $sformatf("%0d", m_len_term_combo)}, fnLenTermComboPointId());
        if (m_term_rearm_combo >= 0)
            note_cov_point({"cp_term_rearm_combo:", $sformatf("%0d", m_term_rearm_combo)}, fnTermRearmComboPointId());
        if (m_class_maxpos_combo >= 0)
            note_cov_point({"cp_class_maxpos_combo:", $sformatf("%0d", m_class_maxpos_combo)}, fnClassMaxPosComboPointId());
        if (m_stall_pair_combo >= 0)
            note_cov_point({"cp_stall_pair_combo:", $sformatf("%0d", m_stall_pair_combo)}, fnStallPairComboPointId());
        if (m_len_result_combo >= 0)
            note_cov_point({"cp_len_result_combo:", $sformatf("%0d", m_len_result_combo)}, fnLenResultComboPointId());
    end
    endfunction

    function void note_checked_beats(input int unsigned iCheckedCount);
    begin
        m_checked_count += iCheckedCount;
    end
    endfunction

    function void sample_frame(input TopExpectedFrame expFrame, input TopObservedFrame obsFrame);
    begin
        m_frame_sample_count++;
        m_reset_phase = expFrame.m_reset_phase;
        m_frame_len = expFrame.m_input_samples.size();
        m_term_kind = expFrame.m_term_kind;
        m_post_term_rearm = expFrame.m_post_term_rearm;
        m_input_class = expFrame.m_input_class;
        m_max_pos_kind = fnMaxPosKind(expFrame);
        m_in_stall = expFrame.m_in_stall_mode;
        m_out_stall = expFrame.m_out_stall_mode;
        m_keep_kind = expFrame.m_keep_kind;
        m_special_kind = expFrame.m_special_kind;
        m_result_kind = expFrame.m_result_kind;
        if (obsFrame == null)
            m_output_last_kind = 0;
        else if (obsFrame.m_last_count == 1)
            m_output_last_kind = 1;
        else if (obsFrame.m_last_count == 0)
            m_output_last_kind = 0;
        else
            m_output_last_kind = 2;
        note_sample_points();
        cg_top_frame.sample();
    end
    endfunction

    function void sample_reset_event(
        input TopResetPhaseE iPhase,
        input TopStallModeE iInStall,
        input TopStallModeE iOutStall
    );
    begin
        m_reset_sample_count++;
        m_reset_phase = iPhase;
        m_frame_len = 1;
        m_term_kind = TOP_TERM_ILAST_ONLY;
        m_post_term_rearm = TOP_POST_TERM_DELAYED;
        m_input_class = TOP_INPUT_CLASS_UNKNOWN;
        m_max_pos_kind = 4;
        m_in_stall = iInStall;
        m_out_stall = iOutStall;
        m_keep_kind = TOP_KEEP_ALL_F;
        m_special_kind = TOP_SPECIAL_NONE;
        m_result_kind = TOP_RESULT_RESET_ABORTED;
        m_output_last_kind = 0;
        note_sample_points();
        cg_top_frame.sample();
    end
    endfunction

    function automatic real fnGetChunkedUnionCoverage();
        real covA;
        real covB;
        real covC;
        real covD;
    begin
        covA = cg_union_goal_a.get_inst_coverage();
        covB = cg_union_goal_b.get_inst_coverage();
        covC = cg_union_goal_c.get_inst_coverage();
        covD = cg_union_goal_d.get_inst_coverage();
        return ((covA * 42.0) + (covB * 42.0) + (covC * 41.0) + (covD * 41.0)) / 166.0;
    end
    endfunction

    function automatic int unsigned fnGetUnionGoalHitCount();
        int key;
        int unsigned hitCount;
    begin
        hitCount = 0;
        key = 0;
        if (m_union_point_hit.first(key)) begin
            do begin
                hitCount++;
            end while (m_union_point_hit.next(key));
        end
        return hitCount;
    end
    endfunction

    function automatic real fnGetUnionGoalClosure();
    begin
        return (fnGetUnionGoalHitCount() * 100.0) / fnTotalUnionGoalCount();
    end
    endfunction

    function automatic int unsigned get_union_goal_closure_tenths();
    begin
        return fnCoverageTenthsFromReal(fnGetUnionGoalClosure());
    end
    endfunction

    function automatic int unsigned get_builtin_raw_coverage_tenths();
    begin
        return get_merged_coverage_tenths();
    end
    endfunction

    function real get_merged_coverage();
    begin
        return cg_union_goal_merged.get_coverage();
    end
    endfunction

    function int unsigned get_merged_coverage_tenths();
    begin
        return fnCoverageTenthsFromReal(get_merged_coverage());
    end
    endfunction

    function real get_inst_coverage();
    begin
        return fnGetUnionGoalClosure();
    end
    endfunction

    function int unsigned get_inst_coverage_tenths();
    begin
        return get_union_goal_closure_tenths();
    end
    endfunction

    function automatic string fnJoinedCovPointKeys();
        string key;
        string joinedKeys;
        bit    isFirst;
    begin
        joinedKeys = "";
        isFirst = 1'b1;
        key = "";
        if (m_cov_point_hit.first(key)) begin
            do begin
                if (!isFirst)
                    joinedKeys = {joinedKeys, "|"};
                joinedKeys = {joinedKeys, key};
                isFirst = 1'b0;
            end while (m_cov_point_hit.next(key));
        end
        return joinedKeys;
    end
    endfunction

    task automatic write_hit_keys(input string iPath);
        integer fd;
        string key;
    begin
        fd = $fopen(iPath, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create coverage hit dump: %s", iPath);

        key = "";
        if (m_cov_point_hit.first(key)) begin
            do begin
                $fdisplay(fd, "%s", key);
            end while (m_cov_point_hit.next(key));
        end
        $fclose(fd);
    end
    endtask

    task automatic write_union_ids(input string iPath);
        integer fd;
        int key;
    begin
        fd = $fopen(iPath, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create union id dump: %s", iPath);

        key = 0;
        if (m_union_point_hit.first(key)) begin
            do begin
                $fdisplay(fd, "%0d", key);
            end while (m_union_point_hit.next(key));
        end
        $fclose(fd);
    end
    endtask

    task automatic write_builtin_breakdown(input string iPath);
        integer fd;
        int unsigned coverageTenths;
    begin
        fd = $fopen(iPath, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create coverage breakdown dump: %s", iPath);

        coverageTenths = get_union_goal_closure_tenths();
        $fdisplay(fd, "union_goal_closure=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        $fdisplay(fd, "union_goal_hits=%0d/%0d", fnGetUnionGoalHitCount(), fnTotalUnionGoalCount());
        coverageTenths = get_merged_coverage_tenths();
        $fdisplay(fd, "cg_union_goal_merged=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = get_inst_coverage_tenths();
        $fdisplay(fd, "cg_union_goal_inst=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.get_inst_coverage());
        $fdisplay(fd, "cg_top_frame=%0d.%0d", coverageTenths / 10, coverageTenths % 10);

        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_reset_phase.get_coverage());
        $fdisplay(fd, "cp_reset_phase=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_frame_len.get_coverage());
        $fdisplay(fd, "cp_frame_len=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_term_kind.get_coverage());
        $fdisplay(fd, "cp_term_kind=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_post_term_rearm.get_coverage());
        $fdisplay(fd, "cp_post_term_rearm=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_input_class.get_coverage());
        $fdisplay(fd, "cp_input_class=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_max_pos.get_coverage());
        $fdisplay(fd, "cp_max_pos=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_in_stall.get_coverage());
        $fdisplay(fd, "cp_in_stall=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_out_stall.get_coverage());
        $fdisplay(fd, "cp_out_stall=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_keep_kind.get_coverage());
        $fdisplay(fd, "cp_keep_kind=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_special_fp32.get_coverage());
        $fdisplay(fd, "cp_special_fp32=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_result_kind.get_coverage());
        $fdisplay(fd, "cp_result_kind=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_output_last.get_coverage());
        $fdisplay(fd, "cp_output_last=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_reset_phase_result_combo.get_coverage());
        $fdisplay(fd, "cp_reset_phase_result_combo=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_len_term_combo.get_coverage());
        $fdisplay(fd, "cp_len_term_combo=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_term_rearm_combo.get_coverage());
        $fdisplay(fd, "cp_term_rearm_combo=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_class_maxpos_combo.get_coverage());
        $fdisplay(fd, "cp_class_maxpos_combo=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_stall_pair_combo.get_coverage());
        $fdisplay(fd, "cp_stall_pair_combo=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        coverageTenths = fnCoverageTenthsFromReal(cg_top_frame.cp_len_result_combo.get_coverage());
        $fdisplay(fd, "cp_len_result_combo=%0d.%0d", coverageTenths / 10, coverageTenths % 10);
        $fclose(fd);
    end
    endtask
endclass

class TopCoverage;
    static TopCoverage          sg_global_coverage;
    TopCoverageEntry        m_total_entry;
    TopCoverageEntry        m_scenario_entries[string];
    string                  m_scenario_order[$];

    function new();
        m_total_entry = new("__total__");
    endfunction

    static function void set_global_coverage(input TopCoverage iCoverageObj);
    begin
        sg_global_coverage = iCoverageObj;
    end
    endfunction

    function automatic string fnScenarioKey(input string iScenarioTag);
    begin
        if (iScenarioTag.len() == 0)
            return "unnamed";
        return iScenarioTag;
    end
    endfunction

    function automatic TopCoverageEntry fnGetScenarioEntry(input string iScenarioTag);
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

    function void sample_frame(input TopExpectedFrame expFrame, input TopObservedFrame obsFrame);
        TopCoverageEntry scenarioEntry;
    begin
        if ((sg_global_coverage != null) && (sg_global_coverage != this))
            sg_global_coverage.sample_frame(expFrame, obsFrame);
        m_total_entry.sample_frame(expFrame, obsFrame);
        scenarioEntry = fnGetScenarioEntry(expFrame.m_scenario_tag);
        scenarioEntry.sample_frame(expFrame, obsFrame);
    end
    endfunction

    function void sample_reset_event(
        input TopResetPhaseE iPhase,
        input TopStallModeE iInStall,
        input TopStallModeE iOutStall,
        input string iScenarioTag = ""
    );
        string scenarioTag;
        TopCoverageEntry scenarioEntry;
    begin
        if ((sg_global_coverage != null) && (sg_global_coverage != this))
            sg_global_coverage.sample_reset_event(iPhase, iInStall, iOutStall, iScenarioTag);
        m_total_entry.sample_reset_event(iPhase, iInStall, iOutStall);
        if (iScenarioTag.len() == 0)
            scenarioTag = $sformatf("reset_%s", fnTopResetPhaseName(iPhase));
        else
            scenarioTag = iScenarioTag;
        scenarioEntry = fnGetScenarioEntry(scenarioTag);
        scenarioEntry.sample_reset_event(iPhase, iInStall, iOutStall);
    end
    endfunction

    function void note_checked_beats(input string iScenarioTag, input int unsigned iCheckedCount);
        TopCoverageEntry scenarioEntry;
    begin
        if ((sg_global_coverage != null) && (sg_global_coverage != this))
            sg_global_coverage.note_checked_beats(iScenarioTag, iCheckedCount);
        m_total_entry.note_checked_beats(iCheckedCount);
        scenarioEntry = fnGetScenarioEntry(iScenarioTag);
        scenarioEntry.note_checked_beats(iCheckedCount);
    end
    endfunction

    task automatic report_scenario_breakdown();
        int idx;
        string key;
        TopCoverageEntry scenarioEntry;
        int unsigned coverageTenths;
    begin
        if (m_scenario_order.size() == 0)
            return;

        `TB_INFO("Scenario breakdown start");
        for (idx = 0; idx < m_scenario_order.size(); idx++) begin
            key = m_scenario_order[idx];
            scenarioEntry = m_scenario_entries[key];
            coverageTenths = scenarioEntry.get_inst_coverage_tenths();
            $display(
                "[TB][INFO] Scenario report: name=%s checked_beats=%0d frame_samples=%0d reset_samples=%0d coverage=%0d.%0d%%",
                key,
                scenarioEntry.m_checked_count,
                scenarioEntry.m_frame_sample_count,
                scenarioEntry.m_reset_sample_count,
                coverageTenths / 10,
                coverageTenths % 10
            );
        end
        `TB_INFO("Scenario breakdown end");
    end
    endtask

    task automatic write_scenario_jsonl(input string iPath);
        integer fd;
        int idx;
        string key;
        TopCoverageEntry scenarioEntry;
        int unsigned coverageTenths;
    begin
        fd = $fopen(iPath, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", iPath);

        for (idx = 0; idx < m_scenario_order.size(); idx++) begin
            key = m_scenario_order[idx];
            scenarioEntry = m_scenario_entries[key];
            coverageTenths = scenarioEntry.get_inst_coverage_tenths();
            $fdisplay(
                fd,
                "{\"name\":\"%s\",\"checked_beats\":%0d,\"frame_samples\":%0d,\"reset_samples\":%0d,\"coverage_pct\":%0d.%0d}",
                key,
                scenarioEntry.m_checked_count,
                scenarioEntry.m_frame_sample_count,
                scenarioEntry.m_reset_sample_count,
                coverageTenths / 10,
                coverageTenths % 10
            );
        end
        $fclose(fd);
    end
    endtask

    task automatic write_scenario_cov_points_jsonl(input string iPath);
        integer fd;
        int idx;
        string key;
        string pointKeys;
        TopCoverageEntry scenarioEntry;
        int unsigned coverageTenths;
    begin
        fd = $fopen(iPath, "w");
        if (fd == 0)
            $fatal(1, "[TB] Failed to create %s", iPath);

        for (idx = 0; idx < m_scenario_order.size(); idx++) begin
            key = m_scenario_order[idx];
            scenarioEntry = m_scenario_entries[key];
            coverageTenths = scenarioEntry.get_inst_coverage_tenths();
            pointKeys = scenarioEntry.fnJoinedCovPointKeys();
            $fdisplay(
                fd,
                "{\"name\":\"%s\",\"point_count\":%0d,\"union_count\":%0d,\"coverage_pct\":%0d.%0d,\"point_keys_pipe\":\"%s\"}",
                key,
                scenarioEntry.m_cov_hit_count,
                scenarioEntry.fnGetUnionGoalHitCount(),
                coverageTenths / 10,
                coverageTenths % 10,
                pointKeys
            );
        end
        $fclose(fd);
    end
    endtask

    function real get_inst_coverage();
        return m_total_entry.get_inst_coverage();
    endfunction

    function int unsigned get_inst_coverage_tenths();
        return m_total_entry.get_inst_coverage_tenths();
    endfunction

    function int unsigned get_builtin_raw_coverage_tenths();
        return m_total_entry.get_builtin_raw_coverage_tenths();
    endfunction

    function real get_merged_coverage();
        return m_total_entry.get_merged_coverage();
    endfunction

    function int unsigned get_merged_coverage_tenths();
        return m_total_entry.get_merged_coverage_tenths();
    endfunction

    task automatic write_total_hit_keys(input string iPath);
    begin
        m_total_entry.write_hit_keys(iPath);
    end
    endtask

    task automatic write_total_union_ids(input string iPath);
    begin
        m_total_entry.write_union_ids(iPath);
    end
    endtask

    task automatic write_total_builtin_breakdown(input string iPath);
    begin
        m_total_entry.write_builtin_breakdown(iPath);
    end
    endtask
endclass

`endif
