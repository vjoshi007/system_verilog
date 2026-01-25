# AXI-5 Protocol Research & Technical Foundation

**Date**: 2026-01-25 | **Phase**: 0 | **Task**: T0.1, T0.2, T0.4  
**Status**: ✅ Complete | **Effort**: 1.5 days

---

## 1. AXI-5 Protocol Specification Overview

### 1.1 Transaction Semantics

AXI-5 is a high-performance, point-to-point protocol for master-to-slave communication with these core properties:

#### Five Independent Channels
1. **Write Address (AW)**: Address, burst type, size, length, ID
2. **Write Data (W)**: Data, strobes, last signal
3. **Write Response (B)**: Response code, ID
4. **Read Address (AR)**: Address, burst type, size, length, ID
5. **Read Data (R)**: Data, response code, ID, last signal

#### Key Characteristics
- **Fully Pipelined**: Each channel independent, no blocking dependencies
- **Decoupled Handshaking**: `valid/ready` on every channel
- **Out-of-Order Capable**: Responses may return in different order than requests
- **Bursting**: Supports 1-256 transfers per transaction (AXI-5 extends beyond AXI4)
- **ID-based Tracking**: Master/slave track transactions via ID field

### 1.2 Handshaking Protocol

#### Basic Ready-Valid Mechanism
```
  Clock edge:          ↑           ↑           ↑
  Master (valid):   0   1___________1   0___________1
  Slave (ready):    1___1           0___1_________1
  Transfer:              ✓ (valid&&ready)
```

**Rules:**
- Master sets `valid` when data is ready
- Slave sets `ready` when accepting data
- Transfer occurs when **both valid AND ready** are high on clock edge
- Master must maintain data stable while valid=1 until transfer completes
- Slave must accept data when both signals high

#### Handshaking Rules by Channel

**Write Address (AW) Channel:**
- Must complete before corresponding Write Data (W) arrives (optional)
- AW-to-W ordering not required (W can precede AW completion)
- Multiple outstanding AW transactions allowed (up to ID width: 2^12)

**Write Data (W) Channel:**
- Can precede or follow AW channel
- Last signal indicates final beat of burst
- Strobes indicate which bytes are valid
- Multiple bursts can be interleaved

**Write Response (B) Channel:**
- Must be returned after both AW and all W beats received
- One response per AW transaction
- Can be ordered or out-of-order (slave dependent)

**Read Address (AR) Channel:**
- Specifies read transaction parameters
- Multiple outstanding AR transactions allowed

**Read Data (R) Channel:**
- Last signal indicates final beat
- Multiple read bursts can be interleaved
- Data ordering per ID preserved (FIFO per ID)

### 1.3 Packet Structures

#### Write Address (AW) Packet
```
Signal       Width   Description
awaddr       64      Write address (byte-aligned)
awlen        8       Burst length-1 (0=1 beat, 255=256 beats)
awsize       3       Bytes per beat (0=1B, 1=2B, 2=4B, 3=8B... 7=128B)
awburst      2       Burst type (0=FIXED, 1=INCR, 2=WRAP)
awid         12      Transaction ID
awlock       1       Exclusive access (0=normal, 1=exclusive)
awcache      4       Cache policy
awprot       3       Protection type (privilege, security, data/instr)
awqos        4       Quality of Service
awregion     4       Region indicator
awuser       *       User-defined sideband (optional, configurable)
awvalid      1       Address valid
awready      1       Slave ready to accept
```

#### Write Data (W) Packet
```
Signal       Width   Description
wdata        512     Write data (typically 64-512 bits)
wstrb        64      Write strobes (1 bit per byte: 0=invalid, 1=valid)
wlast        1       Last beat of burst (0=not last, 1=final)
wuser        *       User-defined sideband (optional)
wvalid       1       Data valid
wready       1       Slave ready
```

