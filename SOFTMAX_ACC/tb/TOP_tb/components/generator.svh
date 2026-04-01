`ifndef TOP_GENERATOR_SVH
`define TOP_GENERATOR_SVH

class TopGenerator;
    TopConfig            m_cfg;
    mailbox #(TopFrameTx) mbx_gen2drv;
    mailbox #(TopFrameTx) mbx_gen2mon;
    TopFrameTx            m_frame_queue[$];
    int unsigned          m_next_frame_id;
    bit                   m_start_requested;
    bit                   m_done;
    event                 ev_start;

    function new(
        input TopConfig cfg,
        mailbox #(TopFrameTx) iMbxGen2Drv,
        mailbox #(TopFrameTx) iMbxGen2Mon
    );
        this.m_cfg = cfg;
        this.mbx_gen2drv = iMbxGen2Drv;
        this.mbx_gen2mon = iMbxGen2Mon;
        this.m_next_frame_id = 1;
        this.m_start_requested = 1'b0;
        this.m_done = 1'b0;
    endfunction

    function void clear();
        m_frame_queue.delete();
        m_next_frame_id = 1;
        m_done = 1'b0;
        m_start_requested = 1'b0;
    endfunction

    function void add_frame(input TopFrameTx txItem);
        TopFrameTx txClone;
    begin
        txClone = txItem.clone();
        if (txClone.m_frame_id == 0) begin
            txClone.m_frame_id = m_next_frame_id;
            m_next_frame_id++;
        end else if (txClone.m_frame_id >= m_next_frame_id) begin
            m_next_frame_id = txClone.m_frame_id + 1;
        end
        txClone.apply_keep_kind();
        m_frame_queue.push_back(txClone);
    end
    endfunction

    function bit is_done();
        return m_done;
    endfunction

    task automatic start();
    begin
        if (!m_start_requested) begin
            m_start_requested = 1'b1;
            ->ev_start;
        end
    end
    endtask

    virtual task run();
        int idx;
    begin
        if (!m_start_requested)
            @(ev_start);

        `TB_INFO($sformatf("Generator queued %0d frame(s)", m_frame_queue.size()));
        for (idx = 0; idx < m_frame_queue.size(); idx++) begin
            mbx_gen2drv.put(m_frame_queue[idx].clone());
            mbx_gen2mon.put(m_frame_queue[idx].clone());
            `TB_INFO($sformatf("GEN : %s", m_frame_queue[idx].sprint()));
        end

        mbx_gen2drv.put(null);
        mbx_gen2mon.put(null);
        m_done = 1'b1;
    end
    endtask
endclass

`endif
