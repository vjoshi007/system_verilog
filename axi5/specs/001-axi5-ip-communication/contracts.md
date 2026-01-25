# AXI-5 Protocol Interface Contracts & Assertions

**Date**: 2026-01-25 | **Task**: T1.2 | **Status**: ✅ Complete

---

## 1. Write Address Channel (AW) Contract

### 1.1 Valid-Ready Handshaking
```
Timing Diagram:
  Clock:        ↑       ↑       ↑       ↑       ↑
  awvalid:  0___1_______1   0___1___________0
  awready:  1___1   0___1___1___________1
  Transfer:      ✓ (beat 1)   ✗   ✓ (beat 2)
```

**Rules:**
- Transfer occurs when `awvalid && awready` on clock edge
- Master must hold `awaddr`, `awlen`, `awsize`, `awburst`, `awid`, etc. stable while `awvalid=1` until transfer
- Slave can assert/deassert `awready` independent of `awvalid`
- `awready` may be combinatorial (no feedback from slave side)
- No requirement for immediate response; slave can stall

### 1.2 Signal Stability Contract

**While awvalid=1:**
```
awaddr   must remain stable until (awvalid && awready)
awlen    must remain stable until transfer
awsize   must remain stable until transfer
awburst  must remain stable until transfer
awid     must remain stable until transfer
awlock   must remain stable until transfer
awcache  must remain stable until transfer
awprot   must remain stable until transfer
awqos    must remain stable until transfer
awregion must remain stable until transfer
awuser   must remain stable until transfer
```

**After transfer:**
- Master may change any signal on next clock
- If new transaction not presented, master must deassert `awvalid`

### 1.3 Address Constraints

**Alignment Rule:**
```
awaddr must be aligned to 2^awsize bytes
Example: if awsize=3 (8 bytes), awaddr[2:0] must be 0
Assert: awaddr[awsize-1:0] == 0
```

**Burst Size Rule:**
```
awsize must be ≤ 7 (max 128 bytes per beat)
For standard AXI-4: awsize ≤ 3 (max 8 bytes)
Assert: awsize <= 7
```

**Burst Length Rule:**
```
awlen ranges 0-255 (1 to 256 beats per transaction)
Assert: Always satisfied by 8-bit field
```

**Burst Type Rule:**
```
For BURST_INCR: address increments by 2^awsize each beat
For BURST_FIXED: same address for all beats
For BURST_WRAP: address wraps at (awlen+1)*2^awsize boundary
Assert: awburst != 2'b11 (reserved)
```

### 1.4 SVA Assertions for AW Channel

```systemverilog
// AW Channel Assertions

// Valid/Ready handshaking
property aw_valid_ready_handshake;
  @(posedge clk) disable iff (rst)
  (awvalid && awready) |=> awvalid || !awvalid;  // Flexible
endproperty

// Signal stability while valid
property aw_addr_stability;
  @(posedge clk) disable iff (rst)
  awvalid |-> ##0 (awaddr == $past(awaddr))
  until (awvalid && awready);
endproperty

property aw_len_stability;
  @(posedge clk) disable iff (rst)
  awvalid |-> ##0 (awlen == $past(awlen))
  until (awvalid && awready);
endproperty

// Address alignment
property aw_alignment;
  @(posedge clk) disable iff (rst)
  (awvalid && awready) |-> (awaddr % (1 << awsize) == 0);
endproperty

// Size constraint
property aw_size_max;
  @(posedge clk) disable iff (rst)
  awvalid |-> (awsize <= 7);  // Max 128 bytes
endproperty

// Burst type valid
property aw_burst_valid;
  @(posedge clk) disable iff (rst)
  awvalid |-> (awburst != 2'b11);
endproperty

// Coverage: Capture address patterns
cover property (@(posedge clk) awvalid && awready);
cover property (@(posedge clk) awvalid && !awready);
cover property (@(posedge clk) awburst == BURST_INCR);
cover property (@(posedge clk) awburst == BURST_FIXED);
cover property (@(posedge clk) awburst == BURST_WRAP);
```

---

## 2. Write Data Channel (W) Contract

### 2.1 Valid-Ready Handshaking

**Similar to AW channel:**
- Transfer when `wvalid && wready`
- Data stability while `wvalid=1`
- `wready` can be combinatorial

### 2.2 Write Data Constraints

**Data & Strobes:**
```
wdata  : 512-bit write data
wstrb  : 64-bit strobes (1 per byte)
         1 = byte is valid, 0 = byte is invalid/masked
         
Example: wdata[15:0] valid with wstrb[1:0] = 2'b11
         wdata[23:16] invalid with wstrb[2] = 1'b0
```