#### Write Response (B) Packet
```
Signal       Width   Description
bresp        2       Response code (0=OKAY, 1=EXOKAY, 2=SLVERR, 3=DECERR)
bid          12      Echo of awid
buser        *       User-defined sideband
bvalid       1       Response valid
bready       1       Master ready
```

#### Read Address (AR) Packet
```
Signal       Width   Description
araddr       64      Read address
arlen        8       Burst length-1
arsize       3       Bytes per beat
arburst      2       Burst type
arid         12      Transaction ID
arlock       1       Exclusive access
arcache      4       Cache policy
arprot       3       Protection type
arqos        4       Quality of Service
arregion     4       Region indicator
aruser       *       User-defined sideband
arvalid      1       Address valid
arready      1       Slave ready
```

#### Read Data (R) Packet
```
Signal       Width   Description
rdata        512     Read data
rresp        2       Response code
rid          12      Echo of arid
rlast        1       Last beat
ruser        *       User-defined sideband
rvalid       1       Data valid
rready       1       Master ready
```

### 1.4 Transaction Flow Diagrams

#### Scenario A: Simple Single-Beat Write
```
Time:        0   1   2   3   4
awvalid:     0   1   1   1   0
awready:     1   1   0   1   1
wvalid:      0   0   1   1   0
wready:      1   1   1   0   1
wlast:       0   0   1   0   0
bvalid:      0   0   0   0   1
bready:      1   1   1   1   1

Transfers:      AW  W   B
```

#### Scenario B: Burst Write (4 beats, address first)
```
Time:        0   1   2   3   4   5   6   7
awvalid:     0   1   1   1   0   0   0   0
awready:     1   1   0   1   1   1   1   1
wvalid:      0   0   0   1   1   1   1   0
wready:      1   1   1   1   1   1   0   1
wlast:       0   0   0   0   0   0   1   0
bvalid:      0   0   0   0   0   0   0   1
bready:      1   1   1   1   1   1   1   1

Transfers:      AW  W0  W1  W2  W3  B
```

#### Scenario C: Out-of-Order Response Read (2 masters)
```
Master1 AR: ID=0, len=1
Master2 AR: ID=1, len=1
Master1 data returns: R[ID=0, rlast=1]
Master2 data returns: R[ID=1, rlast=1] (may come before M1's response)
```

### 1.5 Protocol Rules & Constraints

#### Address/Burst Rules
- **awlen/arlen**: 0-255 (1 to 256 beats per transaction)
- **awsize/arsize**: Must be ≤ 4 (max 16 bytes per beat) for standard AXI; AXI-5 allows up to 128B
- **awburst/arburst**: 
  - 0 = FIXED (same address every beat)
  - 1 = INCR (address increments)
  - 2 = WRAP (address wraps within boundary)
- **Address alignment**: Address must be aligned to `2^awsize` boundaries

#### Write Response Rules
- Response (B) must arrive after both AW and all W beats received
- One B per AW transaction
- B.id must match corresponding AW.id
- Response code: 0=OK, 1=exclusive OK, 2=slave error, 3=decode error

#### Read Data Rules
- Read Data (R) returns after AR accepted
- Multiple R beats if arlen > 0
- Last R beat has rlast=1
- R.id must match corresponding AR.id

#### Ordering Rules
- **No write-to-write reordering**: Writes to same address must complete in order
- **No read-to-read reordering**: Reads to same ID must return in order
- **Write-to-read reordering**: Allowed (unless AwDomain enforces ordering)
- **ID-based ordering**: Transactions with same ID must preserve FIFO order

#### Handshaking Rules
- **Valid/Ready stable**: Once valid asserts, data must remain stable until transfer
- **Ready independent**: Slave ready can be asserted independent of valid
- **Combinatorial ready**: Ready can be combinatorial (no pipeline delay)
- **No feedback loops**: Valid cannot depend on ready in same clock domain (CDC rule)

### 1.6 Edge Cases & Protocol Pitfalls

