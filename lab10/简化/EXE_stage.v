`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data sram interface
    output [31:0]   data_sram_addr,
    output [31:0]   data_sram_wdata,
    input  [31:0]   data_sram_rdata, 
    output [31:0]   es_fw_send,
    output [ 4:0]   es_to_ds_dest,
    output [ 3:0]   data_sram_wstrb,
    output [ 1:0]   data_sram_size,
    output          data_sram_req_d,
    output          es_send_ready,
    output          es_inst_mfc0,
    output          data_sram_wr,
    output          es_ready_go,
    output          es_valid_r,
    output          req_ok_go_d，
    output          es_we_r,
    input           data_sram_addr_ok,
    input           data_sram_data_ok,
    input           eret_flush,
    input           mz_ex,
    input           wb_ex,
    input           wz_ex
);
reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
reg  [31:0] HI;
reg  [31:0] LO;
wire [31:0] br_target_send  ;
wire [31:0] es_rs_value     ;
wire [31:0] es_rt_value     ;
wire [31:0] es_pc           ;
reg         es_valid        ;
reg         data_sram_req;
wire        es_ds_ex;  
wire        es_ex;
wire        es_ready_go     ;
wire [1:0]  es_write_bit;
wire        es_stop;
wire [1:0]  es_swlr_op;
wire [1:0]  es_sp_op        ;
wire [3:0]  es_sele_bit     ;
wire [19:0] es_alu_op       ;
wire        es_load_op      ;
wire        es_src1_is_sa   ;  
wire        es_src1_is_pc   ;
wire        es_src2_is_imm  ; 
wire        es_src2_is_imm_0;  
wire        es_src2_is_8    ;
wire        es_gr_we        ;
wire        es_mem_we       ;
wire [ 4:0] es_dest         ;
wire [15:0] es_imm          ;
wire        es_inst_sw      ;
wire        es_inst_lw      ; 
wire        es_inst_sub     ;
wire        es_inst_add     ;
wire        es_inst_addi    ; 
wire        op_mtc0         ;
wire        fs_ex           ;
wire [1:0]  break_syscall_op;
wire        op_slw          ;  
wire [7:0]  cp0_addr        ;
wire        es_inst_mfc0    ;
wire        br_taken_send   ;
wire        inst_eret       ;
wire        eq_stop         ;
wire        data_sram_req_d ;
wire        req_ok_go_d     ;
assign {eq_stop         ,  //208:208
        inst_eret       ,  //207:207
        br_taken_send   ,  //206:206
        br_target_send  ,  //205:174
        es_inst_mfc0    ,  //173:173
        cp0_addr        ,  //172:165
        break_syscall_op,  //164:163
        fs_ex           ,  //162:162
        op_mtc0         ,  //161:161
        es_ds_ex        ,  //160:160
        es_inst_add     ,  //159:158
        es_inst_addi    ,  //158:158
        es_inst_sub     ,  //157:157
        es_inst_lw      ,  //156:156
        es_inst_sw      ,  //155:155
        es_swlr_op      ,  //154:153
        es_sp_op        ,  //152:151
        es_write_bit    ,  //150:149
        es_sele_bit     ,  //148:145
        es_alu_op       ,  //144:125
        es_load_op      ,  //124:124
        es_src1_is_sa   ,  //123:123
        es_src1_is_pc   ,  //122:122
        es_src2_is_imm_0,  //121:121
        es_src2_is_imm  ,  //120:120
        es_src2_is_8    ,  //119:119
        es_gr_we        ,  //118:118
        es_mem_we       ,  //117:117
        es_dest         ,  //116:112
        es_imm          ,  //111:96
        es_rs_value     ,  //95 :64
        es_rt_value     ,  //63 :32
        es_pc             //31 :0
       } = ds_to_es_bus_r;



wire [31:0] es_alu_src1      ;
wire [31:0] es_alu_src2      ;
wire [31:0] es_alu_result    ;
wire [31:0] es_alu_result2   ;
wire [31:0] es_alu_result_d  ;
wire        es_res_from_mem  ;

assign es_valid_r=es_valid;
assign es_to_ds_dest=es_dest;
assign es_we_r=es_gr_we;

assign es_fw_send=es_alu_result_d;
assign es_send_ready=~es_res_from_mem;

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_mem_we        ,  //195:195
                       eq_stop          ,  //194:194
                       inst_eret        ,  //193:193
                       br_taken_send    ,  //192:192
                       br_target_send   ,  //191:160
                       es_inst_mfc0     ,  //159:159
                       cp0_addr         ,  //158:151
                       es_inst_sw       ,  //150:150
                       op_slw           ,  //149:149
                       break_syscall_op ,  //148:147
                       fs_ex            ,  //146:146
                       es_ds_ex         ,  //145:145
                       op_mtc0          ,  //144:144
                       es_ex            ,  //143:143
                       es_write_bit     ,  //142:141
                       es_rt_value      ,  //140:109
                       es_sp_op         ,  //108:107
                       data_sram_addr   ,  //106:75
                       es_sele_bit      ,  //74:71
                       es_res_from_mem  ,  //70:70
                       es_gr_we         ,  //69:69
                       es_dest          ,  //68:64
                       es_alu_result_d  ,  //63:32
                       es_pc             //31:0
                      };
assign op_slw         = es_inst_sw | es_inst_lw;
assign es_ready_go    = (es_mem_we | es_load_op) ? (data_sram_req_d & data_sram_addr_ok) ? 1 : 0 : es_stop?1:0;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
assign es_stop = result_ready ? 1 :
                    es_alu_op[18] | es_alu_op[19] ? 0 : 1;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (wb_ex | eret_flush) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end
    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign es_alu_src1 = es_src1_is_sa      ? {27'b0, es_imm[10:6]} :
                     es_src1_is_pc      ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm_0   ? {{16{1'b0}}, es_imm[15:0]} :
                     es_src2_is_imm     ? {{16{es_imm[15]}}, es_imm[15:0]} :
                     es_src2_is_8       ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .reset          (reset              ),
    .clk            (clk                ),
    .alu_op         (es_alu_op          ),
    .alu_src1       (es_alu_src1        ),
    .alu_src2       (es_alu_src2        ),
    .alu_result     (es_alu_result      ),
    .alu_result2    (es_alu_result2     ),
    .div_ready      (div_ready          ),
    .result_ready   (result_ready       ),
    .result_valid   (result_valid       ),
    .result_valid_n (result_valid_n     )
    );

wire stop_w_exz;
reg stop_w_exz_d;
assign stop_w_exz = stop_w_exz_d | (mz_ex | wz_ex | eret_flush | es_ex);
always @(posedge clk) begin                                                         //实现长阻塞
    if (reset) begin
        stop_w_exz_d <= 0;
    end
    else if (mz_ex | wz_ex | eret_flush | es_ex) begin
        stop_w_exz_d <= 1;
    end
    if (ds_to_es_valid && es_allowin) begin
        stop_w_exz_d <= 0;
    end
end
wire data_sram_wen;
assign data_sram_wr = (es_load_op != 0 & es_mem_we == 0) ? 1'b0 : 1'b1;
assign data_sram_size =     {2{es_sp_op[1] | es_swlr_op[1]}} & {2{es_alu_result[1:0] == 2'b10}} & 2'b01
                        |   {2{es_sp_op[1] | es_swlr_op[1]}} & {2{es_alu_result[1:0] == 2'b01}} & 2'b10
                        |   {2{es_sp_op[1] | es_swlr_op[1]}} & {2{es_alu_result[1:0] == 2'b00}} & 2'b10
                        |   {2{es_sp_op[1] | es_swlr_op[1]}} & {2{es_alu_result[1:0] == 2'b11}} & 2'b00
                        |   {2{es_sele_bit[0] | es_sele_bit[1] | es_write_bit[1]}} & 2'b00
                        |   {2{es_sele_bit[2] | es_sele_bit[3] | es_write_bit[0]}} & 2'b01
                        |   {2{es_sp_op[0] | es_swlr_op[0]}} & {2{es_alu_result[1:0] == 2'b00}} & 2'b00
                        |   {2{es_sp_op[0] | es_swlr_op[0]}} & {2{es_alu_result[1:0] == 2'b01}} & 2'b01
                        |   {2{es_sp_op[0] | es_swlr_op[0]}} & {2{es_alu_result[1:0] == 2'b10}} & 2'b10
                        |   {2{es_sp_op[0] | es_swlr_op[0]}} & {2{es_alu_result[1:0] == 2'b11}} & 2'b10
                        |   {2{es_load_op != 0 & es_sele_bit == 0 & es_write_bit == 0 & es_sp_op == 0 & es_swlr_op == 0}} & 2'b10
                        |   {2{es_mem_we != 0 & es_write_bit == 0 & es_swlr_op == 0}} & 2'b10;
assign data_sram_wstrb =stop_w_exz ? 4'b0000 :
                            {4{{data_sram_size == 2'b00} & es_alu_result[1:0] == 2'b00}} & 4'b0001
                        |   {4{{data_sram_size == 2'b00} & es_alu_result[1:0] == 2'b01}} & 4'b0010
                        |   {4{{data_sram_size == 2'b00} & es_alu_result[1:0] == 2'b10}} & 4'b0100
                        |   {4{{data_sram_size == 2'b00} & es_alu_result[1:0] == 2'b11}} & 4'b1000
                        |   {4{{data_sram_size == 2'b01} & es_alu_result[1:0] == 2'b00}} & 4'b0011
                        |   {4{{data_sram_size == 2'b01} & es_alu_result[1:0] == 2'b01}} & 4'b0011
                        |   {4{{data_sram_size == 2'b01} & es_alu_result[1:0] == 2'b10}} & 4'b1100
                        |   {4{{data_sram_size == 2'b10} & es_alu_result[1:0] == 2'b10}} & 4'b0111
                        |   {4{{data_sram_size == 2'b10} & es_alu_result[1:0] == 2'b11}} & 4'b1111
                        |   {4{{data_sram_size == 2'b10} & es_alu_result[1:0] == 2'b00 & es_mem_we != 0 & es_write_bit == 0 & (es_swlr_op == 0 | es_swlr_op == 2'b10)}} & 4'b1111
                        |   {4{{data_sram_size == 2'b10} & es_alu_result[1:0] == 2'b00 & es_mem_we != 0 & es_write_bit != 0 & es_swlr_op != 0}} & 4'b0111
                        |   {4{{data_sram_size == 2'b10} & es_alu_result[1:0] == 2'b01}} & 4'b1110;
assign data_sram_addr = es_alu_result;
assign data_sram_wdata =    es_write_bit[1] ?       {4{es_rt_value[7:0]}} :
                            es_write_bit[0] ?       {2{es_rt_value[15:0]}} :
                            es_swlr_op[0]   ?       ({32{(es_alu_result[1:0] == 2'b00)}} & {24'b0,es_rt_value[31:24]})
                                                |   ({32{(es_alu_result[1:0] == 2'b01)}} & {16'b0,es_rt_value[31:16]})
                                                |   ({32{(es_alu_result[1:0] == 2'b10)}} & {8'b0,es_rt_value[31:8]})
                                                |   ({32{(es_alu_result[1:0] == 2'b11)}} & {es_rt_value[31:0]})     :
                            es_swlr_op[1]   ?       ({32{(es_alu_result[1:0] == 2'b00)}} & {es_rt_value[31:0]})
                                                |   ({32{(es_alu_result[1:0] == 2'b01)}} & {es_rt_value[23:0],8'b0})
                                                |   ({32{(es_alu_result[1:0] == 2'b10)}} & {es_rt_value[15:0],16'b0})
                                                |   ({32{(es_alu_result[1:0] == 2'b11)}} & {es_rt_value[7:0],24'b0})     :
                            es_rt_value;


// assign data_sram_wen   = (~eret_flush&~es_ex&~mz_ex&~wz_ex) ? es_mem_we&&es_valid ? (es_write_bit[0] | es_write_bit[1] | es_swlr_op[0] | es_swlr_op[1])? data_sram_wen_d  :    4'hf : 4'h0 : 4'h0;

// assign data_sram_wen_d   = ({4{es_write_bit[1]}} & {4{es_alu_result[1:0] == 2'b00}} & {4'b0001})
//                         | ({4{es_write_bit[1]}} & {4{es_alu_result[1:0] == 2'b01}} & {4'b0010})
//                         | ({4{es_write_bit[1]}} & {4{es_alu_result[1:0] == 2'b10}} & {4'b0100})
//                         | ({4{es_write_bit[1]}} & {4{es_alu_result[1:0] == 2'b11}} & {4'b1000})
//                         | ({4{es_write_bit[0]}} & {4{es_alu_result[1:0] == 2'b00}} & {4'b0011})
//                         | ({4{es_write_bit[0]}} & {4{es_alu_result[1:0] == 2'b10}} & {4'b1100})
//                         | ({4{es_swlr_op[0]}} & {4{es_alu_result[1:0] == 2'b00}} & {4'b0001})
//                         | ({4{es_swlr_op[0]}} & {4{es_alu_result[1:0] == 2'b01}} & {4'b0011})
//                         | ({4{es_swlr_op[0]}} & {4{es_alu_result[1:0] == 2'b10}} & {4'b0111})
//                         | ({4{es_swlr_op[0]}} & {4{es_alu_result[1:0] == 2'b11}} & {4'b1111})
//                         | ({4{es_swlr_op[1]}} & {4{es_alu_result[1:0] == 2'b00}} & {4'b1111})
//                         | ({4{es_swlr_op[1]}} & {4{es_alu_result[1:0] == 2'b01}} & {4'b1110})
//                         | ({4{es_swlr_op[1]}} & {4{es_alu_result[1:0] == 2'b10}} & {4'b1100})
//                         | ({4{es_swlr_op[1]}} & {4{es_alu_result[1:0] == 2'b11}} & {4'b1000});

assign es_alu_result_d   = es_alu_op[16]? HI:
                             es_alu_op[17]? LO:
                                 es_alu_result;

always @(posedge clk) begin 
     if((es_alu_op[12]|es_alu_op[13])&~mz_ex&~wz_ex&~eret_flush&~es_ex&~stop_w_exz&es_valid)   begin
         HI<=es_alu_result;
         LO<=es_alu_result2;
     end
     else if (es_alu_op[14]&~mz_ex&~wz_ex&~eret_flush&~es_ex&~stop_w_exz&es_valid) begin
         HI<=es_rs_value;
         
     end
     else if (es_alu_op[15]&~mz_ex&~wz_ex&~eret_flush&~es_ex&~stop_w_exz&es_valid) begin
         LO<=es_rs_value;
         
     end
     else if (result_valid&~mz_ex&~wz_ex&~eret_flush&~es_ex&~stop_w_exz&es_valid) begin
         HI<=es_alu_result2;
         LO<=es_alu_result;
     end
     else if (result_valid_n&~mz_ex&~wz_ex&~eret_flush&~es_ex&~stop_w_exz&es_valid) begin
         HI<=es_alu_result2;
         LO<=es_alu_result;
     end
    end


assign data_sram_req_d =data_sram_req;
assign req_ok_go_d = data_sram_data_ok | req_ok_go;
reg req_ok_go;
always @(posedge clk) begin                                               //握手-----data_ok(包括) ==0
    if (reset) begin
        req_ok_go <= 1;
    end
    else if (data_sram_req & data_sram_addr_ok) begin
        req_ok_go <= 0;
    end
    if (data_sram_data_ok) begin
        req_ok_go <= 1;
    end
end
always @(posedge clk) begin
    if (reset) begin
        data_sram_req <= 1'b0;
    end
    
    if (data_sram_req & data_sram_addr_ok) begin
        data_sram_req <= 1'b0;
    end
    else if ((es_mem_we | es_load_op) & es_valid & req_ok_go_d) begin
        data_sram_req <= 1'b1;
    end
end
assign es_ex =      (es_res_from_mem & (es_write_bit[0] == 1'b1) & data_sram_addr[0] !=1'b0)
                |   (es_inst_sw & (es_alu_result[1:0] != 2'b00))
                |   (es_inst_lw & (es_alu_result[1:0] != 2'b00))
                |   ((es_inst_add | es_inst_addi) & (es_alu_src1[31:31] == es_alu_src2[31:31]) & (es_alu_src1[31:31] != es_alu_result[31:31]))
                |   (es_inst_sub & (es_alu_src1[31:31] != es_alu_src2[31:31]) & (es_alu_src2[31:31] == es_alu_result[31:31]));
endmodule
