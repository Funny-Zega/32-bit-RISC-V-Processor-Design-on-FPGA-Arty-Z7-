`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31
// inst. are 32 bits in RV32IM
`define INST_SIZE 31
// RV opcodes are 7 bits
`define OPCODE_SIZE 6
`define DIVIDER_STAGES 8

//Others
`include "cla.v"
`include "DividerUnsignedPipelined.v"

module RegFile (
  input      [        4:0] rd,
  input      [`REG_SIZE:0] rd_data,
  input      [        4:0] div_rd,
  input      [`REG_SIZE:0] div_rd_data,
  input                    div_we,
  input      [        4:0] rs1,
  output reg [`REG_SIZE:0] rs1_data,
  input      [        4:0] rs2,
  output reg [`REG_SIZE:0] rs2_data,
  input                    clk,
  input                    we,
  input                    rst
);
  localparam NumRegs = 32;
  reg [`REG_SIZE:0] regs[0:NumRegs-1];
  integer i;
  
  always @(posedge clk) begin
    if (rst) begin
      for (i = 0; i < NumRegs; i = i + 1) regs[i] <= 32'b0;
    end else begin
      if (div_we && (div_rd != 5'b0)) regs[div_rd] <= div_rd_data;
      if (we && (rd != 5'b0)) regs[rd] <= rd_data;
    end
  end

  always @(*) begin
    rs1_data = (rs1 == 5'b0) ? 32'b0 : regs[rs1];
    rs2_data = (rs2 == 5'b0) ? 32'b0 : regs[rs2];
    if (we && rd != 5'b0) begin
       if (rd == rs1) rs1_data = rd_data;
       if (rd == rs2) rs2_data = rd_data;
    end
  end
endmodule

module DatapathPipelined (
  input                     clk,
  input                     rst,
  output     [ `REG_SIZE:0] pc_to_imem,
  input      [`INST_SIZE:0] inst_from_imem,
  output reg [ `REG_SIZE:0] addr_to_dmem,
  input      [ `REG_SIZE:0] load_data_from_dmem,
  output reg [ `REG_SIZE:0] store_data_to_dmem,
  output reg [         3:0] store_we_to_dmem,
  output reg                halt,
  output reg [ `REG_SIZE:0] trace_writeback_pc,
  output reg [`INST_SIZE:0] trace_writeback_inst
);

  // Opcodes
  localparam [`OPCODE_SIZE:0] OpcodeLoad    = 7'b00_000_11;
  localparam [`OPCODE_SIZE:0] OpcodeStore   = 7'b01_000_11;
  localparam [`OPCODE_SIZE:0] OpcodeBranch  = 7'b11_000_11;
  localparam [`OPCODE_SIZE:0] OpcodeJalr    = 7'b11_001_11;
  localparam [`OPCODE_SIZE:0] OpcodeJal     = 7'b11_011_11;
  localparam [`OPCODE_SIZE:0] OpcodeRegImm  = 7'b00_100_11;
  localparam [`OPCODE_SIZE:0] OpcodeRegReg  = 7'b01_100_11;
  localparam [`OPCODE_SIZE:0] OpcodeEnviron = 7'b11_100_11;
  localparam [`OPCODE_SIZE:0] OpcodeAuipc   = 7'b00_101_11;
  localparam [`OPCODE_SIZE:0] OpcodeLui     = 7'b01_101_11;

  // Cycle counter
  reg [`REG_SIZE:0] cycles_current;
  always @(posedge clk) begin
    if (rst) cycles_current <= 0;
    else cycles_current <= cycles_current + 1;
  end

  // ==============================================================================
  // PIPELINE REGISTERS
  // ==============================================================================
  reg [31:0] d_pc, d_inst;
  reg d_valid;

  reg [31:0] x_pc, x_inst, x_rs1_data, x_rs2_data, x_imm;
  reg [4:0]  x_rd; 
  reg [4:0]  x_rs1_addr, x_rs2_addr;
  reg [3:0]  x_alu_op;
  reg        x_alu_src_b, x_is_branch, x_is_jal, x_is_jalr;
  reg        x_is_load, x_is_store, x_mem_read, x_mem_write, x_reg_write;
  reg [1:0]  x_result_src;
  reg [2:0]  x_funct3;
  reg [6:0]  x_opcode, x_funct7;
  reg        x_is_m_extension;
  reg        x_valid;

  reg [31:0] m_pc, m_inst, m_alu_result, m_write_data;
  reg [4:0]  m_rd;
  reg        m_mem_read, m_mem_write, m_reg_write;
  reg [1:0]  m_result_src;
  reg [2:0]  m_funct3;
  reg        m_valid;

  reg [31:0] w_pc, w_inst, w_alu_result, w_mem_data;
  reg [4:0]  w_rd;
  reg        w_reg_write;
  reg [1:0]  w_result_src;
  reg        w_valid;

  // ==============================================================================
  // MAPPING & FORWARD DECLARATION
  // ==============================================================================
  wire [4:0] d_rs1_idx = d_inst[19:15];
  wire [4:0] d_rs2_idx = d_inst[24:20];
  wire [4:0] d_rd_idx  = d_inst[11:7];
  
  
  wire [4:0] x_rs1_idx = x_rs1_addr;
  wire [4:0] x_rs2_idx = x_rs2_addr;
  wire [4:0] x_rd_idx  = x_rd;

  wire d_is_regreg = (d_inst[6:0] == OpcodeRegReg);
  wire d_is_div_instr = d_is_regreg && (d_inst[31:25] == 7'd1) && (d_inst[14:12] >= 3'b100);
  
  reg stall_div_data;
  wire div_result_ready;
  wire struct_hazard_div_wb;
  reg div_busy_before_wb;
  wire stall_div_indep;
  wire stall_wb; 
  wire stall_load;
  
  // Divider Pipeline Latches
  reg [4:0]          div_p_rd       [0:7];
  reg                div_p_valid    [0:7];
  reg                div_p_rem      [0:7];
  reg                div_p_regwrite [0:7];
  reg                div_p_quot_inv [0:7];
  reg                div_p_rem_inv  [0:7];
  reg [`REG_SIZE:0]  div_p_pc       [0:7];
  reg [`INST_SIZE:0] div_p_inst     [0:7];

  reg [31:0]         div_p_special_res [0:7];
  reg                div_p_is_special  [0:7];
  // DIV Writeback Latch
  reg                div_w_valid;
  reg [4:0]          div_w_rd;
  reg [`REG_SIZE:0]  div_w_data;

  wire [31:0] w_final_data = (w_result_src == 0) ? w_alu_result :
                             (w_result_src == 1) ? w_mem_data : w_pc + 4;

  // ==============================================================================
  // !!! HAZARD CONTROL LOGIC !!!
  // ==============================================================================

  // 1. Load-Use Hazard
  assign stall_load = x_valid && x_is_load && (x_rd != 0) && 
                      ((d_rs1_idx == x_rd) || (d_rs2_idx == x_rd));
  integer h;
  reg rs1_conflict;
  reg rs2_conflict;

  always @(*) begin
    rs1_conflict = 1'b0;
    rs2_conflict = 1'b0;
    if (d_valid) begin
        
        // --- CHECK RS1 ---
        // Check Execute
        if (x_valid && x_is_m_extension && x_funct3[2] && (x_rd != 0) && (x_rd == d_rs1_idx))
            rs1_conflict = 1'b1;
        
        // Check Divider Loop
        for (h = 0; h < `DIVIDER_STAGES-2; h = h + 1) begin
            if (div_p_valid[h] && div_p_regwrite[h] && (div_p_rd[h] != 0) && (div_p_rd[h] == d_rs1_idx))
                rs1_conflict = 1'b1;
        end

        // --- CHECK RS2 ---
        // Check Execute
        if (x_valid && x_is_m_extension && x_funct3[2] && (x_rd != 0) && (x_rd == d_rs2_idx))
            rs2_conflict = 1'b1;

        // Check Divider Loop
        for (h = 0; h < `DIVIDER_STAGES-2; h = h + 1) begin
            if (div_p_valid[h] && div_p_regwrite[h] && (div_p_rd[h] != 0) && (div_p_rd[h] == d_rs2_idx))
                rs2_conflict = 1'b1;
        end
    end
