package TOP_tb_pkg;
    string GP_TB_PKG_FILE = `__FILE__;

    `include "include/tb_defs.svh"

    `include "objs/config.svh"
    `include "objs/transaction.svh"

    `include "components/generator.svh"
    `include "components/driver.svh"
    `include "components/monitor.svh"

    `include "env/coverage.svh"
    `include "env/scoreboard.svh"
    `include "env/shadow_checker.svh"
    `include "env/environment.svh"

    `include "tests/base_test.svh"
    `include "tests/test_01_reset_matrix.svh"
    `include "tests/test_02_singleton_frame.svh"
    `include "tests/test_03_uniform_frame.svh"
    `include "tests/test_04_mixed_vector_directed.svh"
    `include "tests/test_05_backpressure_protocol.svh"
    `include "tests/test_06_frame_boundary_cmax.svh"
    `include "tests/test_07_boundary_collision_rearm.svh"
    `include "tests/test_08_keep_ignore.svh"
    `include "tests/test_09_special_fp32_policy.svh"
    `include "tests/test_10_random_cov.svh"

    function automatic TopBaseTest fnCreateTest(input string iTestname, virtual TOP_if vif_TOP);
        TopBaseTest testHandle;
        TopTest01ResetMatrix test01;
        TopTest02SingletonFrame test02;
        TopTest03UniformFrame test03;
        TopTest04MixedVectorDirected test04;
        TopTest05BackpressureProtocol test05;
        TopTest06FrameBoundaryCmax test06;
        TopTest07BoundaryCollisionRearm test07;
        TopTest08KeepIgnore test08;
        TopTest09SpecialFp32Policy test09;
        TopTest10RandomCov test10;
    begin
        testHandle = null;
        if (iTestname == "test_01_reset_matrix") begin
            test01 = new(vif_TOP);
            testHandle = test01;
        end else if (iTestname == "test_02_singleton_frame") begin
            test02 = new(vif_TOP);
            testHandle = test02;
        end else if (iTestname == "test_03_uniform_frame") begin
            test03 = new(vif_TOP);
            testHandle = test03;
        end else if (iTestname == "test_04_mixed_vector_directed") begin
            test04 = new(vif_TOP);
            testHandle = test04;
        end else if (iTestname == "test_05_backpressure_protocol") begin
            test05 = new(vif_TOP);
            testHandle = test05;
        end else if (iTestname == "test_06_frame_boundary_cmax") begin
            test06 = new(vif_TOP);
            testHandle = test06;
        end else if (iTestname == "test_07_boundary_collision_rearm") begin
            test07 = new(vif_TOP);
            testHandle = test07;
        end else if (iTestname == "test_08_keep_ignore") begin
            test08 = new(vif_TOP);
            testHandle = test08;
        end else if (iTestname == "test_09_special_fp32_policy") begin
            test09 = new(vif_TOP);
            testHandle = test09;
        end else if (iTestname == "test_10_random_cov") begin
            test10 = new(vif_TOP);
            testHandle = test10;
        end
        return testHandle;
    end
    endfunction
endpackage
