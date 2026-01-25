# AXI-5 IP Communication: Quickstart Guide & Architecture

**Date**: 2026-01-25 | **Task**: T1.3 | **Status**: ✅ Complete

---

## 1. Architecture Overview

### 1.1 Module Hierarchy

```
axi5_system_top
├── axi5_master_0          # Master interface (writes/reads)
│   ├── aw_channel_fsm     # Write address state machine
│   ├── w_channel_fsm      # Write data pipeline
│   ├── b_channel_fsm      # Write response handler
│   ├── ar_channel_fsm     # Read address state machine
│   └── r_channel_fsm      # Read data pipeline
│
├── axi5_slave             # Slave interface (responds to requests)
│   ├── aw_queue           # Write address queue
│   ├── w_buffer           # Write data buffer
│   ├── memory_controller  # Memory operation handler
│   ├── b_response_queue   # Response queue
│   ├── ar_queue           # Read address queue
│   └── r_buffer           # Read data return buffer
│
├── axi5_interconnect      # Crossbar routing (optional, 4x4)
│   ├── aw_arbiter         # Round-robin for write addresses
│   ├── w_mux              # Write data routing
│   ├── b_mux              # Response routing
│   ├── ar_arbiter         # Round-robin for read addresses
│   └── r_mux              # Read data routing
│
├── cdc/                   # Clock domain crossing library
│   ├── cdc_sync_array.sv  # Gray code synchronizer
│   ├── cdc_pulse_sync.sv  # Pulse synchronizer
│   └── cdc_gray_counter   # FIFO pointer sync
│
├── protocol_checker/      # Runtime assertion monitors
│   ├── axi5_aw_checker    # AW channel protocol monitor
│   ├── axi5_w_checker     # W channel protocol monitor
│   ├── axi5_b_checker     # B channel protocol monitor
│   ├── axi5_ar_checker    # AR channel protocol monitor
│   └── axi5_r_checker     # R channel protocol monitor
│
└── clk_div                # Multi-clock generator (for testing)
    ├── clk_800MHz         # Primary clock
    ├── clk_400MHz         # Divided clocks
    ├── clk_200MHz
    ├── clk_100MHz
    └── clk_50MHz
```

### 1.2 Signal Flow: Write Transaction

```
Master Side:
  awaddr, awlen, awsize, awburst, awid --→ AW Channel
                                            ↓ (awvalid && awready)
  wdata, wstrb, wlast --→ W Channel ----→ Slave Memory
                        ↓ (wvalid && wready)
                                            ↓ (Process write)
  bready ←-- B Channel ←-- bresp, bid ←-- Slave Response
```

### 1.3 Signal Flow: Read Transaction

```
Master Side:
  araddr, arlen, arsize, arburst, arid --→ AR Channel
                                           ↓ (arvalid && arready)
  rready ←-- R Channel ←-- rdata, rlast ←-- Slave Data Return
```

---

## 2. Configuration & Parameters

### 2.1 Adjustable Parameters

Edit `rtl/axi5_pkg.sv` to configure:

```systemverilog
// Data width (512 is default; can be 64, 128, 256, 512, 1024)
parameter int unsigned AXI_DATA_WIDTH    = 512;

// ID width (12 = 4096 max outstanding, configurable 4-16)
parameter int unsigned AXI_ID_WIDTH      = 12;

// Address width (64-bit for large address spaces)
parameter int unsigned AXI_ADDR_WIDTH    = 64;

// User sideband width (8 bits, can be 0 if not needed)
parameter int unsigned AXI_USER_WIDTH    = 8;
```

### 2.2 Typical Configurations

**Small, Low-Power SoC:**
```systemverilog
AXI_DATA_WIDTH = 64;   // Smaller bus
AXI_ID_WIDTH = 4;      // Max 16 outstanding
AXI_ADDR_WIDTH = 32;   // 4GB address space
AXI_USER_WIDTH = 0;    // No sideband
```

**High-Performance System:**
```systemverilog
AXI_DATA_WIDTH = 512;  // Wide datapath
AXI_ID_WIDTH = 12;     // Max 4096 outstanding
AXI_ADDR_WIDTH = 64;   // 64-bit addressing
AXI_USER_WIDTH = 16;   // Extra sideband for QoS, etc.
```

**Multi-Clock Domain:**
```systemverilog
// Base clock: 800 MHz
// Crossing domains: Every 2^n divisor
CLKS = {clk_800, clk_400, clk_200, clk_100, clk_50};
CDC_LATENCY = 3-4 cycles per crossing
```

---

## 3. RTL Module Instantiation Templates

### 3.1 Single Master to Single Slave (No Interconnect)

