module alu_tb;

  reg        clk;
  reg        rst_n;
  reg        flush;
  reg        input_valid;
  reg [3:0]  opcode;
  reg [4:0]  src_a_reg;
  reg [4:0]  src_b_reg;
  reg [4:0]  dest_reg;
  reg [31:0] src_a_value;
  reg [31:0] src_b_value;
  
  wire        wb_valid;
  wire [31:0] wb_result;
  wire [4:0]  wb_dest;
  
  integer p, f;

  initial clk = 0;
  always #5 clk = ~clk;

  // Instantiate the ALU
  alu_pipeline_2stage #(
    .DATA_WIDTH(32), 
    .REG_ADDR_WIDTH(5)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .input_valid(input_valid),
    .opcode(opcode),
    .src_a_reg(src_a_reg),
    .src_b_reg(src_b_reg),
    .src_a_value(src_a_value),
    .src_b_value(src_b_value),
    .dest_reg(dest_reg),
    .wb_valid(wb_valid),
    .wb_result(wb_result),
    .wb_dest(wb_dest)
  );

  // Standard Verilog tasks
  task issue_inst;
    input [3:0]  op;
    input [4:0]  sa_reg;
    input [4:0]  sb_reg;
    input [31:0] sa_val;
    input [31:0] sb_val;
    input [4:0]  dst;
    begin
      input_valid  = 1;
      opcode       = op;
      src_a_reg    = sa_reg;
      src_b_reg    = sb_reg;
      src_a_value  = sa_val;
      src_b_value  = sb_val;
      dest_reg     = dst;
      @(posedge clk);
      #1;
    end
  endtask

  task insert_bubble;
    begin
      input_valid = 0;
      @(posedge clk);
      #1;
    end
  endtask

  initial begin
    p = 0; 
    f = 0;
    rst_n       = 0;
    flush       = 0;
    input_valid = 0;
    opcode      = 0;
    src_a_reg   = 0;
    src_b_reg   = 0;
    src_a_value = 0;
    src_b_value = 0;
    dest_reg    = 0;
    
    @(posedge clk); @(posedge clk);
    rst_n = 1; @(posedge clk); #1;

    // =========================================================
    // TC1 — Throughput with Independent Ops
    // =========================================================
    issue_inst(4'd0, 5'd2, 5'd3, 32'd1, 32'd2, 5'd1);   // R1 = 1+2 = 3
    issue_inst(4'd0, 5'd4, 5'd5, 32'd3, 32'd4, 5'd6);   // R6 = 3+4 = 7
    if (wb_valid && wb_result == 32'd3 && wb_dest == 5'd1) begin p=p+1; $display("PASS: TC1 result1: wb_result=%0d", wb_result); end
    else begin f=f+1; $display("FAIL: TC1 result1"); end

    issue_inst(4'd0, 5'd7, 5'd8, 32'd5, 32'd6, 5'd9);   // R9 = 5+6 = 11
    if (wb_valid && wb_result == 32'd7 && wb_dest == 5'd6) begin p=p+1; $display("PASS: TC1 result2: wb_result=%0d", wb_result); end
    else begin f=f+1; $display("FAIL: TC1 result2"); end

    insert_bubble;
    if (wb_valid && wb_result == 32'd11 && wb_dest == 5'd9) begin p=p+1; $display("PASS: TC1 result3: wb_result=%0d", wb_result); end
    else begin f=f+1; $display("FAIL: TC1 result3"); end

    // =========================================================
    // TC2 — RAW Forwarding (Producer -> Consumer Without Stall)
    // =========================================================
    issue_inst(4'd0, 5'd2, 5'd3, 32'd10, 32'd3, 5'd1);  // R1 = 10+3 = 13
    issue_inst(4'd0, 5'd1, 5'd5, 32'd0,  32'd5, 5'd4);  // R4 = fwd(R1)+5 = 13+5 = 18
    if (wb_valid && wb_result == 32'd13 && wb_dest == 5'd1) begin p=p+1; $display("PASS: TC2 producer: wb_result=%0d", wb_result); end
    else begin f=f+1; $display("FAIL: TC2 producer"); end

    insert_bubble;
    if (wb_valid && wb_result == 32'd18 && wb_dest == 5'd4) begin p=p+1; $display("PASS: TC2 forwarded consumer: wb_result=%0d", wb_result); end
    else begin f=f+1; $display("FAIL: TC2 forwarded consumer"); end

    // =========================================================
    // TC3 — Dependent Chain (R1 -> R2 -> R3)
    // =========================================================
    issue_inst(4'd0, 5'd2, 5'd3, 32'd4, 32'd6, 5'd1);   // R1 = 4+6 = 10
    issue_inst(4'd0, 5'd1, 5'd4, 32'd0, 32'd1, 5'd2);   // R2 = fwd(R1)+1 = 10+1 = 11
    if (!(wb_valid && wb_result == 32'd10 && wb_dest == 5'd1)) f=f+1;
    
    issue_inst(4'd0, 5'd2, 5'd5, 32'd0, 32'd2, 5'd3);   // R3 = fwd(R2)+2 = 11+2 = 13
    if (!(wb_valid && wb_result == 32'd11 && wb_dest == 5'd2)) f=f+1;
    
    insert_bubble;
    if (wb_valid && wb_result == 32'd13 && wb_dest == 5'd3) begin p=p+1; $display("PASS: TC3 dependency chain: wb_result=%0d", wb_result); end
    else begin f=f+1; $display("FAIL: TC3 dependency chain"); end

    // =========================================================
    // TC4 — Flush Kills In-Flight Result
    // =========================================================
    issue_inst(4'd0, 5'd2, 5'd3, 32'd100, 32'd200, 5'd7);
    flush = 1;
    insert_bubble;
    flush = 0;
    if (!wb_valid) begin p=p+1; $display("PASS: TC4 flush: wb_valid=0 squashed"); end
    else begin f=f+1; $display("FAIL: TC4 flush"); end

    $display("=== %0d passed %0d failed ===", p, f);
    $finish;
  end

  // Dumpfiles for GTKWave
  initial begin
    $dumpfile("alu_waves.vcd");
    $dumpvars(0, alu_tb);
  end

endmodule