`timescale 1ns / 1ps

module Top #(
    parameter int Width = 4,
    parameter int Depth = 8,
    parameter int Addr  = $clog2(Depth)
)(
    input  logic [Width-1:0] iData,
    input  logic             Wr_En,
    input  logic             Rd_En,
    input  logic             iClk,
    input  logic             iRstn,

    output logic [Width-1:0] oData,
    output logic             Full,
    output logic             Empty
);

    logic [Width-1:0] Mem [0:Depth-1] ;

    logic [Addr:0] Cnt ;

    logic [Addr-1:0] WrPtr;
    logic [Addr-1:0] RdPtr;

    logic  Wr_Fire;
    logic  Rd_Fire;

    assign Full =  (Cnt == Depth);
    assign Empty = (Cnt == 0);

    assign Wr_Fire = Wr_En && !Full;
    assign Rd_Fire = Rd_En && !Empty;

    always_ff @(posedge iClk or negedge iRstn) begin
    if (!iRstn) begin
        oData <=0 ;
        WrPtr <=0 ;
        RdPtr <=0 ;
        Cnt   <=0 ;
    end
    else begin

        //Write
        if (Wr_Fire) begin
            Mem[WrPtr] <= iData;

            if (WrPtr == Depth-1)
                WrPtr <= 0 ;
            else
                WrPtr <= WrPtr + 1'b1;
        end

        //Read
        if (Rd_Fire) begin
            oData <= Mem[RdPtr];
            if (RdPtr == Depth-1)
                RdPtr <= 0;
            else
                RdPtr <= RdPtr + 1'b1;
        end

       case ({Wr_Fire, Rd_Fire})
            2'b10: Cnt <= Cnt + 1'b1;
            2'b01: Cnt <= Cnt - 1'b1;
            2'b11: Cnt <= Cnt;
            default : Cnt <= Cnt;
       endcase
    end
    end
endmodule

