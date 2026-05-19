`timescale 1ns / 1ps

module FifoAssertions (
    FifoIf vif_fifo
);

    default clocking cb @(posedge vif_fifo.iClk);
    endclocking

    default disable iff (!vif_fifo.iRstn);

    property p_flags_known;
        !$isunknown({vif_fifo.Full, vif_fifo.Empty});
    endproperty

    assert_flags_known: assert property (p_flags_known)
        else $error("FIFO flags contain X/Z");

    property p_not_full_and_empty;
        !(vif_fifo.Full && vif_fifo.Empty);
    endproperty

    assert_not_full_and_empty: assert property (p_not_full_and_empty)
        else $error("FIFO Full and Empty asserted together");

    property p_read_data_known;
        (vif_fifo.Rd_En && !vif_fifo.Empty) |=> !$isunknown(vif_fifo.oData);
    endproperty

    assert_read_data_known: assert property (p_read_data_known)
        else $error("FIFO read data contains X/Z after an accepted read");

    cover_write_fire: cover property (vif_fifo.Wr_En && !vif_fifo.Full);
    cover_read_fire:  cover property (vif_fifo.Rd_En && !vif_fifo.Empty);
    cover_full:       cover property (vif_fifo.Full);
    cover_empty:      cover property (vif_fifo.Empty);

endmodule
