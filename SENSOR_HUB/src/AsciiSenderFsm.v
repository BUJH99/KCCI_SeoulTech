/*
[MODULE_INFO_START]
Name: AsciiSenderFsm
Role: 페이로드를 UART ASCII 바이트 스트림으로 변환하는 송신 FSM
Summary:
  - TIME, STATE, SR04, DHT11 형식에 맞춰 바이트 시퀀스를 생성합니다.
  - 송신기 ready/valid 핸드셰이크를 사용해 바이트 전송 타이밍을 제어합니다.
StateDescription:
  - IDLE: 전송 시작(i_start) 입력을 대기하고 전송 카운터를 초기화합니다.
  - TIME: 시계 포맷(HH:MM:SS:CS) 데이터를 ASCII로 순차 전송합니다.
  - STATE: 모드/잠금/편집 상태 정보를 문자열 형태로 전송합니다.
  - SR04: 초음파 거리 데이터를 ASCII 숫자와 단위(m)로 전송합니다.
  - DHT11: 온습도 데이터를 ASCII 숫자와 기호(%, C)로 전송합니다.
  - STOP: CR/LF 종료 문자를 전송한 뒤 IDLE로 복귀합니다.
[MODULE_INFO_END]
*/
module AsciiSenderFsm (
    input             iClk,
    input             iRst,
    input      [1:0]  i_c_mode,
    input             i_start,
    input      [31:0] i_dec_data,
    input             i_sender_ready,

    output reg [7:0]  send_data,
    output reg        send_valid
);

    localparam IDLE    = 3'd0;
    localparam TIME    = 3'd1;
    localparam STATE   = 3'd2;
    localparam SR04    = 3'd3;
    localparam DHT11   = 3'd4;
    localparam STOP    = 3'd5;

    localparam ASCII_0       = 8'h30;
    localparam ASCII_1       = 8'h31;
    localparam ASCII_LF      = 8'h0a;
    localparam ASCII_CR      = 8'h0d;
    localparam ASCII_PERCENT = 8'h25;
    localparam ASCII_C       = 8'h43;
    localparam ASCII_DOT     = 8'h2e;
    localparam ASCII_COLON   = 8'h3a;
    localparam ASCII_M       = 8'h6d;
    localparam ASCII_SPACE   = 8'h20;

    localparam ASCII_M_UP    = 8'h4d;
    localparam ASCII_L_UP    = 8'h4c;
    localparam ASCII_E_UP    = 8'h45;
    localparam ASCII_A_UP    = 8'h41;
    localparam ASCII_W_UP    = 8'h57;
    localparam ASCII_S_UP    = 8'h53;
    localparam ASCII_H_UP    = 8'h48;
    localparam ASCII_D_UP    = 8'h44;

    reg [2:0]  c_state;
    reg [2:0]  n_state;
    reg [3:0]  send_cnt;
    reg [31:0] dec_data;
    reg        stop_phase; // 0: CR, 1: LF

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            c_state <= IDLE;
        end else begin
            c_state <= n_state;
        end
    end

    always @(*) begin
        n_state = c_state;
        case (c_state)
            IDLE: begin
                if (i_start) begin
                    if (i_c_mode == 2'd3) begin
                        n_state = DHT11;
                    end else if (i_c_mode == 2'd2) begin
                        n_state = SR04;
                    end else if (i_c_mode == 2'd1) begin
                        n_state = STATE;
                    end else begin
                        n_state = TIME;
                    end
                end
            end
            TIME:  if (i_sender_ready && (send_cnt == 4'd11)) n_state = STOP;
            STATE: if (i_sender_ready && (send_cnt == 4'd11)) n_state = STOP;
            SR04:  if (i_sender_ready && (send_cnt == 4'd9))  n_state = STOP;
            DHT11: if (i_sender_ready && (send_cnt == 4'd12)) n_state = STOP;
            STOP:  if (i_sender_ready && (stop_phase == 1'b1)) n_state = IDLE;
            default: n_state = IDLE;
        endcase
    end

    always @(posedge iClk or posedge iRst) begin
        if (iRst) begin
            send_cnt   <= 4'd0;
            dec_data   <= 32'd0;
            send_data  <= 8'd0;
            send_valid <= 1'b0;
            stop_phase <= 1'b0;
        end else begin
            send_valid <= 1'b0;

            case (c_state)
                IDLE: begin
                    send_cnt <= 4'd0;
                    stop_phase <= 1'b0;
                    if (i_start) begin
                        dec_data <= i_dec_data;
                    end
                end

                TIME: begin
                    if (i_sender_ready && (send_cnt < 4'd11)) begin
                        send_valid <= 1'b1;
                        if ((send_cnt == 4'd2) || (send_cnt == 4'd5) || (send_cnt == 4'd8)) begin
                            send_data <= ASCII_COLON;
                        end else begin
                            send_data <= {4'b0, dec_data[31:28]} + ASCII_0;
                            dec_data  <= {dec_data[27:0], 4'b0};
                        end
                        send_cnt <= send_cnt + 1'b1;
                        if (send_cnt == 4'd10) begin
                            stop_phase <= 1'b0;
                        end
                    end
                end

                STATE: begin
                    if (i_sender_ready && (send_cnt < 4'd11)) begin
                        send_valid <= 1'b1;
                        case (send_cnt)
                            4'd0: send_data <= ASCII_M_UP;
                            4'd1: begin
                                case (dec_data[1:0])
                                    2'd0: send_data <= ASCII_W_UP;
                                    2'd1: send_data <= ASCII_S_UP;
                                    2'd2: send_data <= ASCII_H_UP;
                                    default: send_data <= ASCII_D_UP;
                                endcase
                            end
                            4'd2: send_data <= ASCII_SPACE;
                            4'd3: send_data <= ASCII_L_UP;
                            4'd4: send_data <= (dec_data[2] ? ASCII_1 : ASCII_0);
                            4'd5: send_data <= ASCII_SPACE;
                            4'd6: send_data <= ASCII_E_UP;
                            4'd7: send_data <= (dec_data[3] ? ASCII_1 : ASCII_0);
                            4'd8: send_data <= ASCII_SPACE;
                            4'd9: send_data <= ASCII_A_UP;
                            4'd10: send_data <= (dec_data[4] ? ASCII_1 : ASCII_0);
                            default: send_data <= ASCII_SPACE;
                        endcase
                        send_cnt <= send_cnt + 1'b1;
                        if (send_cnt == 4'd10) begin
                            stop_phase <= 1'b0;
                        end
                    end
                end

                SR04: begin
                    if (i_sender_ready) begin
                        if (send_cnt == 4'd9) begin
                            send_valid <= 1'b1;
                            send_data  <= ASCII_M;
                            stop_phase <= 1'b0;
                        end else if (send_cnt < 4'd9) begin
                            send_valid <= 1'b1;
                            if (send_cnt == 4'd6) begin
                                send_data <= ASCII_DOT;
                            end else begin
                                send_data <= {4'b0, dec_data[31:28]} + ASCII_0;
                                dec_data  <= {dec_data[27:0], 4'b0};
                            end
                            send_cnt <= send_cnt + 1'b1;
                        end
                    end
                end

                DHT11: begin
                    if (i_sender_ready) begin
                        if (send_cnt == 4'd12) begin
                            send_valid <= 1'b1;
                            send_data  <= ASCII_C;
                            stop_phase <= 1'b0;
                        end else if (send_cnt < 4'd12) begin
                            send_valid <= 1'b1;
                            if ((send_cnt == 4'd2) || (send_cnt == 4'd9)) begin
                                send_data <= ASCII_DOT;
                            end else if (send_cnt == 4'd5) begin
                                send_data <= ASCII_PERCENT;
                            end else if (send_cnt == 4'd6) begin
                                send_data <= ASCII_SPACE;
                            end else begin
                                send_data <= {4'b0, dec_data[31:28]} + ASCII_0;
                                dec_data  <= {dec_data[27:0], 4'b0};
                            end
                            send_cnt <= send_cnt + 1'b1;
                        end
                    end
                end

                STOP: begin
                    if (i_sender_ready) begin
                        send_valid <= 1'b1;
                        if (stop_phase == 1'b0) begin
                            send_data  <= ASCII_CR;
                            stop_phase <= 1'b1;
                        end else begin
                            send_data  <= ASCII_LF;
                            stop_phase <= 1'b0;
                        end
                    end
                end

                default: begin
                    // no-op
                end
            endcase
        end
    end

endmodule

