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
    // ALU Opcode
    localparam [3:0] ALU_OP_AND = 4'b0000,
                     ALU_OP_OR  = 4'b0001,
                     ALU_OP_ADD = 4'b0010,
                     ALU_OP_SUB = 4'b0110,
                     ALU_OP_NOR = 4'b1100,
                     ALU_OP_SLT = 4'b0111,
                     ALU_OP_NOP = 4'b1111;
    // Program Counter signals
    reg  [DWIDTH-1:0] pc;
    wire [DWIDTH-1:0] pc_increment;
    // Decode signals
    reg  [DWIDTH-1:0] instr;
    wire [3:0]        op;
    wire              ssel;
    wire [1:0]        wbsel;
    wire              we_regfile;
    wire              we_dmem;
    wire [2:0]        jump_type;
    wire [25:0]       jump_addr;
    wire [DWIDTH-1:0] imm;
    wire [4:0]        rs1_id;
    wire [4:0]        rs2_id;
    wire [4:0]        rdst_id;
    // Regfile signals
    reg  [DWIDTH-1:0] rd;
    wire [DWIDTH-1:0] rs1_out;
    wire [DWIDTH-1:0] rs2_out;
    // ALU signals
    reg  [DWIDTH-1:0] alu_rs1;
    reg  [DWIDTH-1:0] alu_rs2;
    wire [DWIDTH-1:0] alu_out;
    wire              zero;
    wire              overflow;
    // Dmem signals
    wire [DWIDTH-1:0] dmem_out;
    // IF/ID
    reg [DWIDTH-1:0] r1_pc;
    reg [DWIDTH-1:0] r1_instr;
    //ID/EXE
    reg [DWIDTH-1:0] r2_pc, r2_instr;
    reg [3:0] r2_op, r2_ssel;
    reg [1:0] r2_wbsel;
    reg r2_we_regfile, r2_we_dmem;
    reg [2:0] r2_jump_type;
    reg [25:0] r2_jump_addr;
    reg [DWIDTH-1:0] r2_imm;
    reg [4:0] r2_rs1_id, r2_rs2_id, r2_rdst_id;
    reg [DWIDTH-1:0] r2_rs1_out, r2_rs2_out;
    //EX/MEM
    reg [DWIDTH-1:0] r3_pc, r3_instr, r3_alu_out;
    reg [1:0] r3_wbsel;
    reg r3_we_regfile, r3_we_dmem;
    reg [4:0] r3_rdst_id;
    reg [DWIDTH-1:0] r3_rs2_out;
    //MEM/WB
    reg [DWIDTH-1:0] r4_pc, r4_instr, r4_rd;
    reg r4_we_regfile;
    reg [4:0] r4_rdst_id;
    reg pc_stall;
    always@(*) begin
        if (
            (r2_rdst_id == rs1_id) && (r2_we_regfile && op != ALU_OP_NOP) ||
            (r2_rdst_id == rs2_id) && (r2_we_regfile && op != ALU_OP_NOP && ssel | we_dmem) ||
            (r3_rdst_id == rs1_id) && (r3_we_regfile && op != ALU_OP_NOP) || 
            (r3_rdst_id == rs2_id) && (r3_we_regfile && op != ALU_OP_NOP && ssel | we_dmem) ||
            (r4_rdst_id == rs1_id) && (r4_we_regfile && op != ALU_OP_NOP) || 
            (r4_rdst_id == rs2_id) && (r4_we_regfile && op != ALU_OP_NOP && ssel | we_dmem)
        )
            pc_stall = 1'b1;
        else 
            pc_stall = 1'b0;
    end
    reg r1_stall;
    always@(*) begin
        if (
            (r2_rdst_id == rs1_id) && (r2_we_regfile && op != ALU_OP_NOP) ||
            (r2_rdst_id == rs2_id) && (r2_we_regfile && op != ALU_OP_NOP && ssel | we_dmem) ||
            (r3_rdst_id == rs1_id) && (r3_we_regfile && op != ALU_OP_NOP) || 
            (r3_rdst_id == rs2_id) && (r3_we_regfile && op != ALU_OP_NOP && ssel | we_dmem) ||
            (r4_rdst_id == rs1_id) && (r4_we_regfile && op != ALU_OP_NOP) || 
            (r4_rdst_id == rs2_id) && (r4_we_regfile && op != ALU_OP_NOP && ssel | we_dmem)
        )
            r1_stall = 1'b1;
        else 
            r1_stall = 1'b0;
    end
    wire r1_flush = ((r2_jump_type == J_TYPE_BEQ) && (zero)) || r2_jump_type == J_TYPE_JAL || r2_jump_type == J_TYPE_JR || r2_jump_type == J_TYPE_J;
    reg r2_stall;
    always@(*) begin
        if (
            (r3_rdst_id == rs1_id) && (r3_we_regfile && op != ALU_OP_NOP) || 
            (r3_rdst_id == rs2_id) && (r3_we_regfile && op != ALU_OP_NOP && ssel | we_dmem) || 
            (r4_rdst_id == rs1_id) && (r4_we_regfile && op != ALU_OP_NOP) || 
            (r4_rdst_id == rs2_id) && (r4_we_regfile && op != ALU_OP_NOP && ssel | we_dmem)
        )
            r2_stall = 1'b1;
        else 
            r2_stall = 1'b0;
    end
    reg r2_flush;
    always @(*) begin
        if (
            (((r2_jump_type == J_TYPE_BEQ) && (zero)) || r2_jump_type == J_TYPE_JAL || r2_jump_type == J_TYPE_JR || r2_jump_type == J_TYPE_J) ||
            (r2_rdst_id == rs1_id) && (r2_we_regfile && op != ALU_OP_NOP) || 
            (r2_rdst_id == rs2_id) && (r2_we_regfile && op != ALU_OP_NOP && ssel | we_dmem)
        )
            r2_flush = 1'b1;
        else 
            r2_flush = 1'b0;
    end
    reg r3_stall;
    always@(*) begin
        if (
            (r4_rdst_id == rs1_id) && (r4_we_regfile && op != ALU_OP_NOP) || 
            (r4_rdst_id == rs2_id) && (r4_we_regfile && op != ALU_OP_NOP && ssel | we_dmem)
        )
            r3_stall = 1'b1;
        else 
            r3_stall = 1'b0;
    end
    reg r3_flush;
    always@(*) begin
        if (
            (r3_rdst_id == rs1_id) && (r3_we_regfile && op != ALU_OP_NOP) || 
            (r3_rdst_id == rs2_id) && (r3_we_regfile && op != ALU_OP_NOP && ssel | we_dmem)
        )
            r3_flush = 1'b1;
        else 
            r3_flush = 1'b0;
    end
    reg r4_stall = 0;
    reg r4_flush;
    always@(*) begin
        if (
            (r4_rdst_id == rs1_id) && (r4_we_regfile && op != ALU_OP_NOP) || 
            (r4_rdst_id == rs2_id) && (r4_we_regfile && op != ALU_OP_NOP && ssel | we_dmem)
        )
            r4_flush = 1'b1;
        else
            r4_flush = 1'b0;
    end
    assign pc_increment = pc + 4;
    always @(posedge clk) begin
        if (rst)
            pc <= 0;
        else if (pc_stall)
            pc <= pc;
        else if (r2_jump_type == J_TYPE_BEQ && zero) 
            pc <= r2_pc + 4 + {r2_imm[29:0], 2'b00};
        else if (r2_jump_type == J_TYPE_JR) 
            pc <= r2_rs1_out;
        else if (r2_jump_type == J_TYPE_JAL || r2_jump_type == J_TYPE_J) 
            pc <= {pc[31:28], r2_jump_addr, 2'b00};
        else
            pc <= pc_increment;
    end
    imem imem_inst(
        .addr(pc),
        .rdata(instr)
    );
    always @(posedge clk) begin
        if (rst) begin
            r1_pc    <= 0;
            r1_instr <= 0;
        end
        else if (r1_stall) begin
            r1_pc    <= r1_pc;
            r1_instr <= r1_instr;
        end
        else if (r1_flush) begin
            r1_pc    <= 0;
            r1_instr <= 0;
        end
        else begin
            r1_pc    <= pc;
            r1_instr <= instr;
        end
    end

    decode decode_inst (
        // input
        .instr(r1_instr),

        // output  
        .op(op),
        .ssel(ssel),
        .wbsel(wbsel),
        .we_regfile(we_regfile),
        .we_dmem(we_dmem),
        .jump_type(jump_type),
        .jump_addr(jump_addr),
        .imm(imm),
        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .rdst_id(rdst_id)
    );

    // Regfile
    always @(*) begin
        case (r3_wbsel)
            2'b00:   rd = r3_alu_out;
            2'b01:   rd = dmem_out;
            2'b10:   rd = r3_pc + 'd4;
            default: rd = 0;
        endcase
    end

    reg_file reg_file_inst (
        // input
        .clk(clk),
        .rst(rst),

        .rs1_id(rs1_id),
        .rs2_id(rs2_id),

        .we(r4_we_regfile),
        .rdst_id(r4_rdst_id),
        .rdst(r4_rd),

        // output 
        .rs1(rs1_out), // rs
        .rs2(rs2_out)  // rt
    );

    // ID/EX 
    always @(posedge clk) begin
        if (rst) begin
            r2_pc         <= 1'b0;
            r2_instr      <= 1'b0;
            r2_op         <= 1'b0;
            r2_ssel       <= 1'b0;
            r2_wbsel      <= 1'b0;
            r2_we_regfile <= 1'b0;
            r2_we_dmem    <= 1'b0;
            r2_jump_type  <= 1'b0;
            r2_jump_addr  <= 1'b0;
            r2_imm        <= 1'b0;
            r2_rs1_id     <= 1'b0;
            r2_rs2_id     <= 1'b0;
            r2_rdst_id    <= 1'b0;
            r2_rs1_out    <= 1'b0;
            r2_rs2_out    <= 1'b0;
        end
        else if (r2_stall) begin
            r2_pc         <= r2_pc;
            r2_instr      <= r2_instr;
            r2_op         <= r2_op;
            r2_ssel       <= r2_ssel;
            r2_wbsel      <= r2_wbsel;
            r2_we_regfile <= r2_we_regfile;
            r2_we_dmem    <= r2_we_dmem;
            r2_jump_type  <= r2_jump_type;
            r2_jump_addr  <= r2_jump_addr;
            r2_imm        <= r2_imm;
            r2_rs1_id     <= r2_rs1_id;
            r2_rs2_id     <= r2_rs2_id;
            r2_rdst_id    <= r2_rdst_id;
            r2_rs1_out    <= r2_rs1_out;
            r2_rs2_out    <= r2_rs2_out;
        end
        else if (r2_flush) begin
            r2_pc         <= 1'b0;
            r2_instr      <= 1'b0;
            r2_op         <= 1'b0;
            r2_ssel       <= 1'b0;
            r2_wbsel      <= 1'b0;
            r2_we_regfile <= 1'b0;
            r2_we_dmem    <= 1'b0;
            r2_jump_type  <= 1'b0;
            r2_jump_addr  <= 1'b0;
            r2_imm        <= 1'b0;
            r2_rs1_id     <= 1'b0;
            r2_rs2_id     <= 1'b0;
            r2_rdst_id    <= 1'b0;
            r2_rs1_out    <= 1'b0;
            r2_rs2_out    <= 1'b0;
        end
        else begin
            r2_pc         <= r1_pc;
            r2_instr      <= r1_instr;
            r2_op         <= op;
            r2_ssel       <= ssel;
            r2_wbsel      <= wbsel;
            r2_we_regfile <= we_regfile;
            r2_we_dmem    <= we_dmem;
            r2_jump_type  <= jump_type;
            r2_jump_addr  <= jump_addr;
            r2_imm        <= imm;
            r2_rs1_id     <= rs1_id;
            r2_rs2_id     <= rs2_id;
            r2_rdst_id    <= rdst_id;
            r2_rs1_out    <= rs1_out;
            r2_rs2_out    <= rs2_out;
        end
    end

    // ALU
    always @(*) begin
        alu_rs1 = r2_rs1_out;
    end

    always @(*) begin
        alu_rs2 = r2_ssel ? r2_rs2_out : r2_imm;
    end

    alu alu_inst (
        // input
        .op(r2_op),
        .rs1(alu_rs1),
        .rs2(alu_rs2),

        // output
        .rd(alu_out),
        .zero(zero),
        .overflow(overflow)
    );

    // EX/MEM 
    always @(posedge clk) begin
        if (rst) begin
            r3_pc         <= 1'b0;
            r3_instr      <= 1'b0;
            r3_alu_out    <= 1'b0;
            r3_wbsel      <= 1'b0;
            r3_we_regfile <= 1'b0;
            r3_we_dmem    <= 1'b0;
            r3_rdst_id    <= 1'b0;
            r3_rs2_out    <= 1'b0;
        end
        else if (r3_stall) begin
            r3_pc         <= r3_pc;
            r3_instr      <= r3_instr;
            r3_alu_out    <= r3_alu_out;
            r3_wbsel      <= r3_wbsel;
            r3_we_regfile <= r3_we_regfile;
            r3_we_dmem    <= r3_we_dmem;
            r3_rdst_id    <= r3_rdst_id;
            r3_rs2_out    <= r3_rs2_out;
        end
        else if (r3_flush) begin
            r3_pc         <= 1'b0;
            r3_instr      <= 1'b0;
            r3_alu_out    <= 1'b0;
            r3_wbsel      <= 1'b0;
            r3_we_regfile <= 1'b0;
            r3_we_dmem    <= 1'b0;
            r3_rdst_id    <= 1'b0;
            r3_rs2_out    <= 1'b0;
        end
        else begin
            r3_pc         <= r2_pc;
            r3_instr      <= r2_instr;
            r3_alu_out    <= alu_out;
            r3_wbsel      <= r2_wbsel;
            r3_we_regfile <= r2_we_regfile;
            r3_we_dmem    <= r2_we_dmem;
            r3_rdst_id    <= r2_rdst_id;
            r3_rs2_out    <= r2_rs2_out;
        end
    end

    // Dmem
    dmem dmem_inst (
        .clk(clk),
        .addr(r3_alu_out),
        .we(r3_we_dmem),
        .wdata(r3_rs2_out),
        .rdata(dmem_out)
    );

    /// MEM/WB 
    always @(posedge clk) begin
        if (rst) begin
            r4_pc         <= 1'b0;
            r4_instr      <= 1'b0;
            r4_rd         <= 1'b0;
            r4_we_regfile <= 1'b0;
            r4_rdst_id    <= 1'b0;
        end
        else if (r4_stall) begin
            r4_pc         <= r4_pc;
            r4_instr      <= r4_instr;
            r4_rd         <= r4_rd;
            r4_we_regfile <= r4_we_regfile;
            r4_rdst_id    <= r4_rdst_id;
        end
        else if (r4_flush) begin
            r4_pc         <= 1'b0;
            r4_instr      <= 1'b0;
            r4_rd         <= 1'b0;
            r4_we_regfile <= 1'b0;
            r4_rdst_id    <= 1'b0;
        end
        else begin
            r4_pc         <= r3_pc;
            r4_instr      <= r3_instr;
            r4_rd         <= rd;
            r4_we_regfile <= r3_we_regfile;
            r4_rdst_id    <= r3_rdst_id;
        end
    end
    

endmodule