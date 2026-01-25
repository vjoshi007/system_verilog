// AXI-5 Protocol Package Definition
// Synthesizable SystemVerilog-2017 (IEEE 1800-2017)
// All types, parameters, and utility functions for AXI-5 IP communication

package axi5_pkg;

  //========== PARAMETER DEFINITIONS ==========
  parameter int unsigned AXI_ID_WIDTH      = 12;     // ID field width
  parameter int unsigned AXI_ADDR_WIDTH    = 64;     // Address width
  parameter int unsigned AXI_DATA_WIDTH    = 512;    // Data width (bits)
  parameter int unsigned AXI_STRB_WIDTH    = AXI_DATA_WIDTH / 8;  // Strobes
  parameter int unsigned AXI_LEN_WIDTH     = 8;      // Burst length (0-255)
  parameter int unsigned AXI_SIZE_WIDTH    = 3;      // Burst size
  parameter int unsigned AXI_BURST_WIDTH   = 2;      // Burst type
  parameter int unsigned AXI_RESP_WIDTH    = 2;      // Response code
  parameter int unsigned AXI_LOCK_WIDTH    = 1;      // Exclusive access
  parameter int unsigned AXI_CACHE_WIDTH   = 4;      // Cache policy
  parameter int unsigned AXI_PROT_WIDTH    = 3;      // Protection
  parameter int unsigned AXI_QOS_WIDTH     = 4;      // QoS
  parameter int unsigned AXI_REGION_WIDTH  = 4;      // Region
  parameter int unsigned AXI_USER_WIDTH    = 8;      // User sideband (configurable)

  // Derived widths
  parameter int unsigned AXI_BYTES_PER_BEAT = AXI_DATA_WIDTH / 8;

  //========== ENUM DEFINITIONS ==========

  // Burst type encoding
  typedef enum logic [1:0] {
    BURST_FIXED = 2'b00,
    BURST_INCR  = 2'b01,
    BURST_WRAP  = 2'b10,
    BURST_RSVD  = 2'b11
  } axi_burst_type_e;

  // Response codes
  typedef enum logic [1:0] {
    RESP_OKAY   = 2'b00,   // Success
    RESP_EXOKAY = 2'b01,   // Exclusive success
    RESP_SLVERR = 2'b10,   // Slave error
    RESP_DECERR = 2'b11    // Decode error
  } axi_resp_e;

  // Transaction direction
  typedef enum logic {
    AXI_WRITE = 1'b0,
    AXI_READ  = 1'b1
  } axi_direction_e;

  // Protection type
  typedef enum logic [2:0] {
    PROT_UNPRIVILEGED_DATA = 3'b000,
    PROT_PRIVILEGED_DATA   = 3'b001,
    PROT_UNPRIVILEGED_INSTR = 3'b010,
    PROT_PRIVILEGED_INSTR   = 3'b011
  } axi_prot_e;

  //========== STRUCT DEFINITIONS ==========

  // Write Address Channel (AW)
  typedef struct packed {
    logic [AXI_ADDR_WIDTH-1:0]   awaddr;
    logic [AXI_LEN_WIDTH-1:0]    awlen;     // 0-255 (1-256 beats)
    logic [AXI_SIZE_WIDTH-1:0]   awsize;    // Bytes per beat (2^awsize)
    axi_burst_type_e             awburst;   // FIXED, INCR, WRAP
    logic [AXI_ID_WIDTH-1:0]     awid;
    logic [AXI_LOCK_WIDTH-1:0]   awlock;    // Exclusive access
    logic [AXI_CACHE_WIDTH-1:0]  awcache;
    logic [AXI_PROT_WIDTH-1:0]   awprot;
    logic [AXI_QOS_WIDTH-1:0]    awqos;
    logic [AXI_REGION_WIDTH-1:0] awregion;
    logic [AXI_USER_WIDTH-1:0]   awuser;
  } axi_aw_payload_t;

  // Write Data Channel (W)
  typedef struct packed {
    logic [AXI_DATA_WIDTH-1:0]   wdata;
    logic [AXI_STRB_WIDTH-1:0]   wstrb;     // Write strobes (1 per byte)
    logic                        wlast;     // Last beat of burst
    logic [AXI_USER_WIDTH-1:0]   wuser;
  } axi_w_payload_t;

  // Write Response Channel (B)
  typedef struct packed {
    axi_resp_e                   bresp;     // Response code
    logic [AXI_ID_WIDTH-1:0]     bid;       // Echo of awid
    logic [AXI_USER_WIDTH-1:0]   buser;
  } axi_b_payload_t;

  // Read Address Channel (AR)
  typedef struct packed {
    logic [AXI_ADDR_WIDTH-1:0]   araddr;
    logic [AXI_LEN_WIDTH-1:0]    arlen;
    logic [AXI_SIZE_WIDTH-1:0]   arsize;
    axi_burst_type_e             arburst;
    logic [AXI_ID_WIDTH-1:0]     arid;
    logic [AXI_LOCK_WIDTH-1:0]   arlock;
    logic [AXI_CACHE_WIDTH-1:0]  arcache;
    logic [AXI_PROT_WIDTH-1:0]   arprot;
    logic [AXI_QOS_WIDTH-1:0]    arqos;
    logic [AXI_REGION_WIDTH-1:0] arregion;
    logic [AXI_USER_WIDTH-1:0]   aruser;
  } axi_ar_payload_t;

  // Read Data Channel (R)
  typedef struct packed {
    logic [AXI_DATA_WIDTH-1:0]   rdata;
    axi_resp_e                   rresp;     // Response code
    logic [AXI_ID_WIDTH-1:0]     rid;       // Echo of arid
    logic                        rlast;     // Last beat of burst
    logic [AXI_USER_WIDTH-1:0]   ruser;
  } axi_r_payload_t;

  // Unified transaction for modeling
  typedef struct {
    logic [AXI_ID_WIDTH-1:0]     id;
    axi_direction_e              direction; // READ or WRITE
    logic [AXI_ADDR_WIDTH-1:0]   addr;
    logic [AXI_LEN_WIDTH-1:0]    len;       // 0-255
    logic [AXI_SIZE_WIDTH-1:0]   size;
    axi_burst_type_e             burst;
    logic [AXI_DATA_WIDTH-1:0]   data[];    // Array of beats
    logic [AXI_STRB_WIDTH-1:0]   strb[];
    axi_resp_e                   resp[];    // Response per beat
    logic                        exclusive; // awlock/arlock
    logic [AXI_CACHE_WIDTH-1:0]  cache;
    logic [AXI_PROT_WIDTH-1:0]   prot;
    logic [AXI_QOS_WIDTH-1:0]    qos;
    logic [AXI_REGION_WIDTH-1:0] region;
  } axi_transaction_t;

  //========== UTILITY FUNCTIONS ==========

  // Convert size encoding to byte count
  function automatic int unsigned get_byte_count(logic [2:0] size);
    return 1 << size;  // 2^size
  endfunction : get_byte_count

  // Calculate next address for INCR burst
  function automatic logic [AXI_ADDR_WIDTH-1:0] get_next_addr(
    logic [AXI_ADDR_WIDTH-1:0] addr,
    logic [2:0] size
  );
    logic [AXI_ADDR_WIDTH-1:0] increment = 1 << size;
    return addr + increment;
  endfunction : get_next_addr

  // Check if burst is aligned
  function automatic logic is_aligned(
    logic [AXI_ADDR_WIDTH-1:0] addr,
    logic [2:0] size
  );
    logic [AXI_ADDR_WIDTH-1:0] mask = (1 << size) - 1;
    return (addr & mask) == 0;
  endfunction : is_aligned

  // Calculate wrap boundary
  function automatic logic [AXI_ADDR_WIDTH-1:0] get_wrap_boundary(
    logic [AXI_ADDR_WIDTH-1:0] addr,
    logic [2:0] size,
    logic [7:0] len
  );
    logic [AXI_ADDR_WIDTH-1:0] wrap_size = (len + 1) << size;
    logic [AXI_ADDR_WIDTH-1:0] mask = ~(wrap_size - 1);
    return addr & mask;
  endfunction : get_wrap_boundary

  // Check for protocol errors
  function automatic logic is_protocol_error(
    logic [2:0] size,
    logic [AXI_ADDR_WIDTH-1:0] addr,
    axi_burst_type_e burst
  );
    logic error = 0;
    // Size too large (max 7 = 128 bytes)
    if (size > 7) error = 1;
    // Unaligned address
    if (!is_aligned(addr, size)) error = 1;
    // Invalid burst type
    if (burst == BURST_RSVD) error = 1;
    return error;
  endfunction : is_protocol_error

  // Convert between binary and Gray code
  function automatic logic [7:0] binary_to_gray(logic [7:0] binary);
    return binary ^ (binary >> 1);
  endfunction : binary_to_gray

  function automatic logic [7:0] gray_to_binary(logic [7:0] gray);
    logic [7:0] binary = 0;
    for (int i = 7; i >= 0; i--) begin
      binary[i] = gray[i] ^ binary[i+1];
    end
    return binary;
  endfunction : gray_to_binary

  // Parameterized Gray code functions
  function automatic logic [8:0] binary_to_gray_w9(logic [8:0] binary);
    return binary ^ (binary >> 1);
  endfunction : binary_to_gray_w9

  function automatic logic [8:0] gray_to_binary_w9(logic [8:0] gray);
    logic [8:0] binary = 0;
    for (int i = 8; i >= 0; i--) begin
      binary[i] = gray[i] ^ binary[i+1];
    end
    return binary;
  endfunction : gray_to_binary_w9

endpackage : axi5_pkg

