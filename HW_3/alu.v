module alu #(parameter DWIDTH = 32) 
(
    input [3 : 0] op,
    input [DWIDTH-1 : 0] rs1,
    input [DWIDTH-1 : 0] rs2,

    output [DWIDTH-1 : 0] rd,
    output zero,
    output overflow
);
    reg [DWIDTH-1 : 0] tmp;
    reg t_overflow = 0;
    always @(*) begin
        case (op)
            4'b0000: tmp = rs1 & rs2;
            4'b0001: tmp = rs1 | rs2;
            4'b0010: tmp = rs1 + rs2;
            4'b0110: tmp = rs1 - rs2; 
            4'b1100: tmp = ~(rs1 | rs2);
            4'b0111: tmp = ($signed(rs1) < $signed(rs2)) ? 32'h1 : 32'h0;
            4'b1111: tmp = rs2;
            default: tmp = 1'b0;
        endcase 
    end
    always @(*) begin
        if (op == 4'b0010)   
            t_overflow = ((rs1[DWIDTH-1] == 1  && rs2[DWIDTH-1] == 1 && rd[DWIDTH-1] == 0) || (rs1[DWIDTH-1] == 0 && rs2[DWIDTH-1] == 0 && rd[DWIDTH-1] == 1)) ? 1'b1 : 1'b0;
        else if (op == 4'b0110)
            t_overflow = ((rs1[DWIDTH-1] == 0  && rs2[DWIDTH-1] == 1 && rd[DWIDTH-1] == 1) || (rs1[DWIDTH-1] == 1 && rs2[DWIDTH-1] == 0 && rd[DWIDTH-1] == 0)) ? 1'b1 : 1'b0;
        else                          
            t_overflow = 1'b0;
    end
    assign zero = (rd == 0) ? 1'b1 : 1'b0;
    assign overflow = t_overflow;
    assign rd = tmp;
endmodule