```systemverilog
module axi5_simple_top (
  input clk,
  input rst_n,
  
  // Master ports (write)
  output logic [AXI_ADDR_WIDTH-1:0]   awaddr,
  output logic [AXI_LEN_WIDTH-1:0]    awlen,
  output logic [AXI_SIZE_WIDTH-1:0]   awsize,
  output logic [1:0]                  awburst,
  output logic [AXI_ID_WIDTH-1:0]     awid,
  output logic                        awvalid,
  input  logic                        awready,
  
  output logic [AXI_DATA_WIDTH-1:0]   wdata,
  output logic [AXI_STRB_WIDTH-1:0]   wstrb,
  output logic                        wlast,
  output logic                        wvalid,
  input  logic                        wready,
  
  input  logic [1:0]                  bresp,
  input  logic [AXI_ID_WIDTH-1:0]     bid,
  input  logic                        bvalid,
  output logic                        bready,
  
  // Master ports (read)
  output logic [AXI_ADDR_WIDTH-1:0]   araddr,
  output logic [AXI_LEN_WIDTH-1:0]    arlen,
  output logic [AXI_SIZE_WIDTH-1:0]   arsize,
  output logic [1:0]                  arburst,
  output logic [AXI_ID_WIDTH-1:0]     arid,
  output logic                        arvalid,
  input  logic                        arready,
  
  input  logic [AXI_DATA_WIDTH-1:0]   rdata,
  input  logic [1:0]                  rresp,
  input  logic [AXI_ID_WIDTH-1:0]     rid,
  input  logic                        rlast,
  input  logic                        rvalid,
  output logic                        rready
);

  // Master instance
  axi5_master #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH)
  ) master_i (
    .clk(clk),
    .rst_n(rst_n),
    
    // Write address channel
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awid(awid),
    .awvalid(awvalid),
    .awready(awready),
    
    // Write data channel
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    
    // Write response channel
    .bresp(bresp),
    .bid(bid),
    .bvalid(bvalid),
    .bready(bready),
    
    // Read address channel
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arid(arid),
    .arvalid(arvalid),
    .arready(arready),
    
    // Read data channel
    .rdata(rdata),
    .rresp(rresp),
    .rid(rid),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready)
  );
  
  // Slave instance (simplified example)
  axi5_slave #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .MEM_SIZE(32'h0000_1000)  // 4KB memory
  ) slave_i (
    .clk(clk),
    .rst_n(rst_n),
    
    // Connect to master
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awid(awid),
    .awvalid(awvalid),
    .awready(awready),
    
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),
    
    .bresp(bresp),
    .bid(bid),
    .bvalid(bvalid),
    .bready(bready),
    
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arid(arid),
    .arvalid(arvalid),
    .arready(arready),
    
    .rdata(rdata),
    .rresp(rresp),
    .rid(rid),
    .rlast(rlast),
    .rvalid(rvalid),
    .rready(rready)
  );

endmodule
```

### 3.2 Multi-Clock Domain with CDC

```systemverilog
module axi5_cdc_top (
  input clk_800_mst,       // Master clock domain
  input clk_400_slv,       // Slave clock domain
  input rst_n,
  
  // Master-side AXI signals (clk_800_mst)
  output axi5_pkg::axi_aw_payload_t  aw_mst,
  output logic                       awvalid_mst,
  input  logic                       awready_slv_sync,
  
  output axi5_pkg::axi_w_payload_t   w_mst,
  output logic                       wvalid_mst,
  input  logic                       wready_slv_sync,
  
  input  axi5_pkg::axi_b_payload_t   b_mst_sync,
  input  logic                       bvalid_mst,
  output logic                       bready_mst,
  
  // Slave-side AXI signals (clk_400_slv)
  input  axi5_pkg::axi_aw_payload_t  aw_slv,
  input  logic                       awvalid_mst_sync,
  output logic                       awready_slv,
  
  input  axi5_pkg::axi_w_payload_t   w_slv,
  input  logic                       wvalid_mst_sync,
  output logic                       wready_slv,
  
  output axi5_pkg::axi_b_payload_t   b_slv,
  output logic                       bvalid_slv,
  input  logic                       bready_mst_sync
);

  // Gray code synchronizers for address pointers
  logic [11:0] aw_ptr_mst, aw_ptr_slv;
  logic [11:0] aw_ptr_gray_mst, aw_ptr_gray_slv, aw_ptr_gray_sync;
  
  // AW channel Gray code pointer sync: mst → slv
  cdc_sync_array #(
    .WIDTH(12),
    .STAGES(3)
  ) aw_ptr_sync_i (
    .clk_src(clk_800_mst),
    .clk_dst(clk_400_slv),
    .data_in(axi5_pkg::binary_to_gray_w9(aw_ptr_mst)),
    .data_out(aw_ptr_gray_sync)
  );
  
  assign aw_ptr_slv = axi5_pkg::gray_to_binary_w9(aw_ptr_gray_sync);
  
  // W channel: Similar CDC for write data FIFO
  // B channel: Similar CDC for response routing
  // AR/R channels: Similar CDC for read path

endmodule
```

---

## 4. Verification Testbench Usage

### 4.1 Basic Testbench Instantiation

```systemverilog
`include "uvm_macros.svh"
import uvm_pkg::*;
import axi5_pkg::*;

