`include "mycpu.h"
module mycpu_top(
    input         clk,
    input         resetn,
    // inst sram interface
    output        inst_sram_req,            //请求信号
    output        inst_sram_wr,             //1为写请求
    output [ 1:0] inst_sram_size,           //请求传输地字节数
    output [ 3:0] inst_sram_wstrb,          //写请求地字节写使能
    output [31:0] inst_sram_addr,           //请求的地址
    output [31:0] inst_sram_wdata,          //写请求地写数据
    input         inst_sram_addr_ok,        //地址传输ok
    input         inst_sram_data_ok,        //数据传输ok
    input  [31:0] inst_sram_rdata,          //这次请求返回地数据
    // data sram interface
    output        data_sram_req,
    output        data_sram_wr,
    output [ 1:0] data_sram_size,
    output [ 3:0] data_sram_wstrb,
    output [31:0] data_sram_addr,
    output [31:0] data_sram_wdata,
    input         data_sram_addr_ok,
    input         data_sram_data_ok,
    input  [31:0] data_sram_rdata,
    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;
wire [31:0]  ws_pc_send;
wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire es_valid_r;
wire ms_valid_r;
wire ws_valid_r;
wire [4:0] es_to_ds_dest ;
wire [4:0] ms_to_ds_dest ;
wire [4:0] ws_to_ds_dest ;
wire       es_we_r;
wire       ms_we_r;
wire       ws_we_r;
wire [31:0] es_fw_send;
wire [31:0] ms_wf_send;
wire [31:0] ws_wf_send;
wire        es_send_ready;
wire [31:0] reg_fs_inst;



// IF stage
if_stage if_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus_d       (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst sram interface
    // .inst_sram_en   (inst_sram_en   ),
    // .inst_sram_wen  (inst_sram_wen  ),
    // .inst_sram_addr (inst_sram_addr ),
    // .inst_sram_wdata(inst_sram_wdata),
    // .inst_sram_rdata(inst_sram_rdata),
    .inst_sram_req_d    (inst_sram_req  ),
    .inst_sram_wr       (inst_sram_wr   ),
    .inst_sram_size     (inst_sram_size ),
    .inst_sram_wstrb    (inst_sram_wstrb),
    .inst_sram_addr     (inst_sram_addr ),
    .inst_sram_wdata    (inst_sram_wdata),
    .inst_sram_addr_ok  (inst_sram_addr_ok),
    .inst_sram_data_ok  (inst_sram_data_ok),
    .inst_sram_rdata    (inst_sram_rdata),
    .wb_ex              (wb_ex          ),
    .eret_flush         (eret_flush     ),
    .ws_pc_send         (ws_pc_send     ),
    .fs_ready_go        (fs_ready_go    ),
    .reg_fs_inst        (reg_fs_inst    ),
    .regvalid           (regvalid       ),
    .ds_ready_go        (ds_ready_go    ),
    .es_allowin         (es_allowin     ),
    .br_stall           (br_stall       ),
    .stop_fs_go         (stop_fs_go     ),
    .ds_valid           (ds_valid       ),
    .mf_stop            (mf_stop        )

);
// ID stage
id_stage id_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    .es_valid_r     (es_valid_r     ),
    .es_to_ds_dest  (es_to_ds_dest  ),
    .ms_valid_r     (ms_valid_r     ),
    .ms_to_ds_dest  (ms_to_ds_dest  ),
    .ws_valid_r     (ws_valid_r     ),
    .ws_to_ds_dest  (ws_to_ds_dest  ),
    .es_we_r        (es_we_r        ),
    .ms_we_r        (ms_we_r        ),
    .ws_we_r        (ws_we_r        ),
    .es_fw_send     (es_fw_send     ),
    .es_send_ready  (es_send_ready  ),
    
    .ms_wf_send     (ms_wf_send     ),
    .ws_wf_send     (ws_wf_send     ),
    .wb_ex          (wb_ex          ),
    .es_inst_mfc0   (es_inst_mfc0   ),
    .ms_inst_mfc0   (ms_inst_mfc0   ),
    .ws_inst_mfc0   (ws_inst_mfc0   ),
    .eret_flush     (eret_flush     ),
    .eq_stop        (eq_stop        ),
    .fs_ready_go    (fs_ready_go    ),
    .reg_fs_inst    (reg_fs_inst    ),
    .regvalid       (regvalid       ),
    .ds_ready_go    (ds_ready_go    ),
    .br_stall       (br_stall       ),
    .req_ok_go_d    (req_ok_go_d    ),
    .stop_fs_go     (stop_fs_go     ),
    .ds_valid       (ds_valid       ),
    .mf_stop        (mf_stop        )
);
// EXE stage
exe_stage exe_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data sram interface

    // .data_sram_en   (data_sram_en   ),
    // .data_sram_wen  (data_sram_wen  ),
    // .data_sram_addr (data_sram_addr ),
    // .data_sram_wdata(data_sram_wdata),
    .data_sram_req_d    (data_sram_req      ),
    .data_sram_wr       (data_sram_wr       ),
    .data_sram_size     (data_sram_size     ),
    .data_sram_wstrb    (data_sram_wstrb    ),
    .data_sram_addr     (data_sram_addr     ),
    .data_sram_wdata    (data_sram_wdata    ),
    .data_sram_addr_ok  (data_sram_addr_ok  ),
    .data_sram_data_ok  (data_sram_data_ok  ),
    .data_sram_rdata    (data_sram_rdata    ),
    
    .es_valid_r     (es_valid_r     ),
    .es_to_ds_dest  (es_to_ds_dest  ),
    .es_we_r        (es_we_r        ),
    .es_fw_send     (es_fw_send     ),
    .es_send_ready  (es_send_ready  ),
    .wb_ex          (wb_ex          ),
    .mz_ex          (mz_ex          ),
    .es_inst_mfc0   (es_inst_mfc0   ),
    .eret_flush     (eret_flush     ),
    .wz_ex          (wz_ex          ),
    .es_ready_go    (es_ready_go    ),
    .req_ok_go_d    (req_ok_go_d    )
    // .es_alu_result  (es_alu_result  )
);
// MEM stage
mem_stage mem_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data-sram
    .data_sram_rdata(data_sram_rdata),
    .data_sram_data_ok(data_sram_data_ok),
    .ms_valid       (ms_valid_r     ),
    .ms_dest        (ms_to_ds_dest  ),
    .ms_gr_we       (ms_we_r        ),
    .ms_wf_send     (ms_wf_send     ),
    .wb_ex          (wb_ex          ),
    .mz_ex          (mz_ex          ),
    .ms_inst_mfc0   (ms_inst_mfc0   ),
    .eret_flush     (eret_flush     ),
    .reg_data_sram_rdata(reg_data_sram_rdata),
    .reg_valid      (reg_valid      ),
    .es_ready_go    (es_ready_go    )
);
// WB stage
wb_stage wb_stage(
    .clk            (clk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    .ws_valid         (ws_valid_r       ),
    .ws_dest          (ws_to_ds_dest    ),
    .rf_we            (ws_we_r          ),
    .rf_wdata         (ws_wf_send       ),
    .wb_ex            (wb_ex            ),
    .ws_inst_mfc0     (ws_inst_mfc0     ),
    .eret_flush       (eret_flush       ),
    .c0_epc           (ws_pc_send       ),
    .eq_stop          (eq_stop          ),
    .wz_ex            (wz_ex            ),
    .reg_data_sram_rdata(reg_data_sram_rdata),
    .reg_valid        (reg_valid        )
);

endmodule