**Last Signal:**
```
wlast=0 : Not the final beat of the burst
wlast=1 : Final beat of burst (must come after awlen beats)

Rule: If awlen=3 (4 beats total), wlast must be 1 on beat #3 (0-indexed)
```

**Beat Counting:**
```
For awlen=N, expect N+1 beats (0 to N inclusive)
Rule: Master must send exactly (awlen+1) beats for each AW transaction
```

### 2.3 Strobes Rules

```
No all-zeros allowed: wstrb must have at least 1 bit set (unless error)
On last beat: wstrb can be partial (aligned to bytes)
Example: 64-byte write, last beat only 16 bytes: wstrb[63:2] = 0

Standard: wstrb[i] = 1 for byte i, 0 for masked
Alignment: No requirement; can strobe any byte combination
```

### 2.4 SVA Assertions for W Channel

```systemverilog
// W Channel Assertions

// Strobe not all zeros (except for error cases)
property w_strb_not_zero;
  @(posedge clk) disable iff (rst)
  wvalid |-> (wstrb != 0);  // At least 1 byte valid
endproperty

// Last beat must come after correct number of beats
property w_last_position;
  @(posedge clk) disable iff (rst)
  let beat_count = $past(beat_count) + (wvalid && wready ? 1 : 0);
  (wvalid && wready) |-> (wlast == (beat_count == awlen + 1));
endproperty

// Data stability
property w_data_stability;
  @(posedge clk) disable iff (rst)
  wvalid |-> ##0 (wdata == $past(wdata))
  until (wvalid && wready);
endproperty

property w_strb_stability;
  @(posedge clk) disable iff (rst)
  wvalid |-> ##0 (wstrb == $past(wstrb))
  until (wvalid && wready);
endproperty

// Coverage
cover property (@(posedge clk) wvalid && wready && wlast);
cover property (@(posedge clk) wvalid && !wready);
cover property (@(posedge clk) wvalid && wstrb == {AXI_STRB_WIDTH{1'b1}});
cover property (@(posedge clk) wvalid && wstrb != {AXI_STRB_WIDTH{1'b1}});
```

---

## 3. Write Response Channel (B) Contract

### 3.1 Response Codes

```
bresp[1:0]:
  2'b00 (OKAY)   : Write completed successfully
  2'b01 (EXOKAY) : Exclusive write succeeded (rare)
  2'b10 (SLVERR) : Slave error (bad address, etc.)
  2'b11 (DECERR) : Decode error (unmapped address)
```

### 3.2 Response Ordering Rules

**Ordering guarantee per ID:**
```
If Master sends:
  AW[ID=5, Addr=0x1000]
  AW[ID=5, Addr=0x2000]
  
Then B responses must come in order:
  B[ID=5] for first write
  B[ID=5] for second write
```

**Across different IDs:**
```
Responses to different IDs can return out-of-order
ID=1 response may come before ID=0 response
```

### 3.3 Response Generation Rules

```
B response generated when:
1. AW address accepted (awvalid && awready)
2. All W data beats received (for that AW)
3. Slave memory operation completes

May generate B immediately or hold for many cycles
```

### 3.4 SVA Assertions for B Channel

```systemverilog
// B Channel Assertions

// Valid-Ready handshaking
property b_valid_ready_handshake;
  @(posedge clk) disable iff (rst)
  (bvalid && bready) |=> (bvalid || !bvalid);  // Flexible next cycle
endproperty

// Signal stability
property b_resp_stability;
  @(posedge clk) disable iff (rst)
  bvalid |-> ##0 (bresp == $past(bresp))
  until (bvalid && bready);
endproperty

property b_id_stability;
  @(posedge clk) disable iff (rst)
  bvalid |-> ##0 (bid == $past(bid))
  until (bvalid && bready);
endproperty

// BID matches issued AW transaction ID
property b_id_matches_aw;
  @(posedge clk) disable iff (rst)
  (awvalid && awready) |->
    ##[1:1000] (bvalid && bready && (bid == $past(awid, 1)));
endproperty

// One B per AW transaction
property one_b_per_aw;
  @(posedge clk) disable iff (rst)
  (awvalid && awready) |->
    ##[1:1000] (bvalid && bready);
endproperty

// Coverage
cover property (@(posedge clk) bvalid && bready && bresp == RESP_OKAY);
cover property (@(posedge clk) bvalid && bready && bresp == RESP_SLVERR);
cover property (@(posedge clk) bvalid && bready && bresp == RESP_DECERR);
```

---

## 4. Read Address Channel (AR) Contract

**Similar to AW channel:**
- Same valid-ready handshaking
- Same signal stability rules
- Same address alignment constraints
- `arid` must be unique (up to 4096 outstanding transactions)

### 4.1 SVA Assertions for AR Channel

