// CDC Gray Code Counter
// For FIFO pointer synchronization across clock domains
// Generates Gray-coded pointer that can safely cross domains

module cdc_gray_counter #(
  parameter int WIDTH = 9,      // Pointer width (one extra bit for empty/full)
  parameter int STAGES = 3      // Synchronizer stages
)(
  input  logic               clk_src,
  input  logic               clk_dst,
  input  logic               rst_n,
  
  // Counter in source clock domain
  input  logic               incr_src,     // Increment request
  output logic [WIDTH-1:0]   ptr_src,      // Binary counter
  output logic [WIDTH-1:0]   ptr_gray_src, // Gray code output
  
  // Synchronized pointer in destination domain
  input  logic               incr_dst,
  output logic [WIDTH-1:0]   ptr_dst,      // Binary counter
  output logic [WIDTH-1:0]   ptr_gray_dst, // Gray code output
  
  // Synchronized pointers for comparison
  output logic [WIDTH-1:0]   ptr_src_sync_in_dst,  // Source ptr in dst domain
  output logic [WIDTH-1:0]   ptr_dst_sync_in_src   // Dest ptr in src domain
);

  // Counters in each domain
  logic [WIDTH-1:0] ptr_src_nxt, ptr_dst_nxt;
  logic [WIDTH-1:0] ptr_gray_src_nxt, ptr_gray_dst_nxt;
  
  // Gray code conversions
  function logic [WIDTH-1:0] binary_to_gray(logic [WIDTH-1:0] binary);
    return binary ^ (binary >> 1);
  endfunction : binary_to_gray
  
  function logic [WIDTH-1:0] gray_to_binary(logic [WIDTH-1:0] gray);
    logic [WIDTH-1:0] binary = 0;
    for (int i = WIDTH-1; i >= 0; i--) begin
      binary[i] = gray[i] ^ binary[i+1];
    end
    return binary;
  endfunction : gray_to_binary
  
  // ========== SOURCE CLOCK DOMAIN ==========
  
  // Counter update in source domain
  always_comb begin
    if (incr_src) begin
      ptr_src_nxt = ptr_src + 1;
    end else begin
      ptr_src_nxt = ptr_src;
    end
  end
  
  always_ff @(posedge clk_src or negedge rst_n) begin
    if (!rst_n) begin
      ptr_src <= '0;
    end else begin
      ptr_src <= ptr_src_nxt;
    end
  end
  
  assign ptr_gray_src = binary_to_gray(ptr_src);
  
  // Synchronize destination pointer to source domain
  logic [WIDTH-1:0] ptr_dst_gray_sync_ff[STAGES];
  
  always_ff @(posedge clk_src or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < STAGES; i++) begin
        ptr_dst_gray_sync_ff[i] <= '0;
      end
    end else begin
      ptr_dst_gray_sync_ff[0] <= ptr_gray_dst;
      for (int i = 1; i < STAGES; i++) begin
        ptr_dst_gray_sync_ff[i] <= ptr_dst_gray_sync_ff[i-1];
      end
    end
  end
  
  assign ptr_dst_sync_in_src = gray_to_binary(ptr_dst_gray_sync_ff[STAGES-1]);
  
  // ========== DESTINATION CLOCK DOMAIN ==========
  
  // Counter update in destination domain
  always_comb begin
    if (incr_dst) begin
      ptr_dst_nxt = ptr_dst + 1;
    end else begin
      ptr_dst_nxt = ptr_dst;
    end
  end
  
  always_ff @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) begin
      ptr_dst <= '0;
    end else begin
      ptr_dst <= ptr_dst_nxt;
    end
  end
  
  assign ptr_gray_dst = binary_to_gray(ptr_dst);
  
  // Synchronize source pointer to destination domain
  logic [WIDTH-1:0] ptr_src_gray_sync_ff[STAGES];
  
  always_ff @(posedge clk_dst or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < STAGES; i++) begin
        ptr_src_gray_sync_ff[i] <= '0;
      end
    end else begin
      ptr_src_gray_sync_ff[0] <= ptr_gray_src;
      for (int i = 1; i < STAGES; i++) begin
        ptr_src_gray_sync_ff[i] <= ptr_src_gray_sync_ff[i-1];
      end
    end
  end
  
  assign ptr_src_sync_in_dst = gray_to_binary(ptr_src_gray_sync_ff[STAGES-1]);

endmodule : cdc_gray_counter

