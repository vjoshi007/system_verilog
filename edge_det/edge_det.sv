// DESIGNER    :- VIVEK JOSHI 
// VERSION     :-       0.0.1
// DATE        :-     21/11/26
/* DESCRIPTION :- detect a rising edge in input signal */
// LATENCY     :-          1
// LOGIC GATE  :-       
// TBD         :-   
// Run command :- verilator --binary --timing -Wno-fatal bin_to_thermo.sv
//             :- ./obj_dir/edge_det

module edge_det(
    input logic clk    , 
    input logic resetn ,
    input logic din    , 
    output logic dout
);

logic r_din ; 

always_ff @(posedge clk, negedge resetn)  
    if(!resetn) 
        r_din  <= 0;
    else 
        r_din  <= din;

    assign dout = (!r_din & din & resetn) ? 1 : 0; 

endmodule