`include "mycpu.h"

module if_stage(
    input                          clk              ,
    input                          reset            ,
    //allwoin
    input                          ds_allowin       ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus_d         ,
    //to ds
    output                         fs_to_ds_valid   ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus     ,
    // inst sram interface
    output        inst_sram_req_d                   ,
    output        inst_sram_wr                      ,
    output [ 1:0] inst_sram_size                    ,
    output [ 3:0] inst_sram_wstrb                   ,
    output [31:0] inst_sram_addr                    ,
    output [31:0] inst_sram_wdata                   ,
    input  [31:0] inst_sram_rdata                   ,
    input         inst_sram_addr_ok                 ,
    input         inst_sram_data_ok                 ,
    input  [31:0] ws_pc_send                        ,
    output [31:0] reg_fs_inst                       ,
    input         wb_ex                             ,
    input         eret_flush                        ,
    input         ds_ready_go                       ,
    input         es_allowin                        ,
    input         br_stall                          ,
    input         ds_valid                          ,
    input         mf_stop                           ,       //mfc0阻塞
    output        fs_ready_go                       ,
    output  reg   stop_fs_go                        ,
    output        regvalid
);
reg  [`BR_BUS_WD       -1:0] reg_br_bus             ;
wire [`BR_BUS_WD       -1:0] br_bus                 ;
wire            inst_sram_req_d                     ;
wire            fs_ex                               ;
reg             inst_sram_req                       ;
reg             fs_valid                            ;
wire            to_fs_valid_d                       ;
wire            fs_ready_go                         ;
wire            fs_allowin                          ;
reg             to_fs_valid                         ;
reg             gjr                                 ;
reg  [31:0]     gj_pc                               ;      
wire [31:0]     seq_pc                              ;
wire [31:0]     nextpc                              ;
wire            br_taken_d                          ;
wire            br_taken                            ;
wire [31:0]     br_target                           ;
wire [31:0]     br_target_d                         ;
reg  [31:0]     reg_fs_inst                         ;
reg  [31:0]     fs_inst                             ;
reg  [31:0]     fs_pc                               ;
reg             regvalid                            ;
reg             br_bus_com                          ;
reg             bd_done                             ;
wire            pre_if_ready_go                     ;
assign br_target_d = fs_pc;
assign {br_taken,br_target,br_taken_d} = br_bus;


// pre-IF stage
always @(posedge clk) begin
    if (reset) begin
        to_fs_valid <= 0;
    end
    else if (gjr_posedge_nok | eret_flush) begin
        to_fs_valid <= 0;
    end
    else if (inst_sram_data_ok) begin
        to_fs_valid <= 1;
    end
    else if (inst_sram_req_d) begin
        to_fs_valid <= 0;
    end
    if (br_stall) begin
        to_fs_valid <= 0;
    end
end
//lalalalala lab10 guo_bu_liao
assign seq_pc       = fs_pc + 3'h4;

assign nextpc       =       gjr ? gj_pc : 
                                (br_taken & fs_valid)     ?   br_target:
                                    seq_pc; 
assign pre_if_ready_go  =   inst_sram_req_d & inst_sram_addr_ok & ~br_stall;
// IF stage

assign fs_ready_go    = (inst_sram_data_ok | (ds_allowin & regvalid)) & ~reg_wb_ex3;
assign fs_allowin     = (!fs_valid || fs_ready_go && ds_allowin)&&~gjr_posedge_nok;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;   
// assign to_fs_valid_d = to_fs_valid | inst_sram_data_ok;
assign to_fs_valid_d = to_fs_valid | inst_sram_data_ok;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin & ~wb_ex & ~eret_flush & ~reg_wb_ex) begin
        fs_valid <= to_fs_valid_d;
    end
    else if (wb_ex) begin
        fs_valid <= 1'b0;
    end
    else if (eret_flush) begin
        fs_valid <= 1'b0;
    end
    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid_d && fs_allowin && ~reg_wb_ex) begin      ////////////////////////////////////
        fs_pc <= nextpc;
    end
end

always @(posedge clk) begin
    if (reset) begin
        reg_br_bus <= 0;
        br_bus_com <= 0;
        bd_done <= 0;
    end
    
    else if (pre_if_ready_go & fs_allowin) begin
        br_bus_com <= 0;
    end
    else if (ds_ready_go & es_allowin & br_bus_d[0]) begin
        br_bus_com <= 1;
        bd_done <= 0;
        reg_br_bus <= br_bus_d;
    end
    else if (fs_to_ds_valid && ds_allowin) begin
        br_bus_com <= 0;
    end
    if (br_bus_com & fs_ready_go) begin
        bd_done <= 1;
    end
end


always @(posedge clk) begin
    if (reset) begin
        regvalid <= 0;
    end
    if (~ds_allowin && fs_ready_go) begin
        reg_fs_inst <= fs_inst;
        regvalid <=1;
    end
    else if (ds_allowin && regvalid) begin
        regvalid <= 0;
    end
end

assign fs_to_ds_bus = {br_taken_d,
                       br_target_d,
                       fs_ex    ,   
                       fs_inst  ,
                       fs_pc        };
reg data_alok;
always @(posedge clk) begin
    if (reset) begin
        data_alok <= 0;
    end
    else if (inst_sram_req_d & inst_sram_addr_ok) begin
        data_alok <= 1;
    end
    else if (inst_sram_data_ok) begin
        data_alok <= 0;
    end
end
reg gjr_posedge_nok;   //记录gjr抬升还在datalok时
always @(posedge clk) begin
    if (reset) begin
        gjr<=1'b0;
        gjr_posedge_nok <= 0;
    end
    if (wb_ex & ~eret_flush  & data_alok) begin
        gjr<=1'b1;
        gj_pc<=32'hbfc00380;
        gjr_posedge_nok <= 1;
    end
    else if (wb_ex & ~eret_flush) begin
        gjr<=1'b1;
        gj_pc<=32'hbfc00380;
    end

    else if (eret_flush) begin
        gjr<=1'b1;
        gj_pc<= ws_pc_send;
    end
    else if (inst_sram_data_ok & ~reg_wb_ex & ~gjr_posedge_nok) begin
        gjr<=1'b0;
    end
    if (inst_sram_data_ok) begin
        gjr_posedge_nok <= 0;
    end
end


reg reg_wb_ex3;
reg reg_wb_ex;
always @(posedge clk) begin
    if (reset) begin
        reg_wb_ex3 <= 0;
    end
    if (wb_ex & ~to_fs_valid) begin
        reg_wb_ex3 <= 1;
    end
    if (inst_sram_req_d & inst_sram_addr_ok) begin
        reg_wb_ex3 <= 0;
    end
end
always @(posedge clk) begin
    if (reset) begin
        reg_wb_ex <= 0;
    end
    else if (eret_flush & ~to_fs_valid_d) begin
        reg_wb_ex <= 1;
    end
    else if (~fs_allowin & ~fs_ready_go & eret_flush) begin
        reg_wb_ex <= 1;
    end
    if (inst_sram_data_ok) begin
        reg_wb_ex <= 0;
    end
end

reg stop_fs_go;
always @(posedge clk) begin
    if (reset) begin
        stop_fs_go <= 0;
    end
    if (reg_wb_ex) begin
        stop_fs_go <= 1;
    end
    else if (fs_ready_go) begin
        stop_fs_go <= 0;
    end
end
//stop_fs_go

assign br_bus =         br_bus_com ?   bd_done ? br_bus_d : reg_br_bus: 
                                br_bus_d;

assign inst_sram_req_d =  inst_sram_req & ~br_stall & ~wb_ex & ~mf_stop;
always @(posedge clk) begin
    if (reset) begin
        inst_sram_req <= 1'b1;
    end
    else if (to_fs_valid_d && fs_allowin) begin
        inst_sram_req <= 1'b1;
    end
    else if (inst_sram_data_ok & gjr_posedge_nok) begin
        inst_sram_req <= 1'b1;
    end
    if (inst_sram_req_d && inst_sram_addr_ok) begin
        inst_sram_req <= 1'b0;
    end
    
end

assign inst_sram_wr     = 1'b0;
assign inst_sram_size   = 2'b10;
assign inst_sram_wstrb  = 4'b1111;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;


always @(posedge clk) begin
    if (reset) begin
        fs_inst <= 0;
    end
    else if (inst_sram_data_ok) begin
        fs_inst <= inst_sram_rdata;
    end
    if (wb_ex) begin
        fs_inst <= 0;
    end
end

assign fs_ex = (fs_pc[1:0] != 2'b00);
endmodule