```systemverilog
// AR Channel Assertions (similar to AW)

property ar_valid_ready_handshake;
  @(posedge clk) disable iff (rst)
  (arvalid && arready) |=> (arvalid || !arvalid);
endproperty

property ar_addr_stability;
  @(posedge clk) disable iff (rst)
  arvalid |-> ##0 (araddr == $past(araddr))
  until (arvalid && arready);
endproperty

property ar_alignment;
  @(posedge clk) disable iff (rst)
  (arvalid && arready) |-> (araddr % (1 << arsize) == 0);
endproperty

property ar_size_max;
  @(posedge clk) disable iff (rst)
  arvalid |-> (arsize <= 7);
endproperty

property ar_burst_valid;
  @(posedge clk) disable iff (rst)
  arvalid |-> (arburst != 2'b11);
endproperty

// Coverage
cover property (@(posedge clk) arvalid && arready);
cover property (@(posedge clk) arburst == BURST_INCR);
cover property (@(posedge clk) arburst == BURST_FIXED);
```

---

## 5. Read Data Channel (R) Contract

### 5.1 Data & Response Rules

**rlast Signal:**
```
Similar to wlast:
- rlast=0: More data beats coming
- rlast=1: Final beat of read burst
- For arlen=N, expect N+1 beats with rlast=1 on final beat
```

**rresp Codes:**
```
Same as bresp:
  2'b00 (OKAY)   : Data valid
  2'b10 (SLVERR) : Slave error
  2'b11 (DECERR) : Decode error
```

**rid Matching:**
```
rid must match corresponding arid from AR transaction
Rule: Master tracks via ID; can have multiple outstanding reads
```

### 5.2 Read Data Ordering

```
Same ID ordering: Responses for same arid must return in FIFO order
Different IDs: Can be out-of-order
```

### 5.3 SVA Assertions for R Channel

```systemverilog
// R Channel Assertions

property r_valid_ready_handshake;
  @(posedge clk) disable iff (rst)
  (rvalid && rready) |=> (rvalid || !rvalid);
endproperty

property r_data_stability;
  @(posedge clk) disable iff (rst)
  rvalid |-> ##0 (rdata == $past(rdata))
  until (rvalid && rready);
endproperty

property r_resp_stability;
  @(posedge clk) disable iff (rst)
  rvalid |-> ##0 (rresp == $past(rresp))
  until (rvalid && rready);
endproperty

property r_id_stability;
  @(posedge clk) disable iff (rst)
  rvalid |-> ##0 (rid == $past(rid))
  until (rvalid && rready);
endproperty

// RID matches issued AR transaction ID
property r_id_matches_ar;
  @(posedge clk) disable iff (rst)
  (arvalid && arready) |->
    ##[1:1000] (rvalid && rready && (rid == $past(arid, 1)));
endproperty

// Last burst beat
property r_last_on_final_beat;
  @(posedge clk) disable iff (rst)
  let beat_count = $past(beat_count) + (rvalid && rready ? 1 : 0);
  (rvalid && rready) |-> (rlast == (beat_count == arlen + 1));
endproperty

// Coverage
cover property (@(posedge clk) rvalid && rready && rlast);
cover property (@(posedge clk) rvalid && rready && rresp == RESP_OKAY);
cover property (@(posedge clk) rvalid && rready && rresp == RESP_SLVERR);
```

---

## 6. Cross-Channel Constraints

### 6.1 Write Order per ID

```
Property: Write address->write data must maintain order
If AW[ID=k] comes first, then W data for that transaction must complete
before AW[ID=k] accepts next write to same address range
(Not strictly enforced; slave may reorder but must handle coherence)
```

### 6.2 Outstanding Transactions

```
Maximum outstanding transactions = 2^AXI_ID_WIDTH = 2^12 = 4096

Master must not exceed this limit:
- Number of unresolved AW transactions ≤ 4096
- Number of unresolved AR transactions ≤ 4096
```

### 6.3 No Deadlock

```
Design must guarantee no circular waiting:
- W data should arrive reasonably after AW
- B response must come after both AW and all W beats
- R data must come after AR

Timeouts may be required in simulation for safety
```

---

## 7. Summary of Critical Assertions

| Channel | Key Assertions | Coverage |
|---------|----------------|----------|
| AW | Valid/ready, alignment, stability, burst valid | Address patterns, burst types |
| W | Last signal, strobe valid, data stability | Last beats, strobes, interleaving |
| B | ID matching, response codes, per-AW ordering | Response types, order |
| AR | Valid/ready, alignment, stability, burst valid | Address patterns, burst types |
| R | ID matching, last signal, response codes | Response types, order, rlast |

---

**Status**: ✅ Contracts Complete | Ready for RTL implementation

