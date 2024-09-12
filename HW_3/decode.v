/*
 *    Author : Che-Yu Wu @ EISL
 *    Date   : 2022-03-30
 */

module decode #(parameter DWIDTH = 32)
(
    input [DWIDTH-1:0]  instr,   // Input instruction.

    output reg [2 : 0]      jump_type,
    output reg [31 : 0]     jump_addr,
    output reg              we_dmem,
    output reg              we_regfile,
    output reg [3 : 0]      op,      // Operation code for the ALU.
    output reg [1 : 0]      ssel,    // Select the signal for either the immediate value or rs2.

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
            6'h04 : begin 
                rs1_id = instr[25 : 21];
                rs2_id = instr[20 : 16];
                rdst_id = rs2_id;
                op = OP_SUB;
            end
            6'h02 : begin
                rs1_id = 0;
                rs2_id = 0;
                rdst_id = 0;
            end
            6'h23 : begin
                rs1_id = instr[25 : 21];
                rs2_id = instr[20 : 16];
                rdst_id = rs2_id;
                op = OP_ADD;
            end
            6'h2b : begin
                rs1_id = instr[25 : 21];
                rs2_id = instr[20 : 16];
                rdst_id = rs2_id;
                op = OP_ADD;
            end
            6'h03 : begin
                rs1_id = 0;
                rs2_id = 0;
                rdst_id = 31;
                op = 4'b1111;
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
        case (instr[31 : 26])
            6'h08 : ssel = 0;
            6'h0a : ssel = 0;
            6'h23 : ssel = 0;
            6'h2b : ssel = 0;
            6'h03 : ssel = 2;
            default : ssel = 1;
        endcase
        imm = {{16{instr[15]}}, instr[15 : 0]};
    end
    localparam [2:0] J_TYPE_NOP = 3'b000,
                     J_TYPE_BEQ = 3'b001,
                     J_TYPE_JAL = 3'b010,
                     J_TYPE_JR  = 3'b011,
                     J_TYPE_J   = 3'b100;
    always @(*) begin 
        if (instr[31 : 26] == 6'h04)
            jump_type = J_TYPE_BEQ;
        else if (instr[31 : 26] == 6'h03)
            jump_type = J_TYPE_JAL;
        else if (instr[31 : 26] == 6'h02)
            jump_type = J_TYPE_J;
        else if (instr[31 : 26] == 6'h00 && instr[5 : 0] == 6'h08)
            jump_type = J_TYPE_JR;
        else 
            jump_type = 3'b000;
    end
    always @(*)
        jump_addr = {{4{1'b0}}, {instr[25 : 0]}, {2{1'b0}}};
    always @(*)
        we_dmem = (instr[31 : 26] == 6'h2b ? 1'b1 : 1'b0);
    always @(*) begin
        case (instr[31 : 26]) 
            6'h00 : we_regfile = 1;
            6'h08 : we_regfile = 1;
            6'h02 : we_regfile = 1;
            6'h0a : we_regfile = 1;
            6'h23 : we_regfile = 1;
            6'h03 : we_regfile = 1;
            default : we_regfile = 0;
        endcase
    end
endmodule