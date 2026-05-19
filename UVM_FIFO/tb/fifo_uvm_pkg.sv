`timescale 1ns / 1ps

package fifo_uvm_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam int FIFO_DATA_WIDTH = 4;
    localparam int FIFO_DEPTH      = 8;

    `include "FifoItem.svh"
    `include "FifoSequence.svh"
    `include "FifoSequencer.svh"
    `include "FifoDriver.svh"
    `include "FifoMonitor.svh"
    `include "FifoScoreboard.svh"
    `include "FifoCoverage.svh"
    `include "FifoAgent.svh"
    `include "FifoEnv.svh"
    `include "FifoTest.svh"

endpackage
