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
    output        data_sram_en   ,
    output [ 3:0] data_sram_wen  ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata,
    output        es_valid_r,
    output [4:0]  es_to_ds_dest,
    output        es_we_r,
    output [31:0] es_fw_send,
    output        es_send_ready,
    output        div_stop
     
);
reg  [31:0] HI;
reg  [31:0] LO;
reg         es_valid        ;
wire        es_ready_go     ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
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
wire [31:0] es_rs_value     ;
wire [31:0] es_rt_value     ;
wire [31:0] es_pc           ;
assign {es_alu_op       ,  //144:125
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

assign es_fw_send=data_sram_addr;
assign es_send_ready=~es_res_from_mem;

assign es_res_from_mem = es_load_op;
assign es_to_ms_bus = {es_res_from_mem,  //70:70
                       es_gr_we       ,  //69:69
                       es_dest        ,  //68:64
                       es_alu_result_d  ,  //63:32
                       es_pc             //31:0
                      };

assign es_ready_go    = div_stop?0:1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
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

assign data_sram_en    = 1'b1;
assign data_sram_wen   = es_mem_we&&es_valid ? 4'hf : 4'h0;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_rt_value;


assign es_alu_result_d   = es_alu_op[16]? HI:
                             es_alu_op[17]? LO:
                                 es_alu_result;
//assign es_gr_we=~(es_alu_op[14]|es_alu_op[15]);
always @(posedge clk) begin 
     if(es_alu_op[12]|es_alu_op[13])   begin
         HI<=es_alu_result;
         LO<=es_alu_result2;
     end
     else if (es_alu_op[14]) begin
         HI<=es_rs_value;
         
     end
     else if (es_alu_op[15]) begin
         LO<=es_rs_value;
         
     end
     else if (result_valid) begin
         HI<=es_alu_result2;
         LO<=es_alu_result;
     end
     else if (result_valid_n) begin
         HI<=es_alu_result2;
         LO<=es_alu_result;
     end
    end
assign div_stop=~result_ready;

endmodule
