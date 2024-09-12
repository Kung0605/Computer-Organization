/*
 *    Author : Che-Yu Wu @ EISL
 *    Date   : 2022-03-30
 */

module decode #(parameter DWIDTH = 32)
(
    input [DWIDTH-1:0]  instr,   // Input instruction.

    output reg [3 : 0]      op,      // Operation code for the ALU.
    output reg              ssel,    // Select the signal for either the immediate value or rs2.

    output reg [DWIDTH-1:0] imm,     // The immediate value (if used).
    output reg [4 : 0]      rs1_id,  // register ID for rs.
    output reg [4 : 0]      rs2_id,  // register ID for rt (if used).
    output reg [4 : 0]      rdst_id // register ID for rd or rt (if used).
);

/***************************************************************************************
    ---------------------------------------------------------------------------------
    | R_type |    |   opcode   |   rs   |   rt   |   rd   |   shamt   |    funct    |
    ---------------------------------------------------------------------------------
    | I_type |    |   opcode   |   rs   |   rt   |             immediate            |
    ---------------------------------------------------------------------------------
    | J_type |    |   opcode   |                     address                        |
    ---------------------------------------------------------------------------------
                   31        26 25    21 20    16 15    11 10        6 5           0
 ***************************************************************************************/

    localparam [3:0] OP_AND = 4'b0000,
                     OP_OR  = 4'b0001,
                     OP_ADD = 4'b0010,
                     OP_SUB = 4'b0110,
                     OP_NOR = 4'b1100,
                     OP_SLT = 4'b0111,
                     OP_NOT_DEFINED = 4'b1111;
    always @(*) begin
        case(instr[31 : 26])
            6'h00 : begin
                rs1_id = instr[25 : 21];
                rs2_id = instr[20 : 16];
                rdst_id = instr[15 : 11];
                case(instr[5 : 0]) 
                    6'h20 : op = OP_ADD;
                    6'h22 : op = OP_SUB;
                    6'h24 : op = OP_AND;
                    6'h25 : op = OP_OR;
                    6'h27 : op = OP_NOR;
                    6'h2a : op = OP_SLT;
                    default : op = OP_NOT_DEFINED;
                endcase
            end
            6'h08 : begin
                rs1_id = instr[25:21];
                rs2_id = instr[20 : 16];
                rdst_id = rs2_id;
                op = OP_ADD;
            end
            6'h0a : begin
                rs1_id = instr[25:21];
                rs2_id = instr[20 : 16];
                rdst_id = rs2_id;
                op = OP_SLT;
            end
            default : begin
                rs1_id = 0;
                rs2_id = 0;
                rdst_id = 0;
                op = 0;
            end
        endcase
    end
    always @(*) begin
        ssel = ~(instr[31 : 26] == 6'h08 || instr[31 : 26] == 6'h0a);
        imm = {{16{instr[15]}}, instr[15 : 0]};
    end
endmodule