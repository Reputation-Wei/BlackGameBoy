`timescale 1ns / 1ps


module ssegcontrol(
input [15:0]B,//Binary code
input clk,
output reg [6:0]seg_cat,//segment
output reg  [3:0]seg_an
);

//// Seg colck
reg [15:0]counter=16'b0;
always @(posedge clk) begin
 counter <= counter +1;
 end
/////4 to 1 mux
wire [3:0]Y;
wire [3:0] I0,I1,I2,I3;
assign I0 = B[3:0];
assign I1 = B[7:4];
assign I2 = B[11:8];
assign I3 = B[15:12];
assign Y =counter[14]?(counter[15]?I3:I1):(counter[15]?I2:I0);
//////////////////////////////////////////////
////2:4 decoder to control which segment is an
       always@(*)
       begin 
       case(counter[15:14])
       2'b00: seg_an <= 4'b1110;
       2'b01: seg_an <= 4'b1101;
       2'b10: seg_an <= 4'b1011;
       2'b11: seg_an <= 4'b0111;
       
       default: seg_an <= 4'b1111;  
       endcase
       end
///////////////////////////////////////////////         
/////7seg decoder
//reg[6:0] seg_cat;
always @(*)begin
case(Y)
4'b0000:seg_cat<=7'b1000000;
4'b0001:seg_cat<=7'b1111001;
4'b0010:seg_cat<=7'b0100100;
4'b0011:seg_cat<=7'b0110000;
4'b0100:seg_cat<=7'b0011001;
4'b0101:seg_cat<=7'b0010010;
4'b0110:seg_cat<=7'b0000010;
4'b0111:seg_cat<=7'b1111000;
4'b1000:seg_cat<=7'b0000000;
4'b1001:seg_cat<=7'b0010000;
default: seg_cat<=7'b1111111;
endcase
end
endmodule