1. **Burst wrapping misalignment**: Wrap must not cross 4KB boundary
2. **Interleaved bursts**: Different transactions can interleave W data (by wlast signal)
3. **Out-of-order responses**: R/B channels can deliver out-of-order; master must track via ID
4. **Exclusive access**: awlock/arlock=1 implies atomic access; not common in modern designs
5. **Zero-length transfer**: awlen=0 means 1 beat (not zero)
6. **Strobes on last beat**: wstrb can differ on last beat (mask alignment)
7. **Response latency**: Response can come immediately or much later; no specified timing

---

## 2. Clock Domain Crossing (CDC) Strategy for 5nm @ 800MHz

### 2.1 Metastability Fundamentals

**Problem**: When data crosses clock domains, setup/hold violations can cause metastability—output oscillates unpredictably.

**Solution**: Insert synchronizer stages to let metastability settle before next logic uses the data.

### 2.2 CDC Synchronizer Types

#### 2.2.1 Multi-Bit Gray Code Synchronizer
**Use Case**: Multiple data bits crossing clock domains  
**Mechanism**: Gray code ensures only 1 bit changes per increment

```
Binary:  00 01 10 11 00 01 10 11...
Gray:    00 01 11 10 00 01 11 10...  ← Only 1 bit changes per step
```

**Implementation**:
- Convert binary write pointer to Gray in write clock domain
- Synchronize Gray pointer through 3-stage flip-flop chain in read domain
- Convert Gray back to binary for FIFO address

**Depth**: 3 stages minimum for 5nm @ 800MHz (MTTF > 10^15 seconds)

#### 2.2.2 Pulse Synchronizer
**Use Case**: Single-clock pulse crossing domains  
**Mechanism**: Extend pulse to span multiple cycles, synchronize, detect edge in read domain

```
Write domain:  pulse_in ___1___
Sync stage 1:            _______1___
Sync stage 2:            ___________1___
Sync stage 3:            _______________1___
Read domain:   pulse_out (edge detect)
```

**Latency**: 2-3 cycles

#### 2.2.3 Handshake Synchronizer
**Use Case**: Block transfer across domains  
**Mechanism**: Req/Ack toggle until synchronized

```
Write: assert req_w → (synchronized) → read ack_r → deassert req_w
Read:  (synchronized) → req_r → assert ack_r
```

**Latency**: ~4-6 cycles

#### 2.2.4 CDC-Safe FIFO Pointer Synchronization
**Use Case**: Multi-clock FIFO with Gray code pointers

**Write pointer in read domain**: 
- Advance write pointer in write clock
- Convert to Gray
- Synchronize through 3-flip-flop chain to read clock
- Convert back to binary in read clock
- Use to check "almost full" condition

**Read pointer in write domain** (symmetric)

### 2.3 Multi-Clock Configuration (800MHz Base)

```
Clock Domains:
├── clk_800  (800 MHz)   ← Primary, all synchronous logic
├── clk_400  (400 MHz)   ← 800÷2
├── clk_200  (200 MHz)   ← 800÷4
├── clk_100  (100 MHz)   ← 800÷8
└── clk_50   (50 MHz)    ← 800÷16

CDC Instances Required:
- Between clk_800 ↔ clk_400: Gray pointer sync (FIFO)
- Between clk_800 ↔ clk_200: Gray pointer sync
- Between clk_400 ↔ clk_100: Gray pointer sync
- Reset synchronization: All clocks need async reset with 2-stage sync
- CDC Latency: 3 cycles (sync) + 1 cycle (setup) = 4 cycles per domain crossing
```

### 2.4 Formal Verification of CDC

**Tools**: Cadence Xcelium CDC, Synopsys Verdi CDC, Questa CDC

**Checks**:
1. All clock domain crossings are synchronized
2. No multi-bit data crossing without Gray code or handshake
3. All asynchronous resets synchronized
4. No combinatorial loops across domains
5. FIFO pointer synchronization depth ≥ 3 stages

