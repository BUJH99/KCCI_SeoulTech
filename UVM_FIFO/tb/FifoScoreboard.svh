class FifoScoreboard extends uvm_scoreboard;

    `uvm_component_utils(FifoScoreboard)

    uvm_analysis_imp #(FifoItem, FifoScoreboard) imp;

    protected logic [FIFO_DATA_WIDTH-1:0] m_model_q[$];
    protected int unsigned                m_cycle_count;
    protected int unsigned                m_write_count;
    protected int unsigned                m_read_count;

    function new(string name = "FifoScoreboard", uvm_component parent = null);
        super.new(name, parent);
        imp = new("imp", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        m_model_q.delete();
        m_cycle_count = 0;
        m_write_count = 0;
        m_read_count  = 0;
    endfunction

    virtual function void write(FifoItem item);
        bit                         expected_full;
        bit                         expected_empty;
        bit                         wr_fire;
        bit                         rd_fire;
        logic [FIFO_DATA_WIDTH-1:0] expected_rdata;

        m_cycle_count++;

        expected_full  = (m_model_q.size() == FIFO_DEPTH);
        expected_empty = (m_model_q.size() == 0);

        if (item.Full !== expected_full) begin
            `uvm_error("FIFO_SCB", $sformatf(
                "Full flag mismatch before cycle %0d: expected=%0b actual=%0b item={%s}",
                m_cycle_count,
                expected_full,
                item.Full,
                item.convert2string()
            ))
        end

        if (item.Empty !== expected_empty) begin
            `uvm_error("FIFO_SCB", $sformatf(
                "Empty flag mismatch before cycle %0d: expected=%0b actual=%0b item={%s}",
                m_cycle_count,
                expected_empty,
                item.Empty,
                item.convert2string()
            ))
        end

        wr_fire = item.WrEn && !expected_full;
        rd_fire = item.RdEn && !expected_empty;

        if (rd_fire) begin
            expected_rdata = m_model_q.pop_front();
            m_read_count++;

            if (item.RData !== expected_rdata) begin
                `uvm_error("FIFO_SCB", $sformatf(
                    "Read data mismatch at cycle %0d: expected=0x%0h actual=0x%0h item={%s}",
                    m_cycle_count,
                    expected_rdata,
                    item.RData,
                    item.convert2string()
                ))
            end
        end

        if (wr_fire) begin
            m_model_q.push_back(item.Data);
            m_write_count++;
        end

        expected_full  = (m_model_q.size() == FIFO_DEPTH);
        expected_empty = (m_model_q.size() == 0);

        if (item.PostFull !== expected_full) begin
            `uvm_error("FIFO_SCB", $sformatf(
                "Full flag mismatch after cycle %0d: expected=%0b actual=%0b item={%s}",
                m_cycle_count,
                expected_full,
                item.PostFull,
                item.convert2string()
            ))
        end

        if (item.PostEmpty !== expected_empty) begin
            `uvm_error("FIFO_SCB", $sformatf(
                "Empty flag mismatch after cycle %0d: expected=%0b actual=%0b item={%s}",
                m_cycle_count,
                expected_empty,
                item.PostEmpty,
                item.convert2string()
            ))
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);

        `uvm_info("FIFO_SCB", $sformatf(
            "Checked %0d cycles, accepted writes=%0d, accepted reads=%0d, remaining model depth=%0d",
            m_cycle_count,
            m_write_count,
            m_read_count,
            m_model_q.size()
        ), UVM_LOW)
    endfunction

endclass
