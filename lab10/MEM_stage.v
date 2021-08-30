`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    output [31:0] reg              reg_data_sram_rdata,  //~ws_allowin & ms_ready_go
    output [31:0]                  ms_wf_send,
    input  [31:0]                  data_sram_rdata,
    output [4:0]                   ms_dest,
    output                         ms_valid,
    output                         ms_gr_we,
    output                         mz_ex,
    output                         ms_inst_mfc0,
    output                         reg_valid,            //reg_data_sram_rdata
    input                          data_sram_data_ok,
    input                          wb_ex,
    input                          eret_flush,
    input                          es_ready_go
);
reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r  ;
wire [31:0] ms_final_result_new             ;
wire [31:0] ms_data_sram_addr               ;
wire [31:0] ms_final_result                 ;
wire [31:0] br_target_send                  ;
wire [31:0] ms_alu_result                   ;
wire [31:0] ms_rt_value                     ;
wire [31:0] ms_wf_send                      ;
wire [31:0] mem_result                      ;
wire [31:0] sp_result                       ;
wire [31:0] ms_pc                           ;
wire [15:0] twobit_result                   ;
wire [ 7:0] cp0_addr                        ;
wire [ 7:0] onebit_result                   ;
wire [ 4:0] ms_dest                         ;
wire [ 3:0] ms_sele_bit                     ;
wire [ 1:0] ms_write_bit                    ;
wire [ 1:0] ms_sp_op                        ;
wire [ 1:0] break_syscall_op                ;
wire        es_ex                           ;
wire        ds_ex                           ;
wire        fs_ex                           ;
wire        ms_ex                           ;
wire        ms_ready_go                     ;
wire        eq_stop                         ;
wire        ms_res_from_mem                 ;
wire        ms_gr_we                        ;
wire        op_mtc0                         ;
wire        op_slw                          ; 
wire        inst_sw                         ;
wire        ms_inst_mfc0                    ;
wire        br_taken_send                   ;
wire        inst_eret                       ;
wire        ms_mem_we                       ;
wire        data_ok_go_d                    ;
reg         ms_valid                        ;
reg         reg_valid                       ;
assign {ms_mem_we           ,   //195:195
        eq_stop             ,   //194:194
        inst_eret           ,   //193:193
        br_taken_send       ,   //192:192
        br_target_send      ,   //191:160
        ms_inst_mfc0        ,   //159:159
        cp0_addr            ,   //158:151
        inst_sw             ,   //150:150
        op_slw              ,   //149:149
        break_syscall_op    ,   //148:147
        fs_ex               ,   //146:146
        ds_ex               ,   //145:145
        op_mtc0             ,   //144:144
        es_ex               ,   //143:143
        ms_write_bit        ,   //142:141
        ms_rt_value         ,   //140:109
        ms_sp_op            ,   //108:107
        ms_data_sram_addr   ,   //106:75  无用
        ms_sele_bit         ,   //74:71
        ms_res_from_mem     ,   //70:70
        ms_gr_we            ,   //69:69
        ms_dest             ,   //68:64
        ms_alu_result       ,   //63:32
        ms_pc                   //31:0
       } = es_to_ms_bus_r;



assign ms_to_ws_bus = {eq_stop          ,  //187:187
                       ms_alu_result    ,  //186:155
                       inst_eret        ,  //154:154
                       br_taken_send    ,  //153:153
                       br_target_send   ,  //152:121
                       ms_inst_mfc0     ,  //120:120
                       cp0_addr         ,  //119:112
                       ms_rt_value      ,  //111::80
                       ms_write_bit[0]  ,  //79:79
                       inst_sw          ,  //78:78
                       op_slw           ,  //77:77
                       break_syscall_op ,  //76:75
                       fs_ex            ,  //74:74
                       ds_ex            ,  //73:73
                       es_ex            ,  //72:72
                       op_mtc0          ,  //71:71
                       ms_ex            ,  //70:70
                       ms_gr_we         ,  //69:69
                       ms_dest          ,  //68:64
                       ms_final_result  ,  //63:32
                       ms_pc               //31:0
                      };

assign ms_wf_send = ms_final_result;                        //不知道为啥换不了
assign data_ok_go_d = data_ok_go | data_sram_data_ok;       //data_ok(包括)  ---- 下一个pc
reg data_ok_go;
always @(posedge clk) begin
    if (reset) begin
        data_ok_go <= 0;
    end
    if (data_sram_data_ok) begin
        data_ok_go <= 1;
    end
    if (es_to_ms_valid && ms_allowin) begin
        data_ok_go <= 0;
    end
end
//需要data_sram时取决与data_ok
assign ms_ready_go    = ms_res_from_mem ? data_sram_data_ok : 1'b1;             
//需要data_sram时allowin还需要再data_ok之后才能置1
assign ms_allowin     =(ms_mem_we | ms_res_from_mem) ? !ms_valid || ms_ready_go && ws_allowin && data_ok_go_d : !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (wb_ex | eret_flush) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin & ~wb_ex & ~eret_flush) begin
        ms_valid <= es_to_ms_valid;
    end
    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  = es_to_ms_bus;
    end
end

always @(posedge clk) begin
    if (reset) begin
        reg_valid <= 0;
    end
    if (~ws_allowin & ms_ready_go) begin
        reg_data_sram_rdata <=ms_final_result;
        reg_valid <= 1;
    end
    else if (~(~ws_allowin & ms_ready_go) | (wb_ex & ~ms_allowin & es_ready_go)) begin
        reg_valid <= 0;
    end
end
assign mem_result = data_sram_rdata;

assign onebit_result =      ({8{ms_alu_result[1:0] == 2'b00}} & mem_result[7:0])
                        |   ({8{ms_alu_result[1:0] == 2'b01}} & mem_result[15:8])
                        |   ({8{ms_alu_result[1:0] == 2'b10}} & mem_result[23:16])
                        |   ({8{ms_alu_result[1:0] == 2'b11}} & mem_result[31:24]);

assign twobit_result =      ({16{ms_alu_result[1:0] == 2'b00}} & mem_result[15:0])
                        |   ({16{ms_alu_result[1:0] == 2'b10}} & mem_result[31:16]);

assign ms_final_result_new = ms_sele_bit[0] ? {{24{onebit_result[7]}}, onebit_result[7:0]} : 
                                ms_sele_bit[1] ? {{24{1'b0}}, onebit_result[7:0]}   :   
                                    ms_sele_bit[2] ? {{16{twobit_result[15]}}, twobit_result[15:0]} :
                                        ms_sele_bit[3] ? {{16{1'b0}}, twobit_result[15:0]}:0;
 
assign sp_result    =   {32{ms_sp_op[0]}} & {32{ms_alu_result[1:0] == 2'b00}} & {mem_result[7:0],ms_rt_value[23:0]}
                    |   {32{ms_sp_op[0]}} & {32{ms_alu_result[1:0] == 2'b01}} & {mem_result[15:0],ms_rt_value[15:0]}
                    |   {32{ms_sp_op[0]}} & {32{ms_alu_result[1:0] == 2'b10}} & {mem_result[23:0],ms_rt_value[7:0]}
                    |   {32{ms_sp_op[0]}} & {32{ms_alu_result[1:0] == 2'b11}} & {mem_result[31:0]}
                    |   {32{ms_sp_op[1]}} & {32{ms_alu_result[1:0] == 2'b00}} & {mem_result[31:0]}
                    |   {32{ms_sp_op[1]}} & {32{ms_alu_result[1:0] == 2'b01}} & {ms_rt_value[31:24],mem_result[31:8]}
                    |   {32{ms_sp_op[1]}} & {32{ms_alu_result[1:0] == 2'b10}} & {ms_rt_value[31:16],mem_result[31:16]}
                    |   {32{ms_sp_op[1]}} & {32{ms_alu_result[1:0] == 2'b11}} & {ms_rt_value[31:8],mem_result[31:24]};

assign ms_final_result = ms_res_from_mem ?      (ms_sele_bit != 0)  ?   ms_final_result_new 
                                            :   (ms_sp_op != 0)     ?   sp_result
                                            :   mem_result
                                            :   ms_alu_result;

assign ms_ex =      (ms_res_from_mem & (ms_sele_bit[3:2] != 0) & ms_alu_result[0] !=1'b0)
                |   (ms_res_from_mem & (ms_write_bit[0] == 1'b1) & ms_alu_result[0] !=1'b0);

assign mz_ex =ms_valid & (ms_ex | fs_ex | ds_ex | es_ex | inst_eret);
endmodule
