`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    input  [4:0]                        es_to_ds_dest ,
    input  [4:0]                        ms_to_ds_dest ,
    input  [4:0]                        ws_to_ds_dest ,
    input                          es_valid_r    ,
    input                          ms_valid_r    ,
    input                          ws_valid_r    ,
    input                          es_we_r,
    input                          ms_we_r,
    input                          ws_we_r,
    input    [31:0]                ws_wf_send,
    input    [31:0]                ms_wf_send,
    input    [31:0]                es_fw_send,
    input                          es_send_ready,
    input                          wb_ex,
    input                          es_inst_mfc0,
    input                          ms_inst_mfc0,
    input                          ws_inst_mfc0,
    input         eret_flush
);
wire es_com;
wire ms_com;
wire ws_com;
wire es_com_rs;
wire ms_com_rs;
wire ws_com_rs;
wire es_com_rt;
wire ms_com_rt;
wire ws_com_rt;
wire must_stop;
wire ds_toes_stop;
wire ds_toms_stop;
wire ds_tows_stop;
wire [31:0] br_target_send;
wire        ds_fs_ex;
reg         ds_valid   ;
wire        ds_ready_go;
wire        ds_ex;
wire        br_taken_send;
wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
(*mark_debug = "true"*) wire [31:0] ds_pc  ;
assign {br_taken_send,
        br_target_send,
        ds_fs_ex,
        ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;
wire        es_stop;
wire        ms_stop;
wire        ws_stop;
wire        br_taken;
wire [31:0] br_target;
wire        rs_zero;
wire        rt_zero;
wire [1:0]  break_syscall_op;
wire [1:0]  write_bit;
wire [3:0]  sele_bit;
wire [19:0] alu_op;
wire        load_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm_0;
wire        src2_is_imm;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;
wire [1:0]  sp_op;
wire [1:0]  swlr_op;
wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
 
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;
wire [ 7:0] cp0_addr;

wire [4:0]  inst_bus;
wire        inst_break;
wire        inst_syscall;
wire        inst_eret;
wire        inst_mfc0;  
wire        inst_mtc0;
wire        inst_swr;
wire        inst_swl;  
wire        inst_lwr;
wire        inst_lwl;  
wire        inst_sh;
wire        inst_sb;
wire        inst_lhu;
wire        inst_lh;
wire        inst_lbu;
wire        inst_lb;
wire        inst_jalr;
wire        inst_bgezal;
wire        inst_bltzal;
wire        inst_j;    
wire        inst_bltz;
wire        inst_blez;
wire        inst_bgtz;
wire        inst_bgez;
wire        inst_divu;
wire        inst_div;
wire        inst_mflo;
wire        inst_mfhi;
wire        inst_mtlo;    
wire        inst_mthi;
wire        inst_multu;    
wire        inst_mult;
wire        inst_srav;
wire        inst_srlv;      
wire        inst_sllv;
wire        inst_xori;
wire        inst_ori;
wire        inst_andi;
wire        inst_sltiu;
wire        inst_slti; 
wire        inst_sub;
wire        inst_addi;  
wire        inst_add;
wire        inst_addu;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_addiu;
wire        inst_lui;
wire        inst_lw;
wire        inst_sw;
wire        inst_beq;
wire        inst_bne;
wire        inst_jal;
wire        inst_jr;
wire        dst_is_r31;  
wire        dst_is_rt;   
wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;

assign br_bus       = {br_taken,br_target};

assign ds_to_es_bus = {inst_eret        ,  //207:207
                       br_taken_send    ,  //206:206
                       br_target_send   ,  //205:174
                       inst_mfc0        ,  //173:173
                       cp0_addr         ,  //172:165
                       break_syscall_op ,  //164:163
                       ds_fs_ex         ,  //162:162
                       inst_mtc0        ,  //161:161
                       ds_ex            ,  //160:160
                       inst_bus         ,  //159:155
                       swlr_op          ,  //154:153
                       sp_op            ,  //152:151
                       write_bit        ,  //150:149
                       sele_bit         ,  //148:145
                       alu_op           ,  //144:125
                       load_op          ,  //124:124
                       src1_is_sa       ,  //123:123
                       src1_is_pc       ,  //122:122
                       src2_is_imm_0    ,  //121:121
                       src2_is_imm      ,  //120:120
                       src2_is_8        ,  //119:119
                       gr_we            ,  //118:118
                       mem_we           ,  //117:117
                       dest             ,  //116:112
                       imm              ,  //111:96
                       rs_value         ,  //95 :64
                       rt_value         ,  //63 :32
                       ds_pc               //31 :0
                      };

assign must_stop=(es_com_rs&~es_send_ready)|(es_com_rt&~es_send_ready);

assign ds_ready_go=(es_stop | ms_stop | ws_stop) ? 1'b0 :     
                        (es_com|ms_com|ws_com)?
                            ((ws_com_rs|ws_com_rt|ms_com_rs|ms_com_rt|(es_com_rs|es_com_rt&es_send_ready))&(must_stop==0))?
                                1'b1:
                                    1'b0 :1'b1;

assign ds_toes_stop=((rs==es_to_ds_dest|rt==es_to_ds_dest)&es_we_r&es_valid_r);
assign ds_toms_stop=((rs==ms_to_ds_dest|rt==ms_to_ds_dest)&ms_we_r&ms_valid_r);
assign ds_tows_stop=((rs==es_to_ds_dest|rt==es_to_ds_dest)&ws_we_r&ws_valid_r);

assign rs_zero = rs == 0;
assign rt_zero = rt == 0;


assign rs_value=must_stop? rf_rdata1:
                    rs_zero ? rf_rdata1:
                        es_com_rs?es_send_ready?es_fw_send:rf_rdata1 :
                            ms_com_rs?ms_wf_send:
                                ws_com_rs?ws_wf_send:rf_rdata1;

assign rt_value=must_stop? rf_rdata2:
                    rt_zero ? rf_rdata2:
                        es_com_rt?es_send_ready?es_fw_send:rf_rdata2 :
                            ms_com_rt?ms_wf_send:
                                ws_com_rt?ws_wf_send:rf_rdata2;

assign ws_com_rs=ws_valid_r&(rs==ws_to_ds_dest)&ws_we_r;
assign ws_com_rt=ws_valid_r&(rt==ws_to_ds_dest)&ws_we_r;
assign ms_com_rs=ms_valid_r&(rs==ms_to_ds_dest)&ms_we_r;
assign ms_com_rt=ms_valid_r&(rt==ms_to_ds_dest)&ms_we_r;
assign es_com_rs=es_valid_r&(rs==es_to_ds_dest)&es_we_r;
assign es_com_rt=es_valid_r&(rt==es_to_ds_dest)&es_we_r;
assign es_com=es_valid_r&(rs==es_to_ds_dest|rt==es_to_ds_dest)&es_we_r;
assign ms_com=ms_valid_r&(rs==ms_to_ds_dest|rt==ms_to_ds_dest)&ms_we_r;
assign ws_com=ws_valid_r&(rs==ws_to_ds_dest|rt==ws_to_ds_dest)&ws_we_r;

assign es_stop=es_valid_r&(rs==es_to_ds_dest|rt==es_to_ds_dest)&es_we_r&es_inst_mfc0;
assign ms_stop=ms_valid_r&(rs==ms_to_ds_dest|rt==ms_to_ds_dest)&ms_we_r&ms_inst_mfc0;
assign ws_stop=ws_valid_r&(rs==ws_to_ds_dest|rt==ws_to_ds_dest)&ws_we_r&ws_inst_mfc0;

assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
if (reset) begin
        ds_valid <= 1'b0;
        end
        else if (ds_allowin & ~wb_ex & ~eret_flush) begin
        ds_valid <=fs_to_ds_valid;
        end
        else if (wb_ex) begin
        ds_valid <=1'b0;
        end
        else if (eret_flush) begin
        ds_valid <= 1'b0;
    end
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];
assign cp0_addr = {ds_inst[15:11],ds_inst[2:0]};

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_break  = op_d[6'h00] & func_d[6'h0d];
assign inst_syscall= op_d[6'h00] & func_d[6'h0c];
assign inst_eret   = op_d[6'h10] & ds_inst[25:25] & (ds_inst[24:6] == 0) & func_d[6'h18];
assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00] & (ds_inst[10:3] == 0);
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04] & (ds_inst[10:3] == 0);
assign inst_swr    = op_d[6'h2e]; 
assign inst_swl    = op_d[6'h2a]; 
assign inst_lwr    = op_d[6'h26];
assign inst_lwl    = op_d[6'h22];
assign inst_sh     = op_d[6'h29];
assign inst_sb     = op_d[6'h28];
assign inst_lhu    = op_d[6'h25];
assign inst_lh     = op_d[6'h21];
assign inst_lbu    = op_d[6'h24];
assign inst_lb     = op_d[6'h20];
assign inst_jalr   = op_d[6'h00] & rt_d[5'h00] & sa_d[5'h00] & func_d[6'h09];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_j      = op_d[6'h02];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & sa_d[5'h00] & rd_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & sa_d[5'h00] & rd_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & sa_d[5'h00] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & sa_d[5'h00] & rs_d[5'h00] & rt_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & sa_d[5'h00] & rd_d[5'h00] & rt_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & sa_d[5'h00] & rd_d[5'h00] & rt_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & sa_d[5'h00] & rd_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & sa_d[5'h00] & rd_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_xori   = op_d[6'h0e];
assign inst_ori    = op_d[6'h0d];
assign inst_andi   = op_d[6'h0c];
assign inst_sltiu  = op_d[6'h0b];
assign inst_slti   = op_d[6'h0a];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_addiu  = op_d[6'h09];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_lw     = op_d[6'h23];
assign inst_sw     = op_d[6'h2b];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];





assign alu_op[ 0] = inst_addi | inst_add | inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal | inst_lb | inst_lbu | inst_bltzal | inst_bgezal | inst_jalr | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lwl | inst_lwr | inst_swl | inst_swr;
assign alu_op[ 1] = inst_subu | inst_sub;
assign alu_op[ 2] = inst_slt  | inst_slti;
assign alu_op[ 3] = inst_sltiu | inst_sltu;
assign alu_op[ 4] = inst_andi | inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_ori | inst_or;
assign alu_op[ 7] = inst_xori | inst_xor;
assign alu_op[ 8] = inst_sllv | inst_sll;
assign alu_op[ 9] = inst_srlv | inst_srl;
assign alu_op[10] = inst_srav | inst_sra;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_mult;
assign alu_op[13] = inst_multu;
assign alu_op[14] = inst_mthi;
assign alu_op[15] = inst_mtlo;
assign alu_op[16] = inst_mfhi;
assign alu_op[17] = inst_mflo;
assign alu_op[18] = inst_div;
assign alu_op[19] = inst_divu;

assign break_syscall_op = {inst_break,inst_syscall};
assign inst_bus         = {inst_add,inst_addi,inst_sub,inst_lw,inst_sw};
assign swlr_op          = {inst_swr,inst_swl};
assign sp_op            = {inst_lwr,inst_lwl};
assign write_bit        = {inst_sb,inst_sh};
assign sele_bit         = {inst_lhu,inst_lh,inst_lbu,inst_lb};
assign load_op          = inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lwl | inst_lwr | inst_swl | inst_swr;
assign src1_is_sa       = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc       = inst_jal | inst_bltzal | inst_bgezal | inst_jalr;
assign src2_is_imm      = inst_sltiu | inst_slti | inst_addi | inst_addiu | inst_lui | inst_lw | inst_sw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lwl | inst_lwr | inst_swl | inst_swr;
assign src2_is_imm_0    = inst_andi | inst_xori | inst_ori;
assign src2_is_8        = inst_jal | inst_bltzal | inst_bgezal | inst_jalr;
//assign res_from_mem     = inst_lw | inst_lb | inst_lbu;
assign dst_is_r31       = inst_jal | inst_bltzal | inst_bgezal;
assign dst_is_rt        = inst_xori | inst_ori | inst_andi | inst_sltiu | inst_slti | inst_addi | inst_addiu | inst_lui | inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lwl | inst_lwr | inst_mfc0;
assign gr_we            = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr & ~inst_mthi & ~inst_mtlo & ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz &~inst_mult & ~inst_multu & ~inst_div & ~inst_divu & ~inst_j & ~inst_sb & ~inst_sh & ~inst_swl & ~inst_swr & ~inst_mtc0;
assign mem_we           = inst_sw | inst_sh | inst_sb | inst_swl | inst_swr;     //写数据ram

assign dest             = dst_is_r31 ? 5'd31 :
                        dst_is_rt  ? rt    : 
                                    rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

//assign rs_value = rf_rdata1;
//assign rt_value = rf_rdata2;
assign rs_mt_zero = ~rs_value[31] & (rs_value[30:0] != 31'b0);
assign rs_lt_zero = rs_value[31];
assign rs_eq_rt = (rs_value == rt_value);
assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
                   || inst_jal
                   || inst_j
                   || inst_jr
                   || inst_bgez     && (rs_mt_zero | (rs_value[31:0] == 32'b0) )
                   || inst_blez     && (rs_lt_zero | (rs_value[31:0] == 32'b0) )
                   || inst_bgtz     && rs_mt_zero
                   || inst_bltz     && rs_lt_zero
                   || inst_bltzal   && rs_lt_zero
                   || inst_bgezal   && (rs_mt_zero | (rs_value[31:0] == 32'b0) )
                   || inst_jalr
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_bltzal || inst_bgezal) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr)              ? rs_value :
                  /*inst_jal*/              {fs_pc[31:28], jidx[25:0], 2'b0};

assign ds_ex =  inst_break
            |   inst_syscall
            |   ~(inst_syscall | inst_eret | inst_mfc0 | inst_mtc0 | inst_swr | inst_swl | inst_lwr | inst_lwl | inst_sh | inst_sb | inst_lhu | inst_lh | inst_lbu | inst_lb | inst_jalr | inst_bgezal | inst_bltzal | inst_j | inst_bltz | inst_blez | inst_bgtz | inst_bgez | inst_divu | inst_div | inst_mflo | inst_mfhi | inst_mtlo | inst_mthi | inst_multu | inst_mult | inst_srav | inst_srlv | inst_sllv | inst_xori | inst_ori | inst_andi | inst_sltiu | inst_slti | inst_sub | inst_addi | inst_add | inst_addu | inst_subu | inst_slt | inst_sltu | inst_and | inst_or | inst_xor | inst_nor | inst_sll | inst_srl | inst_sra | inst_addiu | inst_lui | inst_lw | inst_sw | inst_beq | inst_bne | inst_jal | inst_jr);
endmodule