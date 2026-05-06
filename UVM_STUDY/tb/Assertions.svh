`include "uvm_macros.svh"
import uvm_pkg::*;

module Assertions (
    Top_If vif
);

    default clocking cb @(posedge vif.clk);
    endclocking

    default disable iff (!vif.rst_n);

    property p_hold;
        vif.valid && !vif.ready |=> vif.valid;
    endproperty

    a_hold : assert property (p_hold)
    else begin
        `uvm_error("SVA", "valid dropped before ready")
    end

    property p_stable ;
        vif.valid && !vif.ready |=> $stable({
            vif.write,
            vif.addr,
            vif.wdata
        });
    endproperty

    a_stale : assert property (p_stable)
    else begin
        `uvm_error("SVA", "request change while waiting")
    end

    property p_req_known;
        vif.valid |-> !$isunknown({
            vif.write,
            vif.addr,
            vif.wdata
        });
    endproperty

    a_req_known : assert property (p_req_known)
    else begin
        `uvm_error("SVA", "request has X or Z")
    end

    property p_ready_known;
        !$isunknown(vif.ready);
    endproperty

    a_ready_known : assert property (p_ready_known)
    else begin
        `uvm_error("SVA", "ready has X or Z")
    end

    property p_rdata_known;
        vif.valid && vif.ready && !vif.write |-> !$isunknown(vif.rdata);
    endproperty

    a_rdata_known : assert property (p_rdata_known)
    else begin
        `uvm_error("SVA", "rdata has X or Z")
    end

    c_write : cover property (
        vif.valid && vif.ready && vif.write
    );

    c_read : cover property (
        vif.valid && vif.ready && !vif.write
    );

    c_back_to_back : cover property (
        vif.valid && vif.ready ##1 vif.valid && vif.ready
    );

endmodule
