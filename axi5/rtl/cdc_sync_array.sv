// CDC Multi-bit Gray Code Synchronizer
// For synchronizing multiple bits across clock domains
// Uses Gray code to ensure only 1 bit changes per transition

module cdc_sync_array #(
  parameter int WIDTH = 8,     // Data width
  parameter int STAGES = 3     // Number of sync stages (>=3 for 5nm)
)(
  input  logic clk_src,
  input  logic clk_dst,
  input  logic [WIDTH-1:0] data_in,
  output logic [WIDTH-1:0] data_out
);

  // Gray code conversion
  logic [WIDTH-1:0] data_gray_src;
  logic [WIDTH-1:0] data_gray_sync;
  logic [WIDTH-1:0] data_binary_dst;
  
  // Gray code encoder
  assign data_gray_src = data_in ^ (data_in >> 1);
  
  // Synchronizer flip-flop chain in destination clock domain
  logic [WIDTH-1:0] sync_ff[STAGES];
  
  // Source domain: Convert to Gray
  // (data_gray_src is combinatorial from input)
  
  // First flip-flop in destination domain (metastability absorption)
  always_ff @(posedge clk_dst) begin
    sync_ff[0] <= data_gray_src;
  end
  
  // Additional synchronization stages
  generate
    for (genvar i = 1; i < STAGES; i++) begin : SYNC_STAGES
      always_ff @(posedge clk_dst) begin
        sync_ff[i] <= sync_ff[i-1];
      end
    end
  endgenerate
  
  // Gray code decoder
  always_comb begin
    data_binary_dst = 0;
    for (int i = WIDTH-1; i >= 0; i--) begin
      data_binary_dst[i] = data_gray_sync[i] ^ data_binary_dst[i+1];
    end
  end
  
  assign data_gray_sync = sync_ff[STAGES-1];
  assign data_out = data_binary_dst;

endmodule : cdc_sync_array