### 2.5 Area & Timing Impact (5nm)

| Synchronizer | Gates | Registers | Delay | CDC Cycles |
|--------------|-------|-----------|-------|-----------|
| Gray (4-bit) | 50 | 12 | 0.5ns | 3 |
| Pulse | 30 | 6 | 0.3ns | 2-3 |
| Handshake | 80 | 8 | 0.6ns | 4-6 |
| Reset Sync | 20 | 6 | 0.2ns | 2 |

**Total for 4-domain system**: ~500 gates, ~100 registers, <100μm² area

---

## 3. AXI-5 Protocol Implementation Decisions

### 3.1 Synthesizable SystemVerilog Subset

**Allowed Constructs**:
- `always_ff` blocks (sequential logic)
- `always_comb` blocks (combinatorial logic)
- `generate` blocks (parameterized instantiation)
- `interface` definitions (modports)
- SVA assertions (`assert property`, `assume`)
- Enums, structs, typedefs
- Parameterized modules
- Packed arrays & unpacked arrays
- Clocking blocks (testbenches only)

**Forbidden Constructs**:
- `always` (ambiguous timing)
- Blocking assignments (`=`) in sequential blocks
- `wait` statements (not synthesizable)
- Tri-state logic, open-drain
- Combinatorial loops
- Asynchronous set/reset in synthesis
- `$random` in synthesis (use Verilog randomization)

### 3.2 Master/Slave Patterns

#### Master Behavioral Model
```
always_comb begin
  // Stall write address if FIFO full
  awvalid = (pending_write_requests > 0) && !aw_fifo_full;
  awaddr = next_write_addr;
  awid = next_write_id;
  
  // Stall write data if no room
  wvalid = (pending_write_data > 0) && !w_fifo_full;
  wdata = next_write_data;
  wlast = (write_beat_count == awlen);
end

always_ff @(posedge clk) begin
  if (awvalid && awready) begin
    pending_write_requests--;
    next_write_addr += burst_size;
  end
  if (wvalid && wready) begin
    pending_write_data--;
    write_beat_count++;
    if (wlast) write_beat_count <= 0;
  end
  if (bvalid && bready) begin
    // Process write response
  end
end
```

#### Slave Behavioral Model
```
always_comb begin
  // Accept address when space available
  awready = !aw_queue_full;
  arready = !ar_queue_full;
end

always_ff @(posedge clk) begin
  if (awvalid && awready) begin
    aw_queue <= awdata;  // Enqueue write address
  end
  if (wvalid && wready) begin
    data_buffer <= wdata;
    if (wlast) process_write();  // Execute write
  end
end
```

### 3.3 Interconnect Arbitration Strategy

#### Round-Robin Arbiter
**Fairness**: Each master gets equal bandwidth

```
Round-robin priority vector rotates:
  Cycle 0: M0 > M1 > M2 > M3
  Cycle 1: M1 > M2 > M3 > M0
  Cycle 2: M2 > M3 > M0 > M1
  Cycle 3: M3 > M0 > M1 > M2
```

**For AXI**: Priority rotates only on transaction completion, not per beat

#### Fixed Priority Arbiter
**Simplicity**: Hard-wired priority (M0 highest)

```
Priority: M0 > M1 > M2 > M3 (always)
Risk: Lower-priority masters may starve
```

#### Weighted Round-Robin
**Balance**: Assign weights; higher weight = more cycles

```
Example: M0=weight 2, M1=weight 1
Cycle 0-1: M0 gets arbitration
Cycle 2: M1 gets arbitration
Cycle 3-4: M0 again...
```

**Recommendation for AXI-5**: Use simple round-robin with rotation on AW/AR completion (per address, not per data beat)