module axi5_tb;
  
  reg clk, rst_n;
  
  // Clock generation
  initial begin
    clk = 0;
    forever #0.625ns clk = ~clk;  // 800MHz
  end
  
  // Reset sequence
  initial begin
    rst_n = 0;
    #10us;
    rst_n = 1;
  end
  
  // AXI5 interfaces
  axi_if #(.AXI_DATA_WIDTH(512)) aw_if(clk, rst_n);
  axi_if #(.AXI_DATA_WIDTH(512)) w_if(clk, rst_n);
  // ... other channels ...
  
  // DUT instantiation
  axi5_system_top dut (
    .clk(clk),
    .rst_n(rst_n),
    // ... connect interfaces ...
  );
  
  initial begin
    run_test("axi5_sanity_test");
  end
  
endmodule : axi5_tb
```

### 4.2 UVM Test Sequence Example

```systemverilog
class axi5_write_test extends uvm_test;
  `uvm_component_utils(axi5_write_test)
  
  axi5_env env;
  axi5_write_seq write_seq;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = axi5_env::type_id::create("env", this);
  endfunction
  
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    // Generate a write transaction
    write_seq = axi5_write_seq::type_id::create("write_seq");
    write_seq.randomize() with {
      addr inside {[0:'h1000]};
      len inside {[0:15]};
      size == 3'h3;  // 8 bytes
    };
    write_seq.start(env.mst_agent.sequencer);
    
    #100us;
    phase.drop_objection(this);
  endtask
  
endclass : axi5_write_test
```

---

## 5. Design Flow & Integration Checklist

### 5.1 Integration Steps

- [ ] **Step 1**: Copy `rtl/axi5_pkg.sv` to your project RTL directory
- [ ] **Step 2**: Configure parameters in `axi5_pkg.sv` for your system
- [ ] **Step 3**: Instantiate `axi5_master` module in your top-level design
- [ ] **Step 4**: Instantiate `axi5_slave` module for your slave component
- [ ] **Step 5**: (Optional) Instantiate `axi5_interconnect` for multi-master systems
- [ ] **Step 6**: (Optional) Instantiate CDC synchronizers for multi-clock domains
- [ ] **Step 7**: Bind protocol checker assertions (e.g., `bind dut axi5_aw_checker()`)
- [ ] **Step 8**: Run simulation: `make sim`
- [ ] **Step 9**: Run synthesis: `make synth` (Design Compiler)
- [ ] **Step 10**: Run formal CDC verification: `make cdc_check`

### 5.2 Testing Checklist

- [ ] Sanity test: Single write, single read
- [ ] Burst test: 16-beat write, 16-beat read
- [ ] Interleaved test: Multiple transactions in flight
- [ ] Strobes test: Partial byte writes
- [ ] Out-of-order responses: Different IDs returning out of order
- [ ] Clock domain crossing: Multi-clock reads/writes
- [ ] Stress test: High throughput, back-to-back transactions
- [ ] Error test: Slave errors, decode errors, invalid strobes
- [ ] Coverage: 85%+ functional coverage

---

## 6. Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Deadlock | Backpressure loop | Add flow control logic; verify no combinatorial loops |
| Data corruption | Signal stability violation | Check `wdata` stable while `wvalid=1` |
| Wrong response | ID mismatch | Verify `bid` matches `awid` from master |
| Timing failure | Critical path > 1.25ns | Pipelined arbitration; add registers on long paths |
| CDC metastability | Insufficient sync stages | Use 3-stage minimum for 5nm |
| Coverage gaps | Unexercised corner cases | Add targeted tests; increase randomization |

---

## 7. Performance Tuning

### 7.1 Throughput Optimization

- **Use INCR bursts**: Simpler address generation
- **Maximize burst length**: Longer bursts (awlen/arlen closer to 255)
- **Avoid strobes**: Use full word writes when possible
- **Pipelined arbitration**: Round-robin on transaction completion, not per beat

### 7.2 Latency Optimization

- **CDC latency**: Unavoidable 3-4 cycles; accept and pipeline
- **Slave response time**: Minimize time from AW→B
- **Combinatorial ready**: Slave ready can be combinatorial (path to next module)

### 7.3 Area Optimization

- **Remove CDC if single clock**: Delete CDC modules if only one clock domain
- **Reduce ID width**: If <256 outstanding transactions, shrink `AXI_ID_WIDTH` to 8
- **Reduce address width**: Use 32-bit addresses if <4GB address space
- **Remove user signals**: Set `AXI_USER_WIDTH=0` if not needed

---

## 8. Next Steps

**Phase 2 RTL Implementation**:
1. Implement CDC synchronizers (T2.1)
2. Implement AXI Master (T2.2)
3. Implement AXI Slave (T2.3)
4. Implement Protocol Checkers (T2.4)
5. Implement Interconnect (T2.5)

**Phase 3 Verification**:
1. UVM environment setup
2. Transaction sequences
3. Functional coverage
4. Regression tests

---

**Status**: ✅ Quickstart Complete | Ready for Phase 2 RTL Implementation

