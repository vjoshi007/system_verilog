// DESIGNER    :- VIVEK JOSHI 
// VERSION     :-       0.0.1
// DATE        :-     21/11/26
/* DESCRIPTION :-  Design a rising-edge detector.
dout is high for one cycle, the cycle after one in which din is high and was low in the cycle before. In every other cycle dout is low.
resetn is a synchronous, active-low reset; while it is low, din counts as low. */
// LATENCY     :-          1
// LOGIC GATE  :-       
// TBD         :-  
// AREA Beats 84% and fmax beats 55%  
// Run command :- verilator --binary --timing -Wno-fatal bin_to_thermo.sv
//             :- ./obj_dir/edge_det

module edge_det(
    input logic clk    , 
    input logic resetn ,
    input logic din    , 
    output logic dout
);

logic r_din ; 

always_ff @(posedge clk)  
    if(!resetn) 
        r_din  <= 0;
    else begin 
        r_din  <= din;
        if (!r_din & din) 
            dout <= 1;
        else 
            dout <= 0;
    end 

endmodule