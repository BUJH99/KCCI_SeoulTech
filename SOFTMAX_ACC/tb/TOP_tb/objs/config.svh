`ifndef TOP_CONFIG_SVH
`define TOP_CONFIG_SVH

class TopConfig;
    string        m_testname;
    int unsigned  m_seed;
    int unsigned  m_timeout_cycles;
    int unsigned  m_max_frame_len;
    bit           m_enable_coverage;
    bit           m_fail_on_coverage_gap;
    int unsigned  m_random_frame_count;
    int unsigned  m_case_index;
    int unsigned  m_case_count;
    string        m_project_root;
    string        m_tb_dir;
    string        m_python_tool_path;
    string        m_report_tool_path;
    string        m_python_launcher_path;
    string        m_runtime_root;
    string        m_case_runtime_dir;
    string        m_input_jsonl_path;
    string        m_expected_jsonl_path;
    string        m_actual_jsonl_path;
    string        m_mismatch_jsonl_path;
    string        m_summary_json_path;
    string        m_scenario_coverage_jsonl_path;
    string        m_scenario_cov_points_jsonl_path;
    string        m_scenario_quality_jsonl_path;
    string        m_report_html_path;
    TopStallModeE m_default_in_stall_mode;
    TopStallModeE m_default_out_stall_mode;

    function new(string iTestname = "");
        m_testname = iTestname;
        m_seed = LP_TOP_DEFAULT_SEED;
        m_timeout_cycles = LP_TOP_DEFAULT_TIMEOUT_CYCLES;
        m_max_frame_len = 1024;
        m_enable_coverage = 1'b1;
        m_fail_on_coverage_gap = 1'b0;
        m_random_frame_count = 24;
        m_case_index = 1;
        m_case_count = 1;
        m_project_root = fnTopProjectRoot();
        m_tb_dir = fnTopTbDir();
        m_python_tool_path = fnTopPythonToolPath();
        m_report_tool_path = fnTopReportToolPath();
        m_python_launcher_path = fnTopPythonLauncherPath();
        m_runtime_root = fnTopRuntimeRoot();
        m_default_in_stall_mode = TOP_STALL_NONE;
        m_default_out_stall_mode = TOP_STALL_NONE;
        build_runtime_paths();
    endfunction

    function void build_runtime_paths();
        string caseLeaf;
    begin
        caseLeaf = fnTopSanitizeName(m_testname);
        m_case_runtime_dir = fnTopRuntimeCaseDir(caseLeaf);
        m_input_jsonl_path = fnTopJoinPath(m_case_runtime_dir, "input_frames.jsonl");
        m_expected_jsonl_path = fnTopJoinPath(m_case_runtime_dir, "expected_frames.jsonl");
        m_actual_jsonl_path = fnTopJoinPath(m_case_runtime_dir, "actual_frames.jsonl");
        m_mismatch_jsonl_path = fnTopJoinPath(m_case_runtime_dir, "mismatch_events.jsonl");
        m_summary_json_path = fnTopJoinPath(m_case_runtime_dir, "report_summary.json");
        m_scenario_coverage_jsonl_path = fnTopJoinPath(m_case_runtime_dir, "scenario_coverage.jsonl");
        m_scenario_cov_points_jsonl_path = fnTopJoinPath(m_case_runtime_dir, "scenario_cov_points.jsonl");
        m_scenario_quality_jsonl_path = fnTopJoinPath(m_case_runtime_dir, "scenario_quality.jsonl");
        m_report_html_path = fnTopJoinPath(m_case_runtime_dir, "report.html");
    end
    endfunction

    function void set_case_info(input string iTestname, input int unsigned iCaseIndex, input int unsigned iCaseCount);
    begin
        m_testname = iTestname;
        m_case_index = iCaseIndex;
        m_case_count = iCaseCount;
        build_runtime_paths();
    end
    endfunction
endclass

`endif
