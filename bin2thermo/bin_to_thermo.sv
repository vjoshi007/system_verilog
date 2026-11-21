// DESIGNER    :- VIVEK JOSHI 
// VERSION     :-       0.0.1
// DATE        :-     21/11/26
/* DESCRIPTION :- Design a binary-to-thermometer decoder.A thermometer(unary) code writes a number m as a word whose lowest m bits are 1 and the rest 0, like 
mercury rising in a thermometer.dout is the thermometer code of din: its lowest din bits are 1 and all higher bits are 0. So din =0 gives all 0s, 
and the largest din leaves only the top bit of dout at 0. */
// LATENCY     :- 
// LOGIC GATE  :- 
// TBD         :-
// Run command :- verilator --binary --timing -Wno-fatal bin_to_thermo.sv
//             :- ./obj_dir/bin_to_thermo 

module bin_to_thermo#(
    parameter int DIN_WIDTH = 8
)(
    input  logic [DIN_WIDTH-1:0]        din ,
    output logic [2**DIN_WIDTH-1 : 0]   dout
);

// Area beats 239% 1,695.9µm² Fmax beats 99% 421.9MHz
// assign dout = ~({2 ** DIN_WIDTH{1'b1}} << din);

// Area beats 28% 1,757.9µm² Fmax beats 99% 609.8MHz
always_comb begin
   dout = '{default:0};
   for (int i=0; i < din; i++) begin 
         dout[i] = 1;
   end     
end  

endmodule 
