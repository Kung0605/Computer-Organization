module core_top #(
    parameter DWIDTH = 32
)(
    input                 clk,
    input                 rst
);

    // Jump type
    localparam [2:0] J_TYPE_NOP = 3'b000,
                     J_TYPE_BEQ = 3'b001,
                     J_TYPE_JAL = 3'b010,
                     J_TYPE_JR  = 3'b011,
                     J_TYPE_J   = 3'b100;
    // Program Counter signals
    reg  [DWIDTH-1:0] pc;
    wire [31 : 0] rdata, op;
    wire [31 : 0] imm;
    wire [4 : 0] rs1_id;
    wire [4 : 0] rs2_id;
    wire [4 : 0] rdst_id;
    wire [1 : 0] ssel;
    reg [DWIDTH - 1 : 0] rs1;
    reg [DWIDTH - 1 : 0] rs2;
    always @(posedge clk) begin
        if (rst)
            pc <= 0;
        else 
            pc <= new_pc;
    end
    wire [31 : 0] pc_add_4;
    wire [31 : 0] imm_mul_4;
    assign pc_add_4 = pc + 4, imm_mul_4 = 4 * imm;
    reg [31 : 0] new_pc;
    always @(*) begin 
        case (jump_type)
            J_TYPE_NOP : new_pc = pc_add_4;
            J_TYPE_BEQ : new_pc = zero ? pc_add_4 + imm_mul_4 : pc_add_4;
            J_TYPE_JAL : new_pc = {pc_add_4[31 : 28], {28{1'b0}}} | jump_addr;
            J_TYPE_JR  : new_pc = rs1;
            J_TYPE_J   : new_pc = {pc_add_4[31 : 28], {28{1'b0}}} | jump_addr;
            default : new_pc = pc_add_4;
        endcase
    end
    always @(*) begin
        case (ssel)
            2'b00 : alu_rs2 = imm;
            2'b01 : alu_rs2 = rs2;
            2'b10 : alu_rs2 = pc_add_4;
            default : alu_rs2 = 32'b0;
        endcase
    end
    assign rdst = rdata[31 : 26] == 6'h23 ? dmem_rdata : addr;
    
    imem imem_inst(
        .addr(pc),
        .rdata(rdata)
    );
    wire [2 : 0] jump_type;
    wire [31 : 0] jump_addr;
    wire [31 : 0] jr_address;
    wire we_regfile, we_dmem;
    decode decode_inst (
        // input
        .instr(rdata),

        // output 
        .jump_type(jump_type),
        .jump_addr(jump_addr),
        .we_regfile(we_regfile),
        .we_dmem(we_dmem),

        .op(op),
        .ssel(ssel),
        .imm(imm),
        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .rdst_id(rdst_id)
    );
    wire [31 : 0] rdst;
    reg_file reg_file_inst (
        // input
        .clk(clk),
        .rst(rst),

        .rs1_id(rs1_id),
        .rs2_id(rs2_id),

        .we(we_regfile),
        .rdst_id(rdst_id),
        .rdst(rdst),

        // output 
        .rs1(rs1), // rs
        .rs2(rs2)  // rt
    );
    wire zero;
    reg [31 : 0] alu_rs2;
    alu alu_inst (
        // input
        .op(op),
        .rs1(rs1),
        .rs2(alu_rs2),

        // output
        .rd(addr),
        .zero(zero),
        .overflow()
    );

    // Dmem
    wire [31 : 0] dmem_rdata;
    wire [31 : 0] addr;
    dmem dmem_inst (
        .clk(clk),
        .addr(addr),
        .we(we_dmem),
        .wdata(rs2),
        .rdata(dmem_rdata)
    );
endmodule