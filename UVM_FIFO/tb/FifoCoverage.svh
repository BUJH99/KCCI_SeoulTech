class FifoCoverage extends uvm_subscriber #(FifoItem);

    `uvm_component_utils(FifoCoverage)

    bit                       sample_wr_en;
    bit                       sample_rd_en;
    bit                       sample_wr_fire;
    bit                       sample_rd_fire;
    bit [1:0]                 sample_cmd;
    bit [FIFO_DATA_WIDTH-1:0] sample_data;
    bit [FIFO_DATA_WIDTH-1:0] sample_rdata;
    int unsigned              sample_level;
    protected int unsigned    m_level;

    covergroup cg_fifo;
        option.per_instance = 1;

        cp_cmd: coverpoint sample_cmd {
            bins b_idle       = {2'b00};
            bins b_write      = {2'b10};
            bins b_read       = {2'b01};
            bins b_write_read = {2'b11};
        }

        cp_wr_fire: coverpoint sample_wr_fire {
            bins b_blocked  = {0};
            bins b_accepted = {1};
        }

        cp_rd_fire: coverpoint sample_rd_fire {
            bins b_blocked  = {0};
            bins b_accepted = {1};
        }

        cp_level: coverpoint sample_level {
            bins b_empty = {0};
            bins b_low   = {[1:FIFO_DEPTH-1]};
            bins b_full  = {FIFO_DEPTH};
        }

        cp_data: coverpoint sample_data iff (sample_wr_en) {
            bins b_zero  = {'0};
            bins b_max   = {(1 << FIFO_DATA_WIDTH) - 1};
            bins b_other = default;
        }

        cp_rdata: coverpoint sample_rdata iff (sample_rd_fire) {
            bins b_zero  = {'0};
            bins b_max   = {(1 << FIFO_DATA_WIDTH) - 1};
            bins b_other = default;
        }

        cx_cmd_level: cross cp_cmd, cp_level;
    endgroup

    function new(input string name = "FifoCoverage", input uvm_component parent = null);
        super.new(name, parent);
        cg_fifo = new();
        m_level = 0;
    endfunction

    virtual function void write(input FifoItem item);
        sample_wr_en   = item.WrEn;
        sample_rd_en   = item.RdEn;
        sample_wr_fire = item.WrEn && !item.Full;
        sample_rd_fire = item.RdEn && !item.Empty;
        sample_cmd     = {item.WrEn, item.RdEn};
        sample_data    = item.Data;
        sample_rdata   = item.RData;
        sample_level   = m_level;

        cg_fifo.sample();

        if (sample_rd_fire && (m_level > 0)) begin
            m_level--;
        end

        if (sample_wr_fire && (m_level < FIFO_DEPTH)) begin
            m_level++;
        end
    endfunction

endclass
