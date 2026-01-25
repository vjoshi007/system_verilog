// CDC Handshake Synchronizer
// For safely transferring data blocks across clock domains
// Uses request-acknowledge handshake protocol

module cdc_handshake #(
  parameter int WIDTH = 32,    // Data width
  parameter int STAGES = 3     // Synchronizer stages (>=3)
)(
  input  logic clk_src,
  input  logic clk_dst,
  
  // Source side (clk_src)
  input  logic [WIDTH-1:0] data_src,
  input  logic             req_src,  // Request
  output logic             ack_src,  // Acknowledgement (from dest)
  
  // Destination side (clk_dst)
  output logic [WIDTH-1:0] data_dst,
  output logic             req_dst,  // Request (synchronized)
  input  logic             ack_dst   // Acknowledgement (from user)
);

  // Synchronizer stages for request
  logic [STAGES-1:0] req_sync_ff;
  logic req_sync;
  
  // Synchronizer stages for acknowledgement
  logic [STAGES-1:0] ack_sync_ff;
  logic ack_sync;
  
  // Latch data in source domain
  logic [WIDTH-1:0] data_latched;
  
  always_ff @(posedge clk_src) begin
    if (req_src && ack_sync) begin
      data_latched <= data_src;  // Update on handshake
    end
  end
  
  // Synchronize request to destination domain
  always_ff @(posedge clk_dst) begin
    req_sync_ff[0] <= req_src;
    for (int i = 1; i < STAGES; i++) begin
      req_sync_ff[i] <= req_sync_ff[i-1];
    end
  end
  assign req_sync = req_sync_ff[STAGES-1];
  
  // Synchronize acknowledgement to source domain
  always_ff @(posedge clk_src) begin
    ack_sync_ff[0] <= ack_dst;
    for (int i = 1; i < STAGES; i++) begin
      ack_sync_ff[i] <= ack_sync_ff[i-1];
    end
  end
  assign ack_sync = ack_sync_ff[STAGES-1];
  
  // Generate request-acknowledge signals
  assign ack_src = ack_sync;
  assign req_dst = req_sync;
  assign data_dst = data_latched;

endmodule : cdc_handshake

