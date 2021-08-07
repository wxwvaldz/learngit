`include "mycpu.h"

module CP0(
  input         reset       ,
  input         clk         ,
  input         mtc0_we     ,      //cp0写使能
  input [ 7:0]  c0_addr     ,       //写地址
  input [31:0]  c0_wdata    ,       //写数据
  input         wb_ex       ,       //写回级例外
  input         eret_flush  ,       //eret指令
  input         wb_bd       ,
  input [5:0]   ext_int_in  ,
  input [4:0]   wb_excode   ,
  input [31:0]  wb_pc       ,
  input         mtc0_en     ,
  output [31:0] c0_rdata    ,
  output reg [31:0] c0_epc  
);
wire c0_status_bev;
reg [ 7:0] c0_status_im;
reg c0_status_exl;
reg c0_status_ie;

reg c0_cause_bd;
reg c0_cause_ti;
reg [ 7:0] c0_cause_ip;
reg [ 4:0] c0_cause_excode;

reg [31:0] c0_epc;
wire [7:0] cr_epc;
wire [7:0] cr_cause;
wire [7:0] cr_status;
wire [7:0] cr_compare;

assign cr_epc = 8'b01110000;
assign cr_cause = 8'b01101000;
assign cr_status = 8'b01100000;
assign cr_compare = 8'b01011000;

assign c0_rdata =   ({32{c0_addr == cr_status}} & {9'b0,1'b1,6'b0,c0_status_im[7:0],6'b0,c0_status_exl,c0_status_ie})
                |   ({32{c0_addr == cr_cause}} & {c0_cause_bd,c0_cause_ti,14'b0,c0_cause_ip[7:0],1'b0,c0_cause_excode[4:0],2'b0})
                |   ({32{c0_addr == cr_epc}} & {c0_epc[31:0]});

assign c0_status_bev = 1'b1;

always @(posedge clk) begin
    if (mtc0_we && c0_addr == cr_status) begin
        c0_status_im <= c0_wdata[15:8];
    end
end

always @(posedge clk) begin
if (reset)
 c0_status_exl <= 1'b0;
else if (wb_ex)                     //写回报例外
 c0_status_exl <= 1'b1;
else if (eret_flush)                //eret指令
 c0_status_exl <= 1'b0;
else if (mtc0_we && c0_addr==cr_status)
 c0_status_exl <= c0_wdata[1];
end

always @(posedge clk) begin
if (reset)
 c0_status_ie <= 1'b0;
else if (mtc0_we && c0_addr==cr_status)
 c0_status_ie <= c0_wdata[0];
end

always @(posedge clk) begin
if (reset)
 c0_cause_bd <= 1'b0;
else if (wb_ex && !c0_status_exl)
 c0_cause_bd <= wb_bd;
end

always @(posedge clk) begin
if (reset)
 c0_cause_ti <= 1'b0;
else if (mtc0_we && c0_addr==cr_compare)
 c0_cause_ti <= 1'b0;
// else if (count_eq_compare)
//  c0_cause_ti <= 1'b1;
end

always @(posedge clk) begin
if (reset)
 c0_cause_ip[7:2] <= 6'b0;
else begin
 c0_cause_ip[7] <= ext_int_in[5] | c0_cause_ti;
 c0_cause_ip[6:2] <= ext_int_in[4:0];
end
end

always @(posedge clk) begin
if (reset)
 c0_cause_ip[1:0] <= 2'b0;
else if (mtc0_we && c0_addr==cr_cause)
 c0_cause_ip[1:0] <= c0_wdata[9:8];
end

always @(posedge clk) begin
if (reset)
 c0_cause_excode <= 5'b0;
else if (wb_ex)
 c0_cause_excode <= wb_excode;
end

always @(posedge clk) begin
if (wb_ex && !c0_status_exl)
 c0_epc <= wb_bd ? wb_pc - 3'h4 : wb_pc;
else if (mtc0_we && c0_addr== cr_epc)
 c0_epc <= c0_wdata;
end

endmodule