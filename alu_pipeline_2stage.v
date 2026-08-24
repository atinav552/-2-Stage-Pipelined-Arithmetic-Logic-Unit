// ============================================================
// 2-Stage Pipelined ALU with Data Forwarding (Standard Verilog)
// ============================================================

module alu_pipeline_2stage #(
  parameter DATA_WIDTH = 32,
  parameter REG_ADDR_WIDTH = 5
)(
  input  wire                      clk,
  input  wire                      rst_n,
  input  wire                      flush,
  input  wire                      input_valid,
  input  wire [3:0]                opcode,
  input  wire [REG_ADDR_WIDTH-1:0] src_a_reg,
  input  wire [REG_ADDR_WIDTH-1:0] src_b_reg,
  input  wire [DATA_WIDTH-1:0]     src_a_value,
  input  wire [DATA_WIDTH-1:0]     src_b_value,
  input  wire [REG_ADDR_WIDTH-1:0] dest_reg,
  
  output reg                       wb_valid,
  output reg  [DATA_WIDTH-1:0]     wb_result,
  output reg  [REG_ADDR_WIDTH-1:0] wb_dest
);

  // =====================================================================
  // Stage 1: Execute (EX) Pipeline Registers
  // =====================================================================
  reg                      ex_valid;
  reg [3:0]                ex_opcode;
  reg [REG_ADDR_WIDTH-1:0] ex_src_a_reg;
  reg [REG_ADDR_WIDTH-1:0] ex_src_b_reg;
  reg [DATA_WIDTH-1:0]     ex_src_a_value;
  reg [DATA_WIDTH-1:0]     ex_src_b_value;
  reg [REG_ADDR_WIDTH-1:0] ex_dest_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex_valid       <= 1'b0;
      ex_opcode      <= 4'd0;
      ex_src_a_reg   <= 0;
      ex_src_b_reg   <= 0;
      ex_src_a_value <= 0;
      ex_src_b_value <= 0;
      ex_dest_reg    <= 0;
    end else if (flush) begin
      ex_valid       <= 1'b0; // Invalidate operation on flush
    end else begin
      // Latch all incoming signals into the EX stage
      ex_valid       <= input_valid;
      ex_opcode      <= opcode;
      ex_src_a_reg   <= src_a_reg;
      ex_src_b_reg   <= src_b_reg;
      ex_src_a_value <= src_a_value;
      ex_src_b_value <= src_b_value;
      ex_dest_reg    <= dest_reg;
    end
  end

  // =====================================================================
  // Forwarding Network & Combinational ALU Logic
  // =====================================================================
  reg [DATA_WIDTH-1:0] fwd_mux_a;
  reg [DATA_WIDTH-1:0] fwd_mux_b;
  reg [DATA_WIDTH-1:0] alu_out;
  
  always @(*) begin
    // Forward to Source A if the instruction retiring in WB is writing to Source A
    if (wb_valid && (wb_dest != 0) && (ex_src_a_reg == wb_dest)) begin
      fwd_mux_a = wb_result;
    end else begin
      fwd_mux_a = ex_src_a_value;
    end
    
    // Forward to Source B if the instruction retiring in WB is writing to Source B
    if (wb_valid && (wb_dest != 0) && (ex_src_b_reg == wb_dest)) begin
      fwd_mux_b = wb_result;
    end else begin
      fwd_mux_b = ex_src_b_value;
    end
  end

  always @(*) begin
    case (ex_opcode)
      4'd0: alu_out = fwd_mux_a + fwd_mux_b; // ADD
      4'd1: alu_out = fwd_mux_a - fwd_mux_b; // SUB
      4'd2: alu_out = fwd_mux_a & fwd_mux_b; // AND
      4'd3: alu_out = fwd_mux_a | fwd_mux_b; // OR
      4'd4: alu_out = fwd_mux_a ^ fwd_mux_b; // XOR
      default: alu_out = 0;
    endcase
  end

  // =====================================================================
  // Stage 2: Write-Back (WB) Pipeline Registers
  // =====================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wb_valid  <= 1'b0;
      wb_result <= 0;
      wb_dest   <= 0;
    end else if (flush) begin
      wb_valid  <= 1'b0; // Invalidate operation on flush
    end else begin
      // Latch the computed ALU result into the WB stage
      wb_valid  <= ex_valid;
      wb_result <= alu_out;
      wb_dest   <= ex_dest_reg;
    end
  end

endmodule