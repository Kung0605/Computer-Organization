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

    // Pipeline registers
    reg [DWIDTH-1:0] IF_ID_pc;
    reg [DWIDTH-1:0] IF_ID_instr;

    reg [DWIDTH-1:0] ID_EX_pc;
    reg [DWIDTH-1:0] ID_EX_instr;
    reg [3:0]        ID_EX_op;
    reg [3:0]        ID_EX_ssel;
    reg [1:0]        ID_EX_wbsel;
    reg              ID_EX_we_regfile;
    reg              ID_EX_we_dmem;
    reg [2:0]        ID_EX_jump_type;
    reg [25:0]       ID_EX_jump_addr;
    reg [DWIDTH-1:0] ID_EX_imm;
    reg [4:0]        ID_EX_rs1_id;
    reg [4:0]        ID_EX_rs2_id;
    reg [4:0]        ID_EX_rdst_id;
    reg [DWIDTH-1:0] ID_EX_rs1_out;
    reg [DWIDTH-1:0] ID_EX_rs2_out;

    reg [DWIDTH-1:0] EX_MEM_pc;
    reg [DWIDTH-1:0] EX_MEM_instr;
    reg [DWIDTH-1:0] EX_MEM_alu_out;
    reg [1:0]        EX_MEM_wbsel;
    reg              EX_MEM_we_regfile;
    reg              EX_MEM_we_dmem;
    reg [4:0]        EX_MEM_rdst_id;
    reg [DWIDTH-1:0] EX_MEM_rs2_out;

    reg [DWIDTH-1:0] MEM_WB_pc;
    reg [DWIDTH-1:0] MEM_WB_instr;
    reg [DWIDTH-1:0] MEM_WB_rd;
    reg              MEM_WB_we_regfile;
    reg [4:0]        MEM_WB_rdst_id;

    // Hazard detect signals
    wire branch_miss = ((ID_EX_jump_type == J_TYPE_BEQ) && (zero)) || ID_EX_jump_type == J_TYPE_JAL || ID_EX_jump_type == J_TYPE_JR || ID_EX_jump_type == J_TYPE_J;
    wire EX_rs1_data_hazard = (ID_EX_rdst_id == rs1_id   && ID_EX_rdst_id  != 0) && (ID_EX_we_regfile && op != ALU_OP_NOP);
    wire EX_rs2_data_hazard = (ID_EX_rdst_id == rs2_id   && ID_EX_rdst_id  != 0) && (ID_EX_we_regfile && op != ALU_OP_NOP && ssel | we_dmem);
    
    // Hazard control signals
    wire pc_stall = (EX_rs1_data_hazard || EX_rs2_data_hazard) && ID_EX_wbsel == 2'b01;
 
    wire IF_ID_stall = (EX_rs1_data_hazard || EX_rs2_data_hazard) && ID_EX_wbsel == 2'b01;
    wire IF_ID_flush = branch_miss;

    wire ID_EX_stall = 0;
    wire ID_EX_flush = branch_miss || ((EX_rs1_data_hazard || EX_rs2_data_hazard) && ID_EX_wbsel == 2'b01);

    wire EX_MEM_stall = 0;
    wire EX_MEM_flush = 0;

    wire MEM_WB_stall = 0;
    wire MEM_WB_flush = 0;

    reg [1:0] ForwardA;
    reg [1:0] ForwardB;

    always @(*) begin
        if ((EX_MEM_rdst_id == ID_EX_rs1_id && EX_MEM_rdst_id != 0) && (EX_MEM_we_regfile && ID_EX_op != ALU_OP_NOP)) begin
            ForwardA = 2'b01;    
        end
        else begin
            if ((MEM_WB_rdst_id == ID_EX_rs1_id && MEM_WB_rdst_id != 0) && (MEM_WB_we_regfile && ID_EX_op != ALU_OP_NOP)) 
                ForwardA = 2'b10;
            else 
                ForwardA = 2'b00;
        end
    end

    always @(*) begin
        if ((EX_MEM_rdst_id == ID_EX_rs2_id && EX_MEM_rdst_id != 0) && (EX_MEM_we_regfile && ID_EX_op != ALU_OP_NOP && (ID_EX_ssel | ID_EX_we_dmem))) begin
            ForwardB = 2'b01;    
        end
        else begin
            if ((MEM_WB_rdst_id == ID_EX_rs2_id && MEM_WB_rdst_id != 0) && (MEM_WB_we_regfile && ID_EX_op != ALU_OP_NOP && (ID_EX_ssel | ID_EX_we_dmem)))
                ForwardB = 2'b10;
            else 
                ForwardB = 2'b00;
        end
    end
    // Program counter
    assign pc_increment = pc + 4;

    always @(posedge clk) begin
        if (rst)
            pc <= 0;
        else if (pc_stall)
            pc <= pc;
        else if (ID_EX_jump_type == J_TYPE_BEQ && zero) 
            pc <= ID_EX_pc + 'd4 + {ID_EX_imm[29:0], 2'b00};
        else if (ID_EX_jump_type == J_TYPE_JR) 
            pc <= ID_EX_rs1_out;
        else if (ID_EX_jump_type == J_TYPE_JAL || ID_EX_jump_type == J_TYPE_J) 
            pc <= {pc[31:28], ID_EX_jump_addr, 2'b00};
        else
            pc <= pc_increment;
    end
    
    imem imem_inst(
        .addr(pc),
        .rdata(instr)
    );

    // IF/ID pipline registers
    always @(posedge clk) begin
        if (rst) begin
            IF_ID_pc    <= 0;
            IF_ID_instr <= 0;
        end
        else if (IF_ID_stall) begin
            IF_ID_pc    <= IF_ID_pc;
            IF_ID_instr <= IF_ID_instr;
        end
        else if (IF_ID_flush) begin
            IF_ID_pc    <= 0;
            IF_ID_instr <= 0;
        end
        else begin
            IF_ID_pc    <= pc;
            IF_ID_instr <= instr;
        end
    end

    decode decode_inst (
        // input
        .instr(IF_ID_instr),

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
        case (EX_MEM_wbsel)
            2'b00:   rd = EX_MEM_alu_out;
            2'b01:   rd = dmem_out;
            2'b10:   rd = EX_MEM_pc + 'd4;
            default: rd = 0;
        endcase
    end
    wire [DWIDTH-1 : 0] forward_rs1, forward_rs2;
    reg_file reg_file_inst (
        // input
        .clk(clk),
        .rst(rst),

        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .forward_rs1_id(ID_EX_rs1_id),
        .forward_rs2_id(ID_EX_rs2_id),

        .we(MEM_WB_we_regfile),
        .rdst_id(MEM_WB_rdst_id),
        .rdst(MEM_WB_rd),

        // output 
        .rs1(rs1_out), // rs
        .rs2(rs2_out), // rt
        .forward_rs1(forward_rs1),
        .forward_rs2(forward_rs2)
    );

    // ID/EX pipline registers
    always @(posedge clk) begin
        if (rst) begin
            ID_EX_pc         <= 0;
            ID_EX_instr      <= 0;
            ID_EX_op         <= 0;
            ID_EX_ssel       <= 0;
            ID_EX_wbsel      <= 0;
            ID_EX_we_regfile <= 0;
            ID_EX_we_dmem    <= 0;
            ID_EX_jump_type  <= 0;
            ID_EX_jump_addr  <= 0;
            ID_EX_imm        <= 0;
            ID_EX_rs1_id     <= 0;
            ID_EX_rs2_id     <= 0;
            ID_EX_rdst_id    <= 0;
            ID_EX_rs1_out    <= 0;
            ID_EX_rs2_out    <= 0;
        end
        else if (ID_EX_stall) begin
            ID_EX_pc         <= ID_EX_pc;
            ID_EX_instr      <= ID_EX_instr;
            ID_EX_op         <= ID_EX_op;
            ID_EX_ssel       <= ID_EX_ssel;
            ID_EX_wbsel      <= ID_EX_wbsel;
            ID_EX_we_regfile <= ID_EX_we_regfile;
            ID_EX_we_dmem    <= ID_EX_we_dmem;
            ID_EX_jump_type  <= ID_EX_jump_type;
            ID_EX_jump_addr  <= ID_EX_jump_addr;
            ID_EX_imm        <= ID_EX_imm;
            ID_EX_rs1_id     <= ID_EX_rs1_id;
            ID_EX_rs2_id     <= ID_EX_rs2_id;
            ID_EX_rdst_id    <= ID_EX_rdst_id;
            ID_EX_rs1_out    <= ID_EX_rs1_out;
            ID_EX_rs2_out    <= ID_EX_rs2_out;
        end
        else if (ID_EX_flush) begin
            ID_EX_pc         <= 0;
            ID_EX_instr      <= 0;
            ID_EX_op         <= 0;
            ID_EX_ssel       <= 0;
            ID_EX_wbsel      <= 0;
            ID_EX_we_regfile <= 0;
            ID_EX_we_dmem    <= 0;
            ID_EX_jump_type  <= 0;
            ID_EX_jump_addr  <= 0;
            ID_EX_imm        <= 0;
            ID_EX_rs1_id     <= 0;
            ID_EX_rs2_id     <= 0;
            ID_EX_rdst_id    <= 0;
            ID_EX_rs1_out    <= 0;
            ID_EX_rs2_out    <= 0;
        end
        else begin
            ID_EX_pc         <= IF_ID_pc;
            ID_EX_instr      <= IF_ID_instr;
            ID_EX_op         <= op;
            ID_EX_ssel       <= ssel;
            ID_EX_wbsel      <= wbsel;
            ID_EX_we_regfile <= we_regfile;
            ID_EX_we_dmem    <= we_dmem;
            ID_EX_jump_type  <= jump_type;
            ID_EX_jump_addr  <= jump_addr;
            ID_EX_imm        <= imm;
            ID_EX_rs1_id     <= rs1_id;
            ID_EX_rs2_id     <= rs2_id;
            ID_EX_rdst_id    <= rdst_id;
            ID_EX_rs1_out    <= rs1_out;
            ID_EX_rs2_out    <= rs2_out;
        end
    end

    // ALU
    always @(*) begin
        if(ForwardA == 2'b01) begin
            alu_rs1 = EX_MEM_alu_out;
        end
        else if(ForwardA == 2'b10) begin
            alu_rs1 = MEM_WB_rd;
        end
        else begin
            alu_rs1 = forward_rs1;
        end
    end

    reg [DWIDTH-1:0] ID_EX_rs2_result;

    always @(*) begin
        if(ForwardB == 2'b01) begin
            ID_EX_rs2_result = EX_MEM_alu_out;
        end
        else if(ForwardB == 2'b10) begin
            ID_EX_rs2_result = MEM_WB_rd;
        end
        else begin
            ID_EX_rs2_result = forward_rs2;
        end
        alu_rs2 = (ID_EX_ssel) ? ID_EX_rs2_result : ID_EX_imm;
    end

    alu alu_inst (
        // input
        .op(ID_EX_op),
        .rs1(alu_rs1),
        .rs2(alu_rs2),

        // output
        .rd(alu_out),
        .zero(zero),
        .overflow(overflow)
    );

    // EX/MEM pipline registers
    always @(posedge clk) begin
        if (rst) begin
            EX_MEM_pc         <= 0;
            EX_MEM_instr      <= 0;
            EX_MEM_alu_out    <= 0;
            EX_MEM_wbsel      <= 0;
            EX_MEM_we_regfile <= 0;
            EX_MEM_we_dmem    <= 0;
            EX_MEM_rdst_id    <= 0;
            EX_MEM_rs2_out    <= 0;
        end
        else if (EX_MEM_stall) begin
            EX_MEM_pc         <= EX_MEM_pc;
            EX_MEM_instr      <= EX_MEM_instr;
            EX_MEM_alu_out    <= EX_MEM_alu_out;
            EX_MEM_wbsel      <= EX_MEM_wbsel;
            EX_MEM_we_regfile <= EX_MEM_we_regfile;
            EX_MEM_we_dmem    <= EX_MEM_we_dmem;
            EX_MEM_rdst_id    <= EX_MEM_rdst_id;
            EX_MEM_rs2_out    <= EX_MEM_rs2_out;
        end
        else if (EX_MEM_flush) begin
            EX_MEM_pc         <= 0;
            EX_MEM_instr      <= 0;
            EX_MEM_alu_out    <= 0;
            EX_MEM_wbsel      <= 0;
            EX_MEM_we_regfile <= 0;
            EX_MEM_we_dmem    <= 0;
            EX_MEM_rdst_id    <= 0;
            EX_MEM_rs2_out    <= 0;
        end
        else begin
            EX_MEM_pc         <= ID_EX_pc;
            EX_MEM_instr      <= ID_EX_instr;
            EX_MEM_alu_out    <= alu_out;
            EX_MEM_wbsel      <= ID_EX_wbsel;
            EX_MEM_we_regfile <= ID_EX_we_regfile;
            EX_MEM_we_dmem    <= ID_EX_we_dmem;
            EX_MEM_rdst_id    <= ID_EX_rdst_id;
            EX_MEM_rs2_out    <= ID_EX_rs2_result;
        end
    end

    // Dmem
    dmem dmem_inst (
        .clk(clk),
        .addr(EX_MEM_alu_out),
        .we(EX_MEM_we_dmem),
        .wdata(EX_MEM_rs2_out),
        .rdata(dmem_out)
    );

    /// EX/MEM pipline registers
    always @(posedge clk) begin
        if (rst) begin
            MEM_WB_pc         <= 0;
            MEM_WB_instr      <= 0;
            MEM_WB_rd         <= 0;
            MEM_WB_we_regfile <= 0;
            MEM_WB_rdst_id    <= 0;
        end
        else if (MEM_WB_stall) begin
            MEM_WB_pc         <= MEM_WB_pc;
            MEM_WB_instr      <= MEM_WB_instr;
            MEM_WB_rd         <= MEM_WB_rd;
            MEM_WB_we_regfile <= MEM_WB_we_regfile;
            MEM_WB_rdst_id    <= MEM_WB_rdst_id;
        end
        else if (MEM_WB_flush) begin
            MEM_WB_pc         <= 0;
            MEM_WB_instr      <= 0;
            MEM_WB_rd         <= 0;
            MEM_WB_we_regfile <= 0;
            MEM_WB_rdst_id    <= 0;
        end
        else begin
            MEM_WB_pc         <= EX_MEM_pc;
            MEM_WB_instr      <= EX_MEM_instr;
            MEM_WB_rd         <= rd;
            MEM_WB_we_regfile <= EX_MEM_we_regfile;
            MEM_WB_rdst_id    <= EX_MEM_rdst_id;
        end
    end
endmodule 