end

  // Final Result
  assign stall_div_data = rs1_conflict || rs2_conflict;

// ==============================================================================
// Structural Hazard: Divider result ready at Stage 7.
// ==============================================================================
  assign div_result_ready = div_p_valid[7];
  assign struct_hazard_div_wb = div_result_ready && m_valid && m_reg_write;
  
  integer dh;
  always @(*) begin
    div_busy_before_wb = 1'b0;
    for (dh = 0; dh < `DIVIDER_STAGES-3; dh = dh + 1) begin
      if (div_p_valid[dh] && div_p_regwrite[dh] && (div_p_rd[dh] != 5'd0))
        div_busy_before_wb = 1'b1;
    end
    if (x_valid && x_is_m_extension && x_funct3[2] && (x_rd != 5'd0))
      div_busy_before_wb = 1'b1;
  end

  
  assign stall_div_indep = d_valid && !d_is_div_instr && !stall_div_data && div_busy_before_wb;

  assign stall_wb = stall_load || stall_div_data || stall_div_indep || struct_hazard_div_wb;

  wire pc_en = !stall_wb;
  wire fd_en = !stall_wb;
  wire xm_en = !struct_hazard_div_wb; 

  reg x_branch_taken; 
  
  wire dx_clear = stall_load || stall_div_data || stall_div_indep || 
                  (x_valid && (x_is_branch && x_branch_taken)) || 
                  (x_valid && (x_is_jal || x_is_jalr));

  wire id_ex_enable = !struct_hazard_div_wb; 

  // ==================================================================
  // TESTBENCH ALIASES (Legacy Mapping)
  // ==================================================================
  wire stall_load_use = stall_load; 
  wire stall_div_hazard = stall_div_data;
  wire div_write_we; 
  assign div_write_we = div_w_valid; 

  // Forward declarations for Fetch
  wire branch_taken;
  wire [31:0] branch_target;
  
  // ==============================================================================
  // FETCH STAGE (IF)
  // ==============================================================================
  reg  [`REG_SIZE:0] f_pc_current;
  wire [`REG_SIZE:0] f_pc = f_pc_current;
  wire [`REG_SIZE:0] f_inst = inst_from_imem;
  wire [`REG_SIZE:0] f_pc_next;

  assign f_pc_next = (branch_taken) ? branch_target : (f_pc_current + 4);
  assign pc_to_imem = f_pc_current;

  always @(posedge clk) begin
    if (rst) f_pc_current <= 32'd0;
    else if (pc_en) f_pc_current <= f_pc_next;
  end

  always @(posedge clk) begin
    if (rst) begin
      d_pc <= 0; d_inst <= 0; d_valid <= 0;
    end else if (branch_taken) begin
      d_pc <= 0; d_inst <= 0; d_valid <= 0;
    end else if (fd_en) begin
      d_pc <= f_pc_current;
      d_inst <= f_inst;
      d_valid <= (f_inst != 0);
    end
  end

  // ==============================================================================
  // DECODE STAGE (ID)
  // ==============================================================================
  wire [6:0] d_funct7 = d_inst[31:25];
  wire [2:0] d_funct3 = d_inst[14:12];
  wire [6:0] d_opcode = d_inst[6:0];
  
  reg [31:0] d_imm;
  always @(*) begin
    case (d_opcode)
      OpcodeLoad, OpcodeRegImm, OpcodeJalr: d_imm = {{20{d_inst[31]}}, d_inst[31:20]};
      OpcodeStore: d_imm = {{20{d_inst[31]}}, d_inst[31:25], d_inst[11:7]};
      OpcodeBranch: d_imm = {{20{d_inst[31]}}, d_inst[7], d_inst[30:25], d_inst[11:8], 1'b0};
      OpcodeJal: d_imm = {{12{d_inst[31]}}, d_inst[19:12], d_inst[20], d_inst[30:21], 1'b0};
      OpcodeLui, OpcodeAuipc: d_imm = {d_inst[31:12], 12'b0};
      default: d_imm = 32'b0;
    endcase
  end

  reg d_reg_write, d_mem_write, d_mem_read, d_alu_src_b;
  reg d_is_branch, d_is_jal, d_is_jalr;
  reg [1:0] d_result_src;
  reg [3:0] d_alu_op;

  wire d_is_m_ext = (d_opcode == OpcodeRegReg) && (d_funct7 == 7'b0000001);

  always @(*) begin
    d_reg_write = 0; d_result_src = 0; d_mem_write = 0; 
    d_mem_read = 0; d_alu_src_b = 0; d_is_branch = 0; 
    d_is_jal = 0; d_is_jalr = 0; d_alu_op = 0;

    case (d_opcode)
      OpcodeLoad: begin d_reg_write = 1; d_result_src = 1; d_mem_read = 1; d_alu_src_b = 1; end
      OpcodeStore: begin d_mem_write = 1; d_alu_src_b = 1; end
      OpcodeRegImm: begin
        d_reg_write = 1; d_alu_src_b = 1;
        case (d_funct3)
          3'b000: d_alu_op = 0; 3'b010: d_alu_op = 8; 3'b011: d_alu_op = 9;
          3'b100: d_alu_op = 4; 3'b110: d_alu_op = 3; 3'b111: d_alu_op = 2;
          3'b001: d_alu_op = 5; 3'b101: d_alu_op = (d_funct7[5]) ? 7 : 6;
          default: d_alu_op = 0;
        endcase
      end
      OpcodeRegReg: begin
        d_reg_write = 1; d_alu_src_b = 0;
        if (d_is_m_ext) begin
          if (d_funct3[2] == 1'b0) d_alu_op = 11; // MUL
          else begin d_alu_op = 0; d_reg_write = 0; end // DIV
        end else begin
            case (d_funct3)
              3'b000: d_alu_op = (d_funct7[5]) ? 1 : 0;
              3'b001: d_alu_op = 5; 3'b010: d_alu_op = 8; 3'b011: d_alu_op = 9;
              3'b100: d_alu_op = 4; 3'b101: d_alu_op = (d_funct7[5]) ? 7 : 6;
              3'b110: d_alu_op = 3; 3'b111: d_alu_op = 2;
              default: d_alu_op = 0;
            endcase
        end
      end
      OpcodeLui: begin d_reg_write = 1; d_alu_src_b = 1; d_alu_op = 10; end
      OpcodeAuipc: begin d_reg_write = 1; d_alu_src_b = 1; end 
      OpcodeJal: begin d_reg_write = 1; d_result_src = 2; d_is_jal = 1; d_alu_src_b = 1; end
      OpcodeJalr: begin d_reg_write = 1; d_result_src = 2; d_is_jalr = 1; d_alu_src_b = 1; end
      OpcodeBranch: begin d_is_branch = 1; d_alu_op = 1; end 
      default: begin end
    endcase
  end

  // Register File
  wire [31:0] rs1_data_raw, rs2_data_raw;
  wire [4:0] rf_write_addr = w_rd;
  wire [31:0] rf_write_data = w_final_data;
  wire rf_write_en = w_reg_write;
  
  RegFile rf (
    .clk(clk), .rst(rst), 
    .we(rf_write_en), .rd(rf_write_addr), .rd_data(rf_write_data),
    .div_we(1'b0), .div_rd(5'b0), .div_rd_data(32'b0), // Unused
    .rs1(d_inst[19:15]), .rs1_data(rs1_data_raw), 
    .rs2(d_inst[24:20]), .rs2_data(rs2_data_raw)
  );

  // D->X Pipeline Register
  always @(posedge clk) begin
    if (rst) begin 
      x_pc <= 0; x_inst <= 0; x_valid <= 0;
      x_rs1_data <= 0; x_rs2_data <= 0; x_imm <= 0;
      x_rd <= 0; x_rs1_addr <= 0; x_rs2_addr <= 0;
      x_alu_op <= 0; x_alu_src_b <= 0;
      x_result_src <= 0; x_funct3 <= 0; x_opcode <= 0; x_funct7 <= 0;
      x_is_branch <= 0; x_is_jal <= 0; x_is_jalr <= 0;
      x_is_load <= 0; x_is_store <= 0; x_mem_read <= 0; x_mem_write <= 0; x_reg_write <= 0;
      x_is_m_extension <= 0;
    end else if (id_ex_enable) begin
      if (dx_clear) begin
         x_pc <= 0; x_inst <= 0; x_valid <= 0;
         x_is_branch <= 0; x_is_jal <= 0; x_is_jalr <= 0; 
         x_is_load <= 0; x_is_store <= 0; x_mem_read <= 0; x_mem_write <= 0; x_reg_write <= 0;
      end else begin
         x_pc <= d_pc; x_inst <= d_inst; x_valid <= d_valid;
         x_rs1_data <= rs1_data_raw; x_rs2_data <= rs2_data_raw; 
         x_imm <= d_imm;
         x_rd <= d_rd_idx; x_rs1_addr <= d_inst[19:15]; x_rs2_addr <= d_inst[24:20];
         x_alu_op <= d_alu_op; x_alu_src_b <= d_alu_src_b;
         x_is_branch <= d_is_branch; x_is_jal <= d_is_jal; x_is_jalr <= d_is_jalr;
         x_is_load <= (d_opcode == OpcodeLoad); x_is_store <= (d_opcode == OpcodeStore);
         x_mem_read <= d_mem_read; x_mem_write <= d_mem_write; x_reg_write <= d_reg_write;
         x_result_src <= d_result_src; x_funct3 <= d_funct3; x_opcode <= d_opcode; x_funct7 <= d_funct7;
         x_is_m_extension <= d_is_m_ext;
      end
    end
  end

    // ==============================================================================
    // EXECUTE STAGE 
    // ==============================================================================
    reg [31:0] x_rs1_val, x_rs2_val; 
    wire [31:0] div_q_u, div_r_u; 

    // ============================================================
    // CONSTANTS & AUXILIARY SIGNALS
    // ============================================================
    
    // Define Selector States
    localparam SEL_REG_FILE = 3'd0; // Default: Get from register file (ID/EX)
    localparam SEL_DIV_7    = 3'd1; // Forward from Div Stage 7
    localparam SEL_DIV_W    = 3'd2; // Forward from Div Writeback
    localparam SEL_MEM      = 3'd3; // Forward from Memory Stage
    localparam SEL_WB       = 3'd4; // Forward from Writeback Stage

    // Selector Control Signals
    reg [2:0] rs1_sel;
    reg [2:0] rs2_sel;

    // --- Aux: Calculate Div value (Keep original logic) ---
    wire [31:0] div_q_u_final     = div_p_quot_inv[7] ? (~div_q_u + 32'd1) : div_q_u;
    wire [31:0] div_r_u_final     = div_p_rem_inv[7]  ? (~div_r_u + 32'd1) : div_r_u;
    wire [31:0] div_result_normal = div_p_rem[7]      ? div_r_u_final : div_q_u_final;
    
    wire [31:0] div_result_stage7 = div_p_is_special[7] ? 
                                    div_p_special_res[7] : 
                                    div_result_normal;

    // ============================================================
    // CONTROL LOGIC (CALCULATE SELECTOR)
    // ============================================================
    always @(*) begin
        // --- Calculate selector for RS1 ---
        // Priority from Top to Bottom (if - else if)
        if (div_p_valid[7] && div_p_regwrite[7] && (div_p_rd[7] != 0) && (div_p_rd[7] == x_rs1_addr)) 
            rs1_sel = SEL_DIV_7;
        else if (div_w_valid && (div_w_rd != 0) && (div_w_rd == x_rs1_addr))
            rs1_sel = SEL_DIV_W;
        else if (m_valid && m_reg_write && (m_rd != 0) && !m_mem_read && (m_rd == x_rs1_addr))
            rs1_sel = SEL_MEM;
        else if (w_valid && w_reg_write && (w_rd != 0) && (w_rd == x_rs1_addr))
            rs1_sel = SEL_WB;
        else 
            rs1_sel = SEL_REG_FILE;

        // --- Calculate selector for RS2 ---
        if (div_p_valid[7] && div_p_regwrite[7] && (div_p_rd[7] != 0) && (div_p_rd[7] == x_rs2_addr)) 
            rs2_sel = SEL_DIV_7;
        else if (div_w_valid && (div_w_rd != 0) && (div_w_rd == x_rs2_addr))
            rs2_sel = SEL_DIV_W;
        else if (m_valid && m_reg_write && (m_rd != 0) && !m_mem_read && (m_rd == x_rs2_addr))
            rs2_sel = SEL_MEM;
        else if (w_valid && w_reg_write && (w_rd != 0) && (w_rd == x_rs2_addr))
            rs2_sel = SEL_WB;
        else 
            rs2_sel = SEL_REG_FILE;
    end

    // ============================================================
    // DATA LOGIC (SWITCH CASE)
    // Task: Perform data switching based on Selector
    // ============================================================
    always @(*) begin
        // --- MUX for RS1 ---
        case (rs1_sel)
            SEL_DIV_7: x_rs1_val = div_result_stage7;
            SEL_DIV_W: x_rs1_val = div_w_data;
            SEL_MEM:   x_rs1_val = m_alu_result;
            SEL_WB:    x_rs1_val = w_final_data;
            default:   x_rs1_val = x_rs1_data; // SEL_REG_FILE
        endcase

        // --- MUX for RS2 ---
        case (rs2_sel)
            SEL_DIV_7: x_rs2_val = div_result_stage7;
            SEL_DIV_W: x_rs2_val = div_w_data;
            SEL_MEM:   x_rs2_val = m_alu_result;
            SEL_WB:    x_rs2_val = w_final_data;
            default:   x_rs2_val = x_rs2_data; // SEL_REG_FILE
        endcase
    end


  // ==============================================================================
  // ALU Operation
  // ==============================================================================
  wire [31:0] src_a = (x_opcode == OpcodeAuipc) ? x_pc : x_rs1_val; 
  wire [31:0] src_b = (x_alu_src_b) ? x_imm : x_rs2_val;
  wire alu_sub = (x_alu_op == 1) || x_is_branch;
  wire [31:0] cla_sum;
  cla adder_inst (.a(src_a), .b(alu_sub ? ~src_b : src_b), .cin(alu_sub), .sum(cla_sum));

  reg [31:0] logic_res;
  always @(*) begin
    case (x_alu_op)
      2: logic_res = src_a & src_b;
      3: logic_res = src_a | src_b;
      4: logic_res = src_a ^ src_b;
      5: logic_res = src_a << src_b[4:0];
      6: logic_res = src_a >> src_b[4:0];
      7: logic_res = $signed(src_a) >>> src_b[4:0];
      8: logic_res = ($signed(src_a) < $signed(src_b)) ? 32'd1 : 32'd0;
      9: logic_res = (src_a < src_b) ? 32'd1 : 32'd0;
      10: logic_res = src_b; 
      default: logic_res = 0;
    endcase
  end

  // --- Multiplier ---
  // Initialize Latch
  reg [31:0] mul_result;
  reg [63:0] mul_full;
  always @(*) begin
      mul_full = 64'd0; mul_result = 32'd0;
      case (x_funct3)
          3'b000: mul_result = src_a * src_b; 
          3'b001: begin mul_full = $signed(src_a) * $signed(src_b); mul_result = mul_full[63:32]; end
          3'b010: begin mul_full = $signed(src_a) * $signed({1'b0, src_b}); mul_result = mul_full[63:32]; end
          3'b011: begin mul_full = {32'b0, src_a} * {32'b0, src_b}; mul_result = mul_full[63:32]; end
          default: begin mul_full = 0; mul_result = 0; end
      endcase
  end

  // --- Divider Input Logic ---
  wire x_div_signed = !x_funct3[0];
  wire [31:0] rs1_abs = (x_div_signed && x_rs1_val[31]) ? -x_rs1_val : x_rs1_val;
  wire [31:0] rs2_abs = (x_div_signed && x_rs2_val[31]) ? -x_rs2_val : x_rs2_val;
  
  // Special Cases
  wire div_by_zero = (x_rs2_val == 0);
  wire div_ovf     = x_div_signed && (x_rs1_val == 32'h80000000) && (x_rs2_val == 32'hFFFFFFFF);
  wire special     = div_by_zero || div_ovf;

  DividerUnsignedPipelined u_divu (
      .clk(clk), .rst(rst), .stall(1'b0), 
      .i_dividend(x_is_m_extension && x_funct3[2] && !special ? rs1_abs : 0), 
      .i_divisor(x_is_m_extension && x_funct3[2] && !special ? rs2_abs : 1),
      .o_remainder(div_r_u), .o_quotient(div_q_u)
  );

  // --- Divider Shadow Pipeline Logic ---
  wire div_start = x_valid && x_is_m_extension && x_funct3[2] && !struct_hazard_div_wb;

  integer k;
  always @(posedge clk) begin
      if (rst) begin
          for(k=0; k<8; k=k+1) begin
             div_p_valid[k] <= 0;
             div_p_rd[k] <= 0; div_p_rem[k] <= 0;
             div_p_regwrite[k] <= 0; div_p_quot_inv[k] <= 0; div_p_rem_inv[k] <= 0;
             div_p_pc[k] <= 0; div_p_inst[k] <= 0;
             div_p_special_res[k] <= 0; div_p_is_special[k] <= 0;
          end
      end else begin
          for(k=7; k>0; k=k-1) begin
              div_p_valid[k] <= div_p_valid[k-1];
              div_p_rd[k] <= div_p_rd[k-1];
              div_p_rem[k] <= div_p_rem[k-1];
              div_p_regwrite[k] <= div_p_regwrite[k-1];
              div_p_quot_inv[k] <= div_p_quot_inv[k-1];
              div_p_rem_inv[k] <= div_p_rem_inv[k-1];
              div_p_pc[k] <= div_p_pc[k-1];
              div_p_inst[k] <= div_p_inst[k-1];
              div_p_special_res[k] <= div_p_special_res[k-1];
              div_p_is_special[k] <= div_p_is_special[k-1];
          end
          if (div_start) begin
              div_p_valid[0] <= 1;
              div_p_rd[0] <= x_rd;
              div_p_rem[0] <= (x_funct3[1]); 
              div_p_regwrite[0] <= 1;
              div_p_quot_inv[0] <= (x_div_signed && !div_by_zero) ? (x_rs1_val[31] ^ x_rs2_val[31]) : 0;
              div_p_rem_inv[0]  <= (x_div_signed) ? x_rs1_val[31] : 0;
              div_p_pc[0] <= x_pc;
              div_p_inst[0] <= x_inst;
              div_p_is_special[0] <= special; 

              if (div_by_zero) begin
                  if (x_funct3[1]) div_p_special_res[0] <= x_rs1_val;    
                  else             div_p_special_res[0] <= 32'hFFFFFFFF; 
              end else if (div_ovf) begin
                  if (x_funct3[1]) div_p_special_res[0] <= 32'd0;        
                  else             div_p_special_res[0] <= 32'h80000000; 
              end else begin
                  div_p_special_res[0] <= 0;
              end

          end else begin
              div_p_valid[0] <= 0;
              div_p_rd[0] <= 0; div_p_regwrite[0] <= 0;
              div_p_is_special[0] <= 0; // Clear
          end
      end
  end

  // --- Branch Logic ---
  wire zero = (cla_sum == 0);
  wire less_signed = ($signed(src_a) < $signed(src_b));
  wire less_unsigned = (src_a < src_b);

  reg branch_cond;
  always @(*) begin
    branch_cond = 0;
    case (x_funct3)
      3'b000: branch_cond = zero; 
      3'b001: branch_cond = !zero;
      3'b100: branch_cond = less_signed;
      3'b101: branch_cond = !less_signed;
      3'b110: branch_cond = less_unsigned;
      3'b111: branch_cond = !less_unsigned;
      default: branch_cond = 0; 
    endcase
  end
  
  always @(*) begin
    x_branch_taken = 0;
    if (x_is_branch && branch_cond) x_branch_taken = 1;
  end

  reg [31:0] x_branch_target;
  wire [31:0] target_base = (x_is_jalr) ? src_a : x_pc; 
  always @(*) begin
    x_branch_target = (x_is_jalr) ? ((src_a + x_imm) & ~32'd1) : (x_pc + x_imm);
  end

  wire x_is_mul = x_is_m_extension && (x_funct3[2] == 1'b0);
  
  wire [31:0] final_alu_res = x_is_mul ? mul_result :
                              ((x_alu_op == 0 || x_alu_op == 1) ? cla_sum : logic_res);

  // Connecting EX back to Fetch (Global wires)
  assign branch_taken = x_valid && (x_branch_taken || x_is_jal || x_is_jalr);
  assign branch_target = x_branch_target;

  // EX/MEM Register Update
  always @(posedge clk) begin
    if (rst) begin
      m_pc <= 0; m_inst <= 0; m_valid <= 0; m_rd <= 0;
      m_reg_write <= 0; m_mem_read <= 0; m_mem_write <= 0;
      m_alu_result <= 0; m_write_data <= 0; m_result_src <= 0; m_funct3 <= 0;
    end else if (xm_en) begin
      if (x_valid && x_is_m_extension && x_funct3[2]) begin 
         m_pc <= x_pc; m_inst <= x_inst; m_valid <= 0;
         m_reg_write <= 0; m_mem_read <= 0; m_mem_write <= 0;
      end else begin
         m_pc <= x_pc; m_inst <= x_inst; m_valid <= x_valid;
         m_rd <= x_rd; m_reg_write <= x_reg_write;
         m_mem_read <= x_mem_read; m_mem_write <= x_mem_write;
         m_alu_result <= final_alu_res;
         m_write_data <= x_rs2_val; 
         m_result_src <= x_result_src; m_funct3 <= x_funct3;
      end
    end
  end

  // ==============================================================================
  // MEMORY STAGE (MEM)
  // ==============================================================================
  always @(*) begin
    addr_to_dmem = m_alu_result;
    store_data_to_dmem = 0;
    store_we_to_dmem = 0;
    if (m_mem_write) begin
       case (m_funct3)
         3'b000: begin // SB
            store_data_to_dmem = m_write_data << (m_alu_result[1:0] * 8);
            store_we_to_dmem = 4'b0001 << m_alu_result[1:0]; 
         end
         3'b001: begin // SH
            store_data_to_dmem = m_write_data << (m_alu_result[1:0] * 8);
            store_we_to_dmem = 4'b0011 << m_alu_result[1:0];
         end
         3'b010: begin // SW
            store_data_to_dmem = m_write_data;
            store_we_to_dmem = 4'b1111;
         end
         default: begin
            store_data_to_dmem = 0;
            store_we_to_dmem = 0;
         end
       endcase
    end
  end
  
  reg [31:0] load_val_shifted;
  always @(*) load_val_shifted = load_data_from_dmem >> (m_alu_result[1:0] * 8);
  always @(posedge clk) begin
    if (rst) begin
      w_pc <= 0; w_inst <= 0; w_valid <= 0; w_rd <= 0; w_reg_write <= 0;
      w_alu_result <= 0; w_mem_data <= 0; w_result_src <= 0;
      
      div_w_valid <= 0; div_w_rd <= 0; div_w_data <= 0; 
    end 
    else if (div_result_ready) begin
        w_valid <= 1;
        w_reg_write <= div_p_regwrite[7];
        w_rd <= div_p_rd[7];
        w_alu_result <= div_result_stage7; 
        w_result_src <= 0; 
        w_mem_data <= 0;
        w_pc <= div_p_pc[7];
        w_inst <= div_p_inst[7];
        div_w_valid <= div_p_regwrite[7];
        div_w_rd <= div_p_rd[7];
        div_w_data <= div_result_stage7;
    end
    else if (struct_hazard_div_wb) begin
    end
    else begin
        w_pc <= m_pc; w_inst <= m_inst; w_valid <= m_valid;
        w_rd <= m_rd; w_reg_write <= m_reg_write;
        w_alu_result <= m_alu_result; w_result_src <= m_result_src;

        case (m_funct3)
          3'b000: w_mem_data <= {{24{load_val_shifted[7]}}, load_val_shifted[7:0]};
          3'b001: w_mem_data <= {{16{load_val_shifted[15]}}, load_val_shifted[15:0]};
          3'b010: w_mem_data <= load_val_shifted;
          3'b100: w_mem_data <= {24'b0, load_val_shifted[7:0]};
          3'b101: w_mem_data <= {16'b0, load_val_shifted[15:0]};
          default: w_mem_data <= load_val_shifted;
        endcase
        if (div_w_valid && m_valid && m_reg_write && (m_rd == div_w_rd)) begin
           div_w_valid <= 0;
        end
    end
  end

  always @(*) begin
    if (w_inst[6:0] == OpcodeEnviron && w_inst[31:7] == 0) halt = 1;
    else halt = 0;
  end

  always @(*) begin
    if (w_inst != 0 && !rst && w_valid) begin
        trace_writeback_pc   = w_pc;
        trace_writeback_inst = w_inst;
    end else begin
        trace_writeback_pc   = 0;
        trace_writeback_inst = 0;
    end
  end

endmodule

// ==============================================================================
// MISSING MODULES (Memory & Processor Top-Level)
// ==============================================================================

module MemorySingleCycle #(
    parameter NUM_WORDS = 8192
) (
    input                    rst,
    input                    clk,
    input      [`REG_SIZE:0] pc_to_imem,
    output reg [`REG_SIZE:0] inst_from_imem,
    input      [`REG_SIZE:0] addr_to_dmem,
    output reg [`REG_SIZE:0] load_data_from_dmem,
    input      [`REG_SIZE:0] store_data_to_dmem,
    input      [        3:0] store_we_to_dmem
);
  reg [`REG_SIZE:0] mem_array[0:NUM_WORDS-1];

  initial begin
    $readmemh("File.hex", mem_array);
  end

  localparam AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam AddrLsb = 2;

  always @(negedge clk) begin
    if (rst) begin
        inst_from_imem <= 0;
    end else begin
        inst_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
    end
  end

  always @(negedge clk) begin
    if (store_we_to_dmem[0]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0]   <= store_data_to_dmem[7:0];
    if (store_we_to_dmem[1]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8]  <= store_data_to_dmem[15:8];
    if (store_we_to_dmem[2]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
    if (store_we_to_dmem[3]) mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
    
    load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
  end
endmodule

module Processor (
    input                 clk,
    input                 rst,
    output                halt,
    output [ `REG_SIZE:0] trace_writeback_pc,
    output [`INST_SIZE:0] trace_writeback_inst
);
  wire [`INST_SIZE:0] inst_from_imem;
  wire [ `REG_SIZE:0] pc_to_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [         3:0] mem_data_we;
  wire [(8*32)-1:0] test_case; 

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) memory (
    .rst                 (rst),
    .clk                 (clk),
    .pc_to_imem          (pc_to_imem),
    .inst_from_imem      (inst_from_imem),
    .addr_to_dmem        (mem_data_addr),
    .load_data_from_dmem (mem_data_loaded_value),
    .store_data_to_dmem  (mem_data_to_write),
    .store_we_to_dmem    (mem_data_we)
  );

  DatapathPipelined datapath (
    .clk                  (clk),
    .rst                  (rst),
    .pc_to_imem           (pc_to_imem),
    .inst_from_imem       (inst_from_imem),
    .addr_to_dmem         (mem_data_addr),
    .store_data_to_dmem   (mem_data_to_write),
    .store_we_to_dmem     (mem_data_we),
    .load_data_from_dmem  (mem_data_loaded_value),
    .halt                 (halt),
    .trace_writeback_pc   (trace_writeback_pc),
    .trace_writeback_inst (trace_writeback_inst)
  );
endmodule














