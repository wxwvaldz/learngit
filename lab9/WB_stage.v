

`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    output        ws_valid_r,
    output [4:0]  ws_to_ds_dest,
    output        ws_we_r,
    output [31:0] ws_wf_send,
    output        wb_ex,
    output        wz_ex,
    output        ws_inst_mfc0,
    output        eret_flush,
    output [31:0] ws_pc_send_out,
    output        eq_stop
);

// reg         eret_flush_r;
wire        eq_stop_d;
wire        eq_stop;
wire        gj;
wire        count_eq_compare;  
wire        c0_status_exl;
wire        c0_cause_ti;
wire [31:0] wb_badvaddr;
wire [31:0] c0_wdata;
wire [31:0] ws_pc_send;
wire [31:0] ws_pc_send_out;
wire [31:0] c0_rdata;
wire [31:0] ws_rt_value;
wire        inst_sh;
wire        inst_sw;
wire [4:0]  wb_excode;
wire [5:0]  ext_int_in;
wire        ms_ex;
wire        es_ex;
wire        ds_ex;
wire        fs_ex;
wire        wz_ex;
wire        op_mtc0;
// wire        wb_ex;
wire [1:0]  break_syscall_op;
wire        mtc0_we;
wire        op_slw;
reg         ws_valid;
wire        ws_ready_go;
wire        mtc0_en;
wire [31:0] c0_epc;
reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
wire [ 7:0] cp0_addr;
wire [ 7:0] c0_addr;
// wire        ws_inst_mfc0;
wire [31:0] br_target_send;
wire        br_taken_send;
wire        inst_eret ;
wire [31:0] ms_alu_result;
assign {eq_stop_d           ,  //187:187
        ms_alu_result       ,  //186:155
        inst_eret           ,  //154:154
        br_taken_send       ,  //153:153
        br_target_send      ,  //152:121
        ws_inst_mfc0           ,  //120:120
        cp0_addr            ,  //119:112
        ws_rt_value         ,  //111::80
        inst_sh             ,  //79:79
        inst_sw             ,  //78:78
        op_slw              ,  //77:77
        break_syscall_op    ,  //76:75
        fs_ex               ,  //74:74
        ds_ex               ,  //73:73
        es_ex               ,  //72:72
        op_mtc0             ,  //71:71
        ms_ex               ,  //70:70
        ws_gr_we            ,  //69:69
        ws_dest             ,  //68:64
        ws_final_result     ,  //63:32
        ws_pc                  //31:0
       } = ms_to_ws_bus_r;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_valid_r=ws_valid;
assign ws_to_ds_dest=ws_dest;
assign ws_we_r=rf_we;

assign ws_wf_send=rf_wdata;


assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;

// always @(posedge clk) begin
//     if (reset) begin
//         eret_flush_r<=0;
//     end
//     if (inst_eret) begin
//         eret_flush_r<=1;
//     end
// end
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin & ~wb_ex & ~eret_flush) begin
        ws_valid <= ms_to_ws_valid;
    end
    else if (wb_ex) begin
        ws_valid <= 1'b0;
    end
    else if (eret_flush) begin
        ws_valid <= 1'b0;
    end
    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

assign rf_we    = ws_gr_we&&ws_valid&&~wb_ex;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_inst_mfc0 ? c0_rdata : ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_inst_mfc0 ? c0_rdata : ws_final_result;

CP0 CP0(
    .reset          (reset              ),
    .clk            (clk                ),
    .mtc0_we        (mtc0_we            ),
    .c0_addr        (c0_addr            ),
    .c0_wdata       (c0_wdata           ),
    .wb_ex          (wb_ex              ),
    .eret_flush     (eret_flush         ),
    .wb_bd          (wb_bd              ),
    .ext_int_in     (ext_int_in         ),
    .wb_excode      (wb_excode          ),
    .wb_pc          (ws_pc_send         ),
    .mtc0_en        (mtc0_en            ),
    .c0_rdata       (c0_rdata           ),
    .c0_epc         (c0_epc             ),
    .wb_badvaddr    (wb_badvaddr        ),
    .eq_stop    (eq_stop        ),
    .c0_status_exl  (c0_status_exl      )
);
// assign eq_stop = 
assign ws_pc_send_out = c0_epc;
assign eret_flush = inst_eret & ws_valid;
assign ws_pc_send =br_taken_send ? br_target_send : ws_pc;
assign wb_bd = br_taken_send;
assign mtc0_en = ws_valid && ws_inst_mfc0;
assign c0_addr = cp0_addr;
assign c0_wdata = ws_rt_value;
assign wb_ex = ws_valid & (fs_ex | ds_ex | es_ex | ms_ex | eq_stop_d) & ~c0_status_exl;
assign wz_ex = ws_valid & (fs_ex | ds_ex | es_ex | ms_ex | eq_stop_d);
assign mtc0_we = ws_valid && op_mtc0 && !wb_ex;
// assign ext_int_in = {{count_eq_compare & gj},{(fs_ex & break_syscall_op[1:0] == 0)},{(fs_ex & break_syscall_op[1] == 1)},{(fs_ex & break_syscall_op[0] == 1)},{(es_ex & (op_slw == 0))},{(ms_ex | (es_ex & (op_slw != 0)))}};
assign ext_int_in = 6'b0;
assign wb_excode =      {5{es_ex & (op_slw == 0)}} & {5'b01100}
                    |   {5{ds_ex & (break_syscall_op == 0)}} & {5'b01010}
                    |   {5{ds_ex & (break_syscall_op[1] == 1'b1)}} & {5'b01001}
                    |   {5{ds_ex & (break_syscall_op[0] == 1'b1)}} & {5'b01000}
                    |   {5{eq_stop_d}} & {5'b00000}
                    |   {5{(es_ex & inst_sw) | (ms_ex & inst_sh)}} & {5'b00101}
                    |   {5{(fs_ex) | (es_ex & op_slw != 0 & inst_sw == 0) | (ms_ex & inst_sh == 0)}} & {5'b00100};
assign wb_badvaddr =    ({32{fs_ex}} & ws_pc)
                    |   ({32{(es_ex & op_slw != 0 & inst_sw == 0)}} & ms_alu_result)
                    |   ({32{(ms_ex & inst_sh == 0)}} & ms_alu_result) 
                    |   ({32{(es_ex & inst_sw) | (ms_ex & inst_sh)}} & ms_alu_result);
endmodule
