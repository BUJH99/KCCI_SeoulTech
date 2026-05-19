`timescale 1 ps / 1 ps

module glbl;

  parameter integer ROC_WIDTH = 100000;
  parameter integer TOC_WIDTH = 0;

  wire GSR;
  wire GTS;
  wire PRLD;
  wire GRESTORE;
  tri1 p_up_tmp;
  tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

  reg GSR_int;
  reg GTS_int;
  reg PRLD_int;
  reg GRESTORE_int;

  assign (weak1, weak0) GSR = GSR_int;
  assign (weak1, weak0) GTS = GTS_int;
  assign (weak1, weak0) PRLD = PRLD_int;
  assign (weak1, weak0) GRESTORE = GRESTORE_int;

  initial begin
    GSR_int = 1'b1;
    PRLD_int = 1'b1;
    #(ROC_WIDTH);
    GSR_int = 1'b0;
    PRLD_int = 1'b0;
  end

  initial begin
    GTS_int = 1'b1;
    #(TOC_WIDTH);
    GTS_int = 1'b0;
  end

  initial begin
    GRESTORE_int = 1'b0;
  end

endmodule
