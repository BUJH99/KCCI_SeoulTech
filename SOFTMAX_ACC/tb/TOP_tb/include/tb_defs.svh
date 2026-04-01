`ifndef TOP_TB_DEFS_SVH
`define TOP_TB_DEFS_SVH

`define TB_INFO(MSG) $display("[TB][INFO] %s", MSG)
`define TB_WARN(MSG) $display("[TB][WARN] %s", MSG)
`define TB_ERR(MSG)  $display("[TB][ERROR] %s", MSG)

typedef enum int {
    TOP_RESET_PHASE_NONE         = -1,
    TOP_RESET_PHASE_IDLE         = 0,
    TOP_RESET_PHASE_CAPTURE      = 1,
    TOP_RESET_PHASE_REPLAY       = 2,
    TOP_RESET_PHASE_OUTPUT_VALID = 3
} TopResetPhaseE;

typedef enum int {
    TOP_INPUT_CLASS_UNKNOWN       = 0,
    TOP_INPUT_CLASS_UNIFORM       = 1,
    TOP_INPUT_CLASS_MIXED_SIGN    = 2,
    TOP_INPUT_CLASS_DOMINANT_PEAK = 3,
    TOP_INPUT_CLASS_NEAR_EQUAL    = 4,
    TOP_INPUT_CLASS_SPECIAL_EXP   = 5
} TopInputClassE;

typedef enum int {
    TOP_STALL_NONE      = 0,
    TOP_STALL_LIGHT     = 1,
    TOP_STALL_HEAVY     = 2,
    TOP_STALL_ALTERNATE = 3,
    TOP_STALL_BURST     = 4,
    TOP_STALL_RANDOM    = 5,
    TOP_STALL_SCRIPTED  = 6
} TopStallModeE;

typedef enum int {
    TOP_KEEP_ALL_F = 0,
    TOP_KEEP_ALT   = 1,
    TOP_KEEP_ZERO  = 2,
    TOP_KEEP_RANDOM = 3
} TopKeepKindE;

typedef enum int {
    TOP_TERM_ILAST_ONLY    = 0,
    TOP_TERM_CMAX_ONLY     = 1,
    TOP_TERM_ILAST_AND_CMAX = 2
} TopTermKindE;

typedef enum int {
    TOP_POST_TERM_DELAYED      = 0,
    TOP_POST_TERM_BACK_TO_BACK = 1
} TopPostTermRearmE;

typedef enum int {
    TOP_RESULT_NORMAL        = 0,
    TOP_RESULT_RESET_ABORTED = 1,
    TOP_RESULT_KEEP_IGNORE   = 2,
    TOP_RESULT_SPECIAL       = 3,
    TOP_RESULT_PROTOCOL      = 4,
    TOP_RESULT_RANDOM_COV    = 5
} TopResultKindE;

typedef enum int {
    TOP_SPECIAL_NONE         = 0,
    TOP_SPECIAL_ZERO         = 1,
    TOP_SPECIAL_LARGE_FINITE = 2,
    TOP_SPECIAL_POS_INF      = 3,
    TOP_SPECIAL_NEG_INF      = 4,
    TOP_SPECIAL_QNAN         = 5,
    TOP_SPECIAL_SNAN         = 6
} TopSpecialFp32E;

localparam int unsigned LP_TOP_DEFAULT_SEED           = 32'h2026_0320;
localparam int unsigned LP_TOP_DEFAULT_TIMEOUT_CYCLES = 5_000_000;
localparam int unsigned LP_TOP_DRAIN_STABLE_CYCLES    = 32;
localparam int unsigned LP_TOP_RESET_CYCLES           = 4;
localparam real         LP_TOP_SUM_TOLERANCE          = 0.03;

function automatic string fnTopNormalizePath(input string iPath);
    string pathValue;
    int idx;
begin
    pathValue = iPath;
    for (idx = 0; idx < pathValue.len(); idx++) begin
        if (pathValue.getc(idx) == 92)
            pathValue.putc(idx, 47);
    end
    return pathValue;
end
endfunction

function automatic string fnTopDirname(input string iPath);
    string pathValue;
    int idx;
begin
    pathValue = fnTopNormalizePath(iPath);
    for (idx = pathValue.len() - 1; idx >= 0; idx--) begin
        if (pathValue.getc(idx) == 47) begin
            if (idx == 0)
                return "/";
            return pathValue.substr(0, idx - 1);
        end
    end
    return ".";
end
endfunction

function automatic string fnTopJoinPath(input string iBase, input string iLeaf);
begin
    if (iBase.len() == 0)
        return iLeaf;
    if (iBase.getc(iBase.len() - 1) == 47)
        return {iBase, iLeaf};
    return {iBase, "/", iLeaf};
end
endfunction

function automatic string fnTopSanitizeName(input string iName);
    string safeName;
    int idx;
    int c;
begin
    safeName = iName;
    if (safeName.len() == 0)
        return "unnamed";
    for (idx = 0; idx < safeName.len(); idx++) begin
        c = safeName.getc(idx);
        if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 45))
            safeName.putc(idx, 95);
    end
    return safeName;
end
endfunction

function automatic string fnTopTbDir();
begin
    return fnTopDirname(fnTopNormalizePath(GP_TB_PKG_FILE));
end
endfunction

function automatic string fnTopProjectRoot();
begin
    return fnTopDirname(fnTopDirname(fnTopTbDir()));
end
endfunction

function automatic string fnTopRuntimeRoot();
begin
    return fnTopJoinPath(fnTopProjectRoot(), "tb_runtime");
end
endfunction

function automatic string fnTopUserHome();
    string projectRoot;
    int idx;
    int slashCount;
begin
    projectRoot = fnTopProjectRoot();
    slashCount = 0;
    for (idx = 0; idx < projectRoot.len(); idx++) begin
        if (projectRoot.getc(idx) == 47) begin
            slashCount++;
            if (slashCount == 3)
                return projectRoot.substr(0, idx - 1);
        end
    end
    return projectRoot;
end
endfunction

function automatic string fnTopPythonToolPath();
begin
    return fnTopJoinPath(fnTopJoinPath(fnTopTbDir(), "tools"), "top_golden_model.py");
end
endfunction

function automatic string fnTopPythonLauncherPath();
begin
    return fnTopJoinPath(fnTopJoinPath(fnTopTbDir(), "tools"), "run_python.bat");
end
endfunction

function automatic string fnTopReportToolPath();
begin
    return fnTopJoinPath(fnTopJoinPath(fnTopTbDir(), "tools"), "top_tb_report.py");
end
endfunction

function automatic string fnTopRuntimeCaseDir(input string iTestName);
begin
    return fnTopJoinPath(fnTopRuntimeRoot(), fnTopSanitizeName(iTestName));
end
endfunction

function automatic string fnTopRuntimeSuiteSummaryPath(input string iTestName);
begin
    return fnTopJoinPath(fnTopRuntimeRoot(), {"suite_summary_", fnTopSanitizeName(iTestName), ".json"});
end
endfunction

function automatic string fnTopRuntimeMasterReportPath(input string iTestName);
begin
    return fnTopJoinPath(fnTopRuntimeRoot(), {"report_", fnTopSanitizeName(iTestName), ".html"});
end
endfunction

function automatic string fnTopResetPhaseName(input TopResetPhaseE iPhase);
begin
    case (iPhase)
        TOP_RESET_PHASE_IDLE:         return "idle";
        TOP_RESET_PHASE_CAPTURE:      return "capture";
        TOP_RESET_PHASE_REPLAY:       return "replay";
        TOP_RESET_PHASE_OUTPUT_VALID: return "output_valid";
        default:                      return "none";
    endcase
end
endfunction

function automatic TopResetPhaseE fnTopParseResetPhase(input string iValue);
begin
    if (iValue == "idle")
        return TOP_RESET_PHASE_IDLE;
    if (iValue == "capture")
        return TOP_RESET_PHASE_CAPTURE;
    if (iValue == "replay")
        return TOP_RESET_PHASE_REPLAY;
    if (iValue == "output_valid")
        return TOP_RESET_PHASE_OUTPUT_VALID;
    return TOP_RESET_PHASE_NONE;
end
endfunction

function automatic string fnTopInputClassName(input TopInputClassE iClassKind);
begin
    case (iClassKind)
        TOP_INPUT_CLASS_UNIFORM:       return "uniform";
        TOP_INPUT_CLASS_MIXED_SIGN:    return "mixed_sign";
        TOP_INPUT_CLASS_DOMINANT_PEAK: return "dominant_peak";
        TOP_INPUT_CLASS_NEAR_EQUAL:    return "near_equal";
        TOP_INPUT_CLASS_SPECIAL_EXP:   return "special_exp";
        default:                       return "unknown";
    endcase
end
endfunction

function automatic TopInputClassE fnTopParseInputClass(input string iValue);
begin
    if (iValue == "uniform")
        return TOP_INPUT_CLASS_UNIFORM;
    if (iValue == "mixed_sign")
        return TOP_INPUT_CLASS_MIXED_SIGN;
    if (iValue == "dominant_peak")
        return TOP_INPUT_CLASS_DOMINANT_PEAK;
    if (iValue == "near_equal")
        return TOP_INPUT_CLASS_NEAR_EQUAL;
    if (iValue == "special_exp")
        return TOP_INPUT_CLASS_SPECIAL_EXP;
    return TOP_INPUT_CLASS_UNKNOWN;
end
endfunction

function automatic string fnTopStallModeName(input TopStallModeE iMode);
begin
    case (iMode)
        TOP_STALL_LIGHT:     return "light";
        TOP_STALL_HEAVY:     return "heavy";
        TOP_STALL_ALTERNATE: return "alternate";
        TOP_STALL_BURST:     return "burst";
        TOP_STALL_RANDOM:    return "random";
        TOP_STALL_SCRIPTED:  return "scripted";
        default:             return "none";
    endcase
end
endfunction

function automatic TopStallModeE fnTopParseStallMode(input string iValue);
begin
    if (iValue == "light")
        return TOP_STALL_LIGHT;
    if (iValue == "heavy")
        return TOP_STALL_HEAVY;
    if (iValue == "alternate")
        return TOP_STALL_ALTERNATE;
    if (iValue == "burst")
        return TOP_STALL_BURST;
    if (iValue == "random")
        return TOP_STALL_RANDOM;
    if (iValue == "scripted")
        return TOP_STALL_SCRIPTED;
    return TOP_STALL_NONE;
end
endfunction

function automatic string fnTopKeepKindName(input TopKeepKindE iKeepKind);
begin
    case (iKeepKind)
        TOP_KEEP_ALT:    return "alt";
        TOP_KEEP_ZERO:   return "zero";
        TOP_KEEP_RANDOM: return "random";
        default:         return "all_f";
    endcase
end
endfunction

function automatic TopKeepKindE fnTopParseKeepKind(input string iValue);
begin
    if (iValue == "alt")
        return TOP_KEEP_ALT;
    if (iValue == "zero")
        return TOP_KEEP_ZERO;
    if (iValue == "random")
        return TOP_KEEP_RANDOM;
    return TOP_KEEP_ALL_F;
end
endfunction

function automatic string fnTopTermKindName(input TopTermKindE iTermKind);
begin
    case (iTermKind)
        TOP_TERM_CMAX_ONLY:      return "cmax_only";
        TOP_TERM_ILAST_AND_CMAX: return "iLast_and_cmax";
        default:                 return "iLast_only";
    endcase
end
endfunction

function automatic TopTermKindE fnTopParseTermKind(input string iValue);
begin
    if (iValue == "cmax_only")
        return TOP_TERM_CMAX_ONLY;
    if (iValue == "iLast_and_cmax")
        return TOP_TERM_ILAST_AND_CMAX;
    return TOP_TERM_ILAST_ONLY;
end
endfunction

function automatic string fnTopPostTermRearmName(input TopPostTermRearmE iRearm);
begin
    case (iRearm)
        TOP_POST_TERM_BACK_TO_BACK: return "back_to_back";
        default:                    return "delayed";
    endcase
end
endfunction

function automatic TopPostTermRearmE fnTopParsePostTermRearm(input string iValue);
begin
    if (iValue == "back_to_back")
        return TOP_POST_TERM_BACK_TO_BACK;
    return TOP_POST_TERM_DELAYED;
end
endfunction

function automatic string fnTopResultKindName(input TopResultKindE iResultKind);
begin
    case (iResultKind)
        TOP_RESULT_RESET_ABORTED: return "reset_aborted";
        TOP_RESULT_KEEP_IGNORE:   return "keep_ignore";
        TOP_RESULT_SPECIAL:       return "special";
        TOP_RESULT_PROTOCOL:      return "protocol";
        TOP_RESULT_RANDOM_COV:    return "random_cov";
        default:                  return "normal";
    endcase
end
endfunction

function automatic TopResultKindE fnTopParseResultKind(input string iValue);
begin
    if (iValue == "reset_aborted")
        return TOP_RESULT_RESET_ABORTED;
    if (iValue == "keep_ignore")
        return TOP_RESULT_KEEP_IGNORE;
    if (iValue == "special")
        return TOP_RESULT_SPECIAL;
    if (iValue == "protocol")
        return TOP_RESULT_PROTOCOL;
    if (iValue == "random_cov")
        return TOP_RESULT_RANDOM_COV;
    return TOP_RESULT_NORMAL;
end
endfunction

function automatic string fnTopSpecialKindName(input TopSpecialFp32E iKind);
begin
    case (iKind)
        TOP_SPECIAL_ZERO:         return "zero";
        TOP_SPECIAL_LARGE_FINITE: return "large_finite";
        TOP_SPECIAL_POS_INF:      return "pos_inf";
        TOP_SPECIAL_NEG_INF:      return "neg_inf";
        TOP_SPECIAL_QNAN:         return "qnan";
        TOP_SPECIAL_SNAN:         return "snan";
        default:                  return "none";
    endcase
end
endfunction

function automatic TopSpecialFp32E fnTopParseSpecialKind(input string iValue);
begin
    if (iValue == "zero")
        return TOP_SPECIAL_ZERO;
    if (iValue == "large_finite")
        return TOP_SPECIAL_LARGE_FINITE;
    if (iValue == "pos_inf")
        return TOP_SPECIAL_POS_INF;
    if (iValue == "neg_inf")
        return TOP_SPECIAL_NEG_INF;
    if (iValue == "qnan")
        return TOP_SPECIAL_QNAN;
    if (iValue == "snan")
        return TOP_SPECIAL_SNAN;
    return TOP_SPECIAL_NONE;
end
endfunction

function automatic bit [31:0] fnTopShortrealBits(input shortreal iValue);
begin
    return $shortrealtobits(iValue);
end
endfunction

function automatic shortreal fnTopBitsToShortreal(input bit [31:0] iValue);
begin
    return $bitstoshortreal(iValue);
end
endfunction

`endif
