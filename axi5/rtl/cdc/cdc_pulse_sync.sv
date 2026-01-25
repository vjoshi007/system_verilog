// CDC Single-Pulse Synchronizer
// For synchronizing a single clock pulse across clock domains
// Extends pulse width and detects edge in destination domain

module cdc_pulse_sync #(
  parameter int STAGES = 3  // Synchronizer stages (>=3 for 5nm)
)(
  input  logic clk_src,
  input  logic clk_dst,
  input  logic pulse_in,
  output logic pulse_out
);

  // Extended pulse in source domain (stays high for multiple cycles)
  logic pulse_extended;
  logic pulse_ff;
  logic pulse_clear;
  
  // Synchronizer chain
  logic [STAGES-1:0] sync_ff;
  
  // Extend pulse in source clock domain
  always_ff @(posedge clk_src) begin
    if (pulse_in) begin
      pulse_extended <= 1'b1;
    end else if (pulse_clear) begin
      pulse_extended <= 1'b0;
    end
  end
  
  // Synchronize extended pulse to destination domain
  always_ff @(posedge clk_dst) begin
    sync_ff[0] <= pulse_extended;
    for (int i = 1; i < STAGES; i++) begin
      sync_ff[i] <= sync_ff[i-1];
    end
  end
  
  // Detect rising edge in destination domain
  always_ff @(posedge clk_dst) begin
    pulse_ff <= sync_ff[STAGES-1];
  end
  
  assign pulse_out = sync_ff[STAGES-1] && !pulse_ff;  // Rising edge detect
  
  // Clear pulse in source domain when synchronized
  always_ff @(posedge clk_src) begin
    pulse_clear <= sync_ff[STAGES-1];
  end

endmodule : cdc_pulse_sync

