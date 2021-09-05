module bridge(
    input         aclk              ,
    input         reset             ,
    input         inst_sram_req     ,           //请求信号
    input         inst_sram_wr      ,           //1为写请求
    input  [ 1:0] inst_sram_size    ,           //请求传输地字节数
    input  [ 3:0] inst_sram_wstrb   ,           //写请求地字节写使能
    input  [31:0] inst_sram_addr    ,           //请求的地址
    input  [31:0] inst_sram_wdata   ,           //写请求地写数据
    output        inst_sram_addr_ok ,           //地址传输ok
    output        inst_sram_data_ok ,           //数据传输ok
    output [31:0] inst_sram_rdata   ,           //这次请求返回地数据
    // data sram interface
    input         data_sram_req     ,
    input         data_sram_wr      ,
    input  [ 1:0] data_sram_size    ,
    input  [ 3:0] data_sram_wstrb   ,
    input  [31:0] data_sram_addr    ,
    input  [31:0] data_sram_wdata   ,
    output        data_sram_addr_ok ,
    output        data_sram_data_ok ,
    output [31:0] data_sram_rdata   ,
    // read req
    output [ 3:0] arid              ,
    output [31:0] araddr            ,
    output [ 7:0] arlen             ,
    output [ 2:0] arsize            ,
    output [ 1:0] arburst           ,
    output [ 1:0] arlock            ,
    output [ 3:0] arcache           ,
    output [ 2:0] arprot            ,
    output        arvalid           ,
    input         arready           ,
    // read resp
    input  [ 3:0] rid               ,
    input  [31:0] rdata             ,
    input  [ 1:0] rresp             ,
    input         rlast             ,
    input         rvalid            ,
    output        rready            ,
    // write req
    output [ 3:0] awid              ,
    output [31:0] awaddr            ,
    output [ 7:0] awlen             ,
    output [ 2:0] awsize            ,
    output [ 1:0] awburst           ,
    output [ 1:0] awlock            ,
    output [ 3:0] awcache           ,
    output [ 2:0] awprot            ,
    output        awvalid           ,
    input         awready           ,
    // write data
    output [ 3:0] wid               ,
    output [31:0] wdata             ,
    output [ 3:0] wstrb             ,
    output        wlast             ,
    output        wvalid            ,
    input         wready            ,
    // write resp
    input  [ 3:0] bid               ,
    input  [ 1:0] bresp             ,
    input         bvalid            ,
    output        bready            ,
    
    input         wb_ex             
);
assign inst_sram_addr_ok = ~arid & arready;
assign inst_sram_data_ok = ~rid & rvalid; 
assign inst_sram_rdata = rdata;


assign data_sram_addr_ok = (arid & arready) | (addr_ok & awid & wready & wvalid | data_ok & awid & awready & awvalid);
// reg r_wb_ex;       //记录在请求时来的例外，将返回的data_ok除外
// always @(posedge aclk) begin
//     if (reset) begin
//         r_wb_ex <= 0;
//     end
//     else if (req_togeter & wb_ex) begin
//         r_wb_ex <= 1;
//     end
//     if (rvalid) begin
//         r_wb_ex <= 0;
//     end
// end

        reg addr_ok;
        reg data_ok;
        always @(posedge aclk) begin
            if (reset) begin
                addr_ok <= 0;
                data_ok <= 0;
            end
            if (awid & awready & awvalid) begin
                addr_ok <= 1;
            end
            if (awid & wready & wvalid) begin
                data_ok <= 1;
            end
            if (addr_ok & data_ok) begin
                addr_ok <= 0;
                data_ok <= 0;
            end
        end
assign data_sram_data_ok = (rid & rvalid) | bvalid;
assign data_sram_rdata = rdata;
//读请求
assign arid = req_togeter ? reg_arid : (data_sram_req & ~data_sram_wr & inst_sram_req & ~inst_sram_wr) | (data_sram_req & ~data_sram_wr);

        reg req_togeter;                //记录前一个读响应的arid，下一个读响应来时不改变arid
        reg reg_arid;
        always @(posedge aclk) begin
            if (reset) begin
                req_togeter <= 0;
            end
            else if (data_sram_req & ~data_sram_wr | inst_sram_req & ~inst_sram_wr) begin
                req_togeter <= 1;
                reg_arid <= arid;
            end
            if (arready) begin
                req_togeter <= 0;
            end
        end
assign araddr = arid ? data_sram_addr : reg_araddr ? valid_reg_araddr : inst_sram_addr;
reg reg_araddr;
reg [31:0] valid_reg_araddr;
always @(posedge aclk) begin
    if (reset) begin
        reg_araddr <= 0;
        valid_reg_araddr <= 0;
    end
    else if (inst_sram_req) begin
        reg_araddr <= 1;
        valid_reg_araddr <= inst_sram_addr;
    end
    if (inst_sram_addr_ok) begin
        reg_araddr <= 0;
    end
end
assign arlen = 8'b00000000;
assign arsize = arid ? {1'b0,data_sram_size} : {1'b0,inst_sram_size};
assign arburst = 2'b01;
assign arlock = 2'b00;
assign arcache = 4'b0000;
assign arprot = 3'b000;
assign arvalid = ((inst_sram_req & ~inst_sram_wr) | (data_sram_req & ~data_sram_wr)) & ~reset &~rvalid;
//读响应
assign rready = 1'b1;
//写请求
assign awid = 4'b0001;
assign awaddr = data_sram_addr;
assign awlen = 8'b00000000;
assign awsize = {1'b0,data_sram_size};
assign awburst = 2'b01;
assign awlock = 2'b00;
assign awcache = 4'b0000;
assign awprot = 3'b000;
assign awvalid = data_sram_req & data_sram_wr  & ~addr_ok;
//写数据
assign wid = 4'b0001;
assign wdata = data_sram_wdata;
assign wstrb = data_sram_wstrb;
assign wlast = 1'b1;
assign wvalid = data_sram_req & data_sram_wr & ~data_ok;
//写响应
assign bready = 1'b1;
endmodule
