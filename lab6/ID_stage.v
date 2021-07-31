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
    input                          es_send_ready
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

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];

wire [31:0] ds_inst;
(*mark_debug = "true"*) wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

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

assign ds_to_es_bus = {alu_op           ,  //144:125
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

assign ds_ready_go=     (es_com|ms_com|ws_com)?
                            ((ws_com_rs|ws_com_rt|ms_com_rs|ms_com_rt|(es_com_rs|es_com_rt&es_send_ready))&(must_stop==0))?
                                1'b1:
                                    1'b0 :1'b1;

assign ds_toes_stop=((rs==es_to_ds_dest|rt==es_to_ds_dest)&es_we_r&es_valid_r);
assign ds_toms_stop=((rs==ms_to_ds_dest|rt==ms_to_ds_dest)&ms_we_r&ms_valid_r);
assign ds_tows_stop=((rs==es_to_ds_dest|rt==es_to_ds_dest)&ws_we_r&ws_valid_r);

assign rs_value=must_stop? rf_rdata1:
                    es_com_rs?es_send_ready?es_fw_send:rf_rdata1 :
                        ms_com_rs?ms_wf_send:
                            ws_com_rs?ws_wf_send:rf_rdata1;

assign rt_value=must_stop? rf_rdata2:
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


assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;
always @(posedge clk) begin
if (reset) begin
        ds_valid <= 1'b0;
        end
        else if (ds_allowin) begin
        ds_valid <=fs_to_ds_valid;
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

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));


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





assign alu_op[ 0] = inst_addi | inst_add | inst_addu | inst_addiu | inst_lw | inst_sw | inst_jal;
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


assign load_op          = inst_lw    | inst_sw;
assign src1_is_sa       = inst_sll   | inst_srl | inst_sra;
assign src1_is_pc       = inst_jal;
assign src2_is_imm      = inst_sltiu | inst_slti | inst_addi | inst_addiu | inst_lui | inst_lw | inst_sw;
assign src2_is_imm_0    = inst_andi | inst_xori | inst_ori;
assign src2_is_8        = inst_jal;
assign res_from_mem     = inst_lw;
assign dst_is_r31       = inst_jal;
assign dst_is_rt        = inst_xori | inst_ori | inst_andi | inst_sltiu | inst_slti | inst_addi | inst_addiu | inst_lui | inst_lw;
assign gr_we            = ~inst_sw & ~inst_beq & ~inst_bne & ~inst_jr & ~inst_mthi & ~inst_mtlo;
assign mem_we           = inst_sw;

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

assign rs_eq_rt = (rs_value == rt_value);
assign br_taken = (   inst_beq  &&  rs_eq_rt
                   || inst_bne  && !rs_eq_rt
                   || inst_jal
                   || inst_jr
                  ) && ds_valid;
assign br_target = (inst_beq || inst_bne) ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr)              ? rs_value :
                  /*inst_jal*/              {fs_pc[31:28], jidx[25:0], 2'b0};

endmodule