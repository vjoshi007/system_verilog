// AXI-5 Slave Interface
// Synthesizable SystemVerilog-2017
// Accepts and responds to AXI write and read transactions
// Includes configurable memory for testing

module axi5_slave import axi5_pkg::*; #(
  parameter int AXI_ADDR_WIDTH = AXI_ADDR_WIDTH,
  parameter int AXI_DATA_WIDTH = AXI_DATA_WIDTH,
  parameter int AXI_ID_WIDTH = AXI_ID_WIDTH,
  parameter int MEM_SIZE = 32'h1000  // Memory size in bytes
)(
  input  logic                                clk,
  input  logic                                rst_n,
  
  // ===== WRITE ADDRESS CHANNEL (AW) =====
  input  logic [AXI_ADDR_WIDTH-1:0]          awaddr,
  input  logic [AXI_LEN_WIDTH-1:0]           awlen,
  input  logic [AXI_SIZE_WIDTH-1:0]          awsize,
  input  axi_burst_type_e                    awburst,
  input  logic [AXI_ID_WIDTH-1:0]            awid,
  input  logic [AXI_LOCK_WIDTH-1:0]          awlock,
  input  logic [AXI_CACHE_WIDTH-1:0]         awcache,
  input  logic [AXI_PROT_WIDTH-1:0]          awprot,
  input  logic [AXI_QOS_WIDTH-1:0]           awqos,
  input  logic [AXI_REGION_WIDTH-1:0]        awregion,
  input  logic [AXI_USER_WIDTH-1:0]          awuser,
  input  logic                               awvalid,
  output logic                               awready,
  
  // ===== WRITE DATA CHANNEL (W) =====
  input  logic [AXI_DATA_WIDTH-1:0]          wdata,
  input  logic [(AXI_DATA_WIDTH/8)-1:0]      wstrb,
  input  logic                               wlast,
  input  logic [AXI_USER_WIDTH-1:0]          wuser,
  input  logic                               wvalid,
  output logic                               wready,
  
  // ===== WRITE RESPONSE CHANNEL (B) =====
  output logic [AXI_RESP_WIDTH-1:0]          bresp,
  output logic [AXI_ID_WIDTH-1:0]            bid,
  output logic [AXI_USER_WIDTH-1:0]          buser,
  output logic                               bvalid,
  input  logic                               bready,
  
  // ===== READ ADDRESS CHANNEL (AR) =====
  input  logic [AXI_ADDR_WIDTH-1:0]          araddr,
  input  logic [AXI_LEN_WIDTH-1:0]           arlen,
  input  logic [AXI_SIZE_WIDTH-1:0]          arsize,
  input  axi_burst_type_e                    arburst,
  input  logic [AXI_ID_WIDTH-1:0]            arid,
  input  logic [AXI_LOCK_WIDTH-1:0]          arlock,
  input  logic [AXI_CACHE_WIDTH-1:0]         arcache,
  input  logic [AXI_PROT_WIDTH-1:0]          arprot,
  input  logic [AXI_QOS_WIDTH-1:0]           arqos,
  input  logic [AXI_REGION_WIDTH-1:0]        arregion,
  input  logic [AXI_USER_WIDTH-1:0]          aruser,
  input  logic                               arvalid,
  output logic                               arready,
  
  // ===== READ DATA CHANNEL (R) =====
  output logic [AXI_DATA_WIDTH-1:0]          rdata,
  output logic [AXI_RESP_WIDTH-1:0]          rresp,
  output logic [AXI_ID_WIDTH-1:0]            rid,
  output logic                               rlast,
  output logic [AXI_USER_WIDTH-1:0]          ruser,
  output logic                               rvalid,
  input  logic                               rready
);

  localparam int STRB_WIDTH = AXI_DATA_WIDTH / 8;
  localparam int MEM_DEPTH = MEM_SIZE / (AXI_DATA_WIDTH / 8);

  //========== MEMORY ARRAY ==========
  
  logic [AXI_DATA_WIDTH-1:0] memory [MEM_DEPTH];
  
  initial begin
    for (int i = 0; i < MEM_DEPTH; i++) begin
      memory[i] = {(AXI_DATA_WIDTH/32){32'hDEADBEEF}};
    end
  end
  
  //========== WRITE ADDRESS HANDLING ==========
  
  typedef struct packed {
    logic [AXI_ADDR_WIDTH-1:0] awaddr;
    logic [AXI_LEN_WIDTH-1:0]  awlen;
    logic [AXI_SIZE_WIDTH-1:0] awsize;
    axi_burst_type_e awburst;
    logic [AXI_ID_WIDTH-1:0]   awid;
  } aw_info_t;
  
  localparam int AW_QUEUE_DEPTH = 16;
  aw_info_t aw_queue[AW_QUEUE_DEPTH];
  logic [3:0] aw_write_ptr, aw_read_ptr, aw_count;
  
  logic aw_queue_full = (aw_count == AW_QUEUE_DEPTH);
  logic aw_queue_empty = (aw_count == 0);
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_write_ptr <= 4'h0;
      aw_read_ptr <= 4'h0;
      aw_count <= 4'h0;
    end else begin
      if (awvalid && awready) begin
        aw_queue[aw_write_ptr] <= {awaddr, awlen, awsize, awburst, awid};
        aw_write_ptr <= aw_write_ptr + 1;
        aw_count <= aw_count + 1;
      end
      if (wvalid && wready && wlast) begin
        aw_read_ptr <= aw_read_ptr + 1;
        aw_count <= aw_count - 1;
      end
    end
  end
  
  assign awready = !aw_queue_full;
  
  //========== WRITE DATA HANDLING ==========
  
  logic [AXI_DATA_WIDTH-1:0] w_data_q;
  logic [STRB_WIDTH-1:0] w_strb_q;
  logic w_beat_count_q;
  logic [AXI_ADDR_WIDTH-1:0] w_addr;
  logic [7:0] w_expected_beats;
  
  assign w_expected_beats = aw_queue[aw_read_ptr].awlen + 1;
  
  // Address calculation (simplified, INCR mode only)
  assign w_addr = aw_queue[aw_read_ptr].awaddr + 
                  (w_beat_count_q << aw_queue[aw_read_ptr].awsize);
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_beat_count_q <= 8'h0;
      w_data_q <= '0;
      w_strb_q <= '0;
    end else begin
      if (wvalid && wready) begin
        w_data_q <= wdata;
        w_strb_q <= wstrb;
        if (wlast) begin
          w_beat_count_q <= 8'h0;
        end else begin
          w_beat_count_q <= w_beat_count_q + 1;
        end
      end
    end
  end
  
  // Memory write logic
  always_ff @(posedge clk) begin
    if (wvalid && wready) begin
      for (int i = 0; i < STRB_WIDTH; i++) begin
        if (wstrb[i]) begin
          memory[w_addr[AXI_ADDR_WIDTH-1:$clog2(STRB_WIDTH)]][8*i +: 8] 
            <= wdata[8*i +: 8];
        end
      end
    end
  end
  
  assign wready = !aw_queue_empty;
  
  //========== WRITE RESPONSE GENERATION ==========
  
  typedef struct packed {
    logic [AXI_ID_WIDTH-1:0] bid;
    logic [1:0] bresp;
  } b_info_t;
  
  localparam int B_QUEUE_DEPTH = 16;
  b_info_t b_queue[B_QUEUE_DEPTH];
  logic [3:0] b_write_ptr, b_read_ptr, b_count;
  logic b_queue_full = (b_count == B_QUEUE_DEPTH);
  logic b_queue_empty = (b_count == 0);
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      b_write_ptr <= 4'h0;
      b_read_ptr <= 4'h0;
      b_count <= 4'h0;
    end else begin
      if (wvalid && wready && wlast) begin
        b_queue[b_write_ptr] <= {aw_queue[aw_read_ptr].awid, RESP_OKAY};
        b_write_ptr <= b_write_ptr + 1;
        b_count <= b_count + 1;
      end
      if (bvalid && bready) begin
        b_read_ptr <= b_read_ptr + 1;
        b_count <= b_count - 1;
      end
    end
  end
  
  assign bvalid = !b_queue_empty;
  assign bid = b_queue[b_read_ptr].bid;
  assign bresp = b_queue[b_read_ptr].bresp;
  assign buser = 8'b0;
  
  //========== READ ADDRESS HANDLING ==========
  
  typedef struct packed {
    logic [AXI_ADDR_WIDTH-1:0] araddr;
    logic [AXI_LEN_WIDTH-1:0]  arlen;
    logic [AXI_SIZE_WIDTH-1:0] arsize;
    axi_burst_type_e arburst;
    logic [AXI_ID_WIDTH-1:0]   arid;
  } ar_info_t;
  
  localparam int AR_QUEUE_DEPTH = 16;
  ar_info_t ar_queue[AR_QUEUE_DEPTH];
  logic [3:0] ar_write_ptr, ar_read_ptr, ar_count;
  
  logic ar_queue_full = (ar_count == AR_QUEUE_DEPTH);
  logic ar_queue_empty = (ar_count == 0);
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ar_write_ptr <= 4'h0;
      ar_read_ptr <= 4'h0;
      ar_count <= 4'h0;
    end else begin
      if (arvalid && arready) begin
        ar_queue[ar_write_ptr] <= {araddr, arlen, arsize, arburst, arid};
        ar_write_ptr <= ar_write_ptr + 1;
        ar_count <= ar_count + 1;
      end
      if (rvalid && rready && rlast) begin
        ar_read_ptr <= ar_read_ptr + 1;
        ar_count <= ar_count - 1;
      end
    end
  end
  
  assign arready = !ar_queue_full;
  
  //========== READ DATA GENERATION ==========
  
  logic [7:0] r_beat_count_q;
  logic [AXI_ADDR_WIDTH-1:0] r_addr;
  
  assign r_addr = ar_queue[ar_read_ptr].araddr + 
                  (r_beat_count_q << ar_queue[ar_read_ptr].arsize);
  
  assign rdata = memory[r_addr[AXI_ADDR_WIDTH-1:$clog2(STRB_WIDTH)]];
  assign rid = ar_queue[ar_read_ptr].arid;
  assign rresp = RESP_OKAY;
  assign rlast = (r_beat_count_q == ar_queue[ar_read_ptr].arlen);
  assign ruser = 8'b0;
  assign rvalid = !ar_queue_empty;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_beat_count_q <= 8'h0;
    end else begin
      if (rvalid && rready) begin
        if (rlast) begin
          r_beat_count_q <= 8'h0;
        end else begin
          r_beat_count_q <= r_beat_count_q + 1;
        end
      end
    end
  end

endmodule : axi5_slave