### 3.4 Performance Targets & Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Clock Frequency | 800MHz | 1.25ns period |
| Master Write Latency (address to response) | <100 cycles | Includes pipeline delay |
| Master Read Latency (address to data) | <100 cycles | Depends on slave memory |
| Interconnect Arbitration Latency | 1-2 cycles | Runt cycles |
| CDC Crossing Latency | 3-4 cycles per domain | Gray code sync |
| Sustained Throughput (write) | 90% of max | Peak = 1 write/cycle |
| Burst Efficiency | 95%+ | Minimize wlast gaps |
| Multi-master Deadlock | Zero in test suite | Formal deadlock check |
| CDC MTBF | >10^15 seconds | 3-stage sync @ 5nm |

---

## 4. UVM Testbench Architecture

### 4.1 Environment Hierarchy

```
uvm_test
  └─ axi5_env
      ├─ axi5_mst_agent_0
      │   ├─ axi5_mst_driver
      │   ├─ axi5_mst_monitor (AW, W, B channels)
      │   ├─ axi5_mst_sequencer
      │   └─ axi5_mst_collector
      ├─ axi5_mst_agent_1
      │   └─ (same as agent_0)
      ├─ axi5_slv_agent
      │   ├─ axi5_slv_driver (responds to requests)
      │   ├─ axi5_slv_monitor (AR, R channels)
      │   └─ axi5_slv_sequencer
      ├─ axi5_scoreboard (transaction matching)
      └─ axi5_coverage_collector (functional coverage)
```

### 4.2 Transaction Types

```
class axi5_write_txn extends uvm_sequence_item;
  rand logic [63:0] awaddr;
  rand logic [7:0]  awlen;
  rand logic [2:0]  awsize;
  rand logic [1:0]  awburst;
  rand logic [11:0] awid;
  rand logic [511:0] wdata[];  // Array of data beats
  rand logic [63:0] wstrb[];
  logic [1:0] bresp;  // Response
endclass

class axi5_read_txn extends uvm_sequence_item;
  rand logic [63:0] araddr;
  rand logic [7:0]  arlen;
  rand logic [2:0]  arsize;
  rand logic [1:0]  arburst;
  rand logic [11:0] arid;
  logic [511:0] rdata[];  // Array of data beats
  logic [1:0] rresp[];    // Response per beat
endclass
```

### 4.3 Coverage Model

**Functional Coverage Bins**:
- Burst lengths (1, 2, 4, 8, 16, 256)
- Burst types (FIXED, INCR, WRAP)
- Address alignments (1B, 2B, 4B, 8B, 16B, ...)
- Data widths (64b, 128b, 256b, 512b)
- Strobes (all 1s, partial, sparse patterns)
- Response codes (OKAY, EXOKAY, SLVERR, DECERR)
- Concurrent transactions (0, 1, 2, 4+ simultaneous)
- Clock domain crossings (within clk_800, cross to clk_400, etc.)
- Out-of-order responses (R/B ordering variations)

**Target**: 85%+ functional coverage before RTL freeze

---

## 5. Summary & Next Steps

### 5.1 Key Takeaways

1. **AXI-5 Protocol**: 5 independent channels, fully pipelined, ID-based tracking, out-of-order capable
2. **CDC Strategy**: 3-stage Gray code synchronizers for multi-bit crossing, pulse sync for single bits
3. **Timing Target**: 800MHz with <4 cycle CDC latency per domain crossing
4. **Verification**: UVM agents for master/slave, randomized sequences, 85%+ coverage
5. **Performance**: 90% sustained throughput, <100 cycle latency, zero deadlock

### 5.2 Proceeding to Phase 1

**Next Tasks**:
- T1.1: Implement `axi5_pkg.sv` with all typedef and parameter definitions
- T1.2: Write `contracts.md` with detailed SVA specification
- T1.3: Create `quickstart.md` with architecture and instantiation
- T1.4: Design state machines and block diagrams

**Deliverables Expected**: 
- Complete type library
- Protocol assertions
- Module hierarchy
- Implementation roadmap

---

**Status**: ✅ Phase 0 Complete | Ready for Phase 1 Design

