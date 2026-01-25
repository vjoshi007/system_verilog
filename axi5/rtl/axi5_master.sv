// AXI-5 Master Interface
// Synthesizable SystemVerilog-2017
// Generates AXI write and read transactions

module axi5_master import axi5_pkg::*; #(
  parameter int AXI_ADDR_WIDTH = AXI_ADDR_WIDTH,
  parameter int AXI_DATA_WIDTH = AXI_DATA_WIDTH,
  parameter int AXI_ID_WIDTH = AXI_ID_WIDTH
)(
  input  logic                                clk,
  input  logic                                rst_n,
  
  // ===== WRITE ADDRESS CHANNEL (AW) =====
  output logic [AXI_ADDR_WIDTH-1:0]          awaddr,
  output logic [AXI_LEN_WIDTH-1:0]           awlen,
  output logic [AXI_SIZE_WIDTH-1:0]          awsize,
  output axi_burst_type_e                    awburst,
  output logic [AXI_ID_WIDTH-1:0]            awid,
  output logic [AXI_LOCK_WIDTH-1:0]          awlock,
  output logic [AXI_CACHE_WIDTH-1:0]         awcache,
  output logic [AXI_PROT_WIDTH-1:0]          awprot,
  output logic [AXI_QOS_WIDTH-1:0]           awqos,
  output logic [AXI_REGION_WIDTH-1:0]        awregion,
  output logic [AXI_USER_WIDTH-1:0]          awuser,
  output logic                               awvalid,
  input  logic                               awready,
  
  // ===== WRITE DATA CHANNEL (W) =====
  output logic [AXI_DATA_WIDTH-1:0]          wdata,
  output logic [(AXI_DATA_WIDTH/8)-1:0]      wstrb,
  output logic                               wlast,
  output logic [AXI_USER_WIDTH-1:0]          wuser,
  output logic                               wvalid,
  input  logic                               wready,
  
  // ===== WRITE RESPONSE CHANNEL (B) =====
  input  logic [AXI_RESP_WIDTH-1:0]          bresp,
  input  logic [AXI_ID_WIDTH-1:0]            bid,
  input  logic [AXI_USER_WIDTH-1:0]          buser,
  input  logic                               bvalid,
  output logic                               bready,
  
  // ===== READ ADDRESS CHANNEL (AR) =====
  output logic [AXI_ADDR_WIDTH-1:0]          araddr,
  output logic [AXI_LEN_WIDTH-1:0]           arlen,
  output logic [AXI_SIZE_WIDTH-1:0]          arsize,
  output axi_burst_type_e                    arburst,
  output logic [AXI_ID_WIDTH-1:0]            arid,
  output logic [AXI_LOCK_WIDTH-1:0]          arlock,
  output logic [AXI_CACHE_WIDTH-1:0]         arcache,
  output logic [AXI_PROT_WIDTH-1:0]          arprot,
  output logic [AXI_QOS_WIDTH-1:0]           arqos,
  output logic [AXI_REGION_WIDTH-1:0]        arregion,
  output logic [AXI_USER_WIDTH-1:0]          aruser,
  output logic                               arvalid,
  input  logic                               arready,
  
  // ===== READ DATA CHANNEL (R) =====
  input  logic [AXI_DATA_WIDTH-1:0]          rdata,
  input  logic [AXI_RESP_WIDTH-1:0]          rresp,
  input  logic [AXI_ID_WIDTH-1:0]            rid,
  input  logic                               rlast,
  input  logic [AXI_USER_WIDTH-1:0]          ruser,
  input  logic                               rvalid,
  output logic                               rready
);

  localparam int STRB_WIDTH = AXI_DATA_WIDTH / 8;

  //========== WRITE PATH STATE MACHINES ==========
  
  // Write address state machine
  typedef enum logic [1:0] {
    AW_IDLE = 2'b00,
    AW_WAIT_READY = 2'b01,
    AW_TRANSFER = 2'b10
  } aw_state_e;
  
  aw_state_e aw_state, aw_state_nxt;
  logic [AXI_ADDR_WIDTH-1:0] aw_addr_q, aw_addr_nxt;
  logic [AXI_LEN_WIDTH-1:0] aw_len_q, aw_len_nxt;
  logic [AXI_SIZE_WIDTH-1:0] aw_size_q, aw_size_nxt;
  axi_burst_type_e aw_burst_q, aw_burst_nxt;
  logic [AXI_ID_WIDTH-1:0] aw_id_q, aw_id_nxt;
  logic aw_has_txn, aw_has_txn_nxt;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_state <= AW_IDLE;
      aw_addr_q <= '0;
      aw_len_q <= '0;
      aw_size_q <= '0;
      aw_burst_q <= BURST_INCR;
      aw_id_q <= '0;
      aw_has_txn <= 1'b0;
    end else begin
      aw_state <= aw_state_nxt;
      aw_addr_q <= aw_addr_nxt;
      aw_len_q <= aw_len_nxt;
      aw_size_q <= aw_size_nxt;
      aw_burst_q <= aw_burst_nxt;
      aw_id_q <= aw_id_nxt;
      aw_has_txn <= aw_has_txn_nxt;
    end
  end
  
  always_comb begin
    aw_state_nxt = aw_state;
    aw_addr_nxt = aw_addr_q;
    aw_len_nxt = aw_len_q;
    aw_size_nxt = aw_size_q;
    aw_burst_nxt = aw_burst_q;
    aw_id_nxt = aw_id_q;
    aw_has_txn_nxt = aw_has_txn;
    awvalid = 1'b0;
    
    case (aw_state)
      AW_IDLE: begin
        if (aw_has_txn) begin
          aw_state_nxt = AW_WAIT_READY;
        end
      end
      
      AW_WAIT_READY: begin
        awvalid = 1'b1;
        if (awready) begin
          aw_state_nxt = AW_IDLE;
          aw_has_txn_nxt = 1'b0;
        end
      end
      
      default: aw_state_nxt = AW_IDLE;
    endcase
  end
  
  // Assign AW channel outputs
  assign awaddr = aw_addr_q;
  assign awlen = aw_len_q;
  assign awsize = aw_size_q;
  assign awburst = aw_burst_q;
  assign awid = aw_id_q;
  assign awlock = 1'b0;
  assign awcache = 4'b0011;  // Bufferable, modifiable
  assign awprot = 3'b000;    // Unprivileged, nonsecure, data
  assign awqos = 4'b0;
  assign awregion = 4'b0;
  assign awuser = 8'b0;
  
  //========== WRITE DATA STATE MACHINE ==========
  
  typedef enum logic [1:0] {
    W_IDLE = 2'b00,
    W_BUSY = 2'b01,
    W_WAIT_LAST = 2'b10
  } w_state_e;
  
  w_state_e w_state, w_state_nxt;
  logic [AXI_DATA_WIDTH-1:0] w_data_q, w_data_nxt;
  logic [STRB_WIDTH-1:0] w_strb_q, w_strb_nxt;
  logic [7:0] w_beat_count_q, w_beat_count_nxt;
  logic [7:0] w_beat_total_q, w_beat_total_nxt;
  logic w_has_txn, w_has_txn_nxt;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_state <= W_IDLE;
      w_data_q <= '0;
      w_strb_q <= '0;
      w_beat_count_q <= '0;
      w_beat_total_q <= '0;
      w_has_txn <= 1'b0;
    end else begin
      w_state <= w_state_nxt;
      w_data_q <= w_data_nxt;
      w_strb_q <= w_strb_nxt;
      w_beat_count_q <= w_beat_count_nxt;
      w_beat_total_q <= w_beat_total_nxt;
      w_has_txn <= w_has_txn_nxt;
    end
  end
  
  always_comb begin
    w_state_nxt = w_state;
    w_data_nxt = w_data_q;
    w_strb_nxt = w_strb_q;
    w_beat_count_nxt = w_beat_count_q;
    w_beat_total_nxt = w_beat_total_q;
    w_has_txn_nxt = w_has_txn;
    wvalid = 1'b0;
    wlast = 1'b0;
    
    case (w_state)
      W_IDLE: begin
        if (w_has_txn) begin
          w_state_nxt = W_BUSY;
          w_beat_count_nxt = 8'h00;
        end
      end
      
      W_BUSY: begin
        wvalid = 1'b1;
        if (wready) begin
          w_beat_count_nxt = w_beat_count_q + 1;
          if (w_beat_count_q == w_beat_total_q) begin
            wlast = 1'b1;
            w_state_nxt = W_IDLE;
            w_has_txn_nxt = 1'b0;
          end else begin
            w_data_nxt = {w_data_q[AXI_DATA_WIDTH-2:0], w_data_q[AXI_DATA_WIDTH-1]};
          end
        end
      end
      
      default: w_state_nxt = W_IDLE;
    endcase
  end
  
  assign wdata = w_data_q;
  assign wstrb = w_strb_q;
  assign wuser = 8'b0;
  
  //========== WRITE RESPONSE HANDLER ==========
  
  always_comb begin
    bready = 1'b1;  // Always ready for responses
  end
  
  //========== READ ADDRESS STATE MACHINE ==========
  
  typedef enum logic [1:0] {
    AR_IDLE = 2'b00,
    AR_WAIT_READY = 2'b01
  } ar_state_e;
  
  ar_state_e ar_state, ar_state_nxt;
  logic [AXI_ADDR_WIDTH-1:0] ar_addr_q, ar_addr_nxt;
  logic [AXI_LEN_WIDTH-1:0] ar_len_q, ar_len_nxt;
  logic [AXI_SIZE_WIDTH-1:0] ar_size_q, ar_size_nxt;
  axi_burst_type_e ar_burst_q, ar_burst_nxt;
  logic [AXI_ID_WIDTH-1:0] ar_id_q, ar_id_nxt;
  logic ar_has_txn, ar_has_txn_nxt;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ar_state <= AR_IDLE;
      ar_addr_q <= '0;
      ar_len_q <= '0;
      ar_size_q <= '0;
      ar_burst_q <= BURST_INCR;
      ar_id_q <= '0;
      ar_has_txn <= 1'b0;
    end else begin
      ar_state <= ar_state_nxt;
      ar_addr_q <= ar_addr_nxt;
      ar_len_q <= ar_len_nxt;
      ar_size_q <= ar_size_nxt;
      ar_burst_q <= ar_burst_nxt;
      ar_id_q <= ar_id_nxt;
      ar_has_txn <= ar_has_txn_nxt;
    end
  end
  
  always_comb begin
    ar_state_nxt = ar_state;
    ar_addr_nxt = ar_addr_q;
    ar_len_nxt = ar_len_q;
    ar_size_nxt = ar_size_q;
    ar_burst_nxt = ar_burst_q;
    ar_id_nxt = ar_id_q;
    ar_has_txn_nxt = ar_has_txn;
    arvalid = 1'b0;
    
    case (ar_state)
      AR_IDLE: begin
        if (ar_has_txn) begin
          ar_state_nxt = AR_WAIT_READY;
        end
      end
      
      AR_WAIT_READY: begin
        arvalid = 1'b1;
        if (arready) begin
          ar_state_nxt = AR_IDLE;
          ar_has_txn_nxt = 1'b0;
        end
      end
      
      default: ar_state_nxt = AR_IDLE;
    endcase
  end
  
  assign araddr = ar_addr_q;
  assign arlen = ar_len_q;
  assign arsize = ar_size_q;
  assign arburst = ar_burst_q;
  assign arid = ar_id_q;
  assign arlock = 1'b0;
  assign arcache = 4'b0011;
  assign arprot = 3'b000;
  assign arqos = 4'b0;
  assign arregion = 4'b0;
  assign aruser = 8'b0;
  
  //========== READ DATA HANDLER ==========
  
  logic [7:0] r_beat_count_q, r_beat_count_nxt;
  logic [AXI_LEN_WIDTH-1:0] r_expected_len_q, r_expected_len_nxt;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_beat_count_q <= '0;
      r_expected_len_q <= '0;
    end else begin
      r_beat_count_q <= r_beat_count_nxt;
      r_expected_len_q <= r_expected_len_nxt;
    end
  end
  
  always_comb begin
    rready = 1'b1;  // Always ready for data
    r_beat_count_nxt = r_beat_count_q;
    r_expected_len_nxt = r_expected_len_q;
    
    if (arvalid && arready) begin
      r_expected_len_nxt = arlen;
      r_beat_count_nxt = 8'h00;
    end else if (rvalid && rready) begin
      r_beat_count_nxt = r_beat_count_q + 1;
      if (rlast) begin
        r_beat_count_nxt = 8'h00;
      end
    end
  end

endmodule : axi5_master

