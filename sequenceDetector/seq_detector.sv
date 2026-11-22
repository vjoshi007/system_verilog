/* DESCRIPTION :- Design an overlapping sequence detector for the target sequence 1010.
Whenever the target sequence is detected on the serial input stream din, dout should pulse high the following cycle. Sequences may overlap, so the stream 101010 completes two sequences.
resetn is a synchronous, active-low reset; it discards the bits received so far and clears dout.  */
// LATENCY     :-          1
// LOGIC GATE  :-       
// TBD         :-  
// AREA Beats  and fmax beats   
// Run command :- verilator --binary --timing -Wno-fatal .sv
//             :- ./obj_dir/edge_det

module seq_detector(
    input        clk,
    input     resetn, 
    input  logic din,
    output logic dout
);

typedef enum logic[1:0] {idle, s1, s10, s101} state_t ;

state_t present_state;
state_t next_state   ;

always_comb begin 
  next_state = idle;
  // dout       =  0; 
   case (present_state) 
    idle : begin 
         next_state = din ? s1 : idle ; 
//         dout       = 0;
    end 
    s1 : begin 
         next_state = din ? s1 : s10 ;
  //       dout       = 0;
    end 
    s10 : begin 
         next_state = din ? s101 : idle ;
    //     dout       = 0;
    end
    s101 : begin 
         next_state = din ? s1 : s10 ;
      //   dout       = din ? 0  : 1 ;
    end 
   endcase 
end  

always_ff @(posedge clk)
 if(!resetn) begin 
   dout          <= 0 ;  
   present_state <= idle ;
 end else begin  
   present_state <= next_state;
   if (present_state == s101 && din == 0) 
     dout <= 1;
   else 
     dout <= 0;
 end 

endmodule 