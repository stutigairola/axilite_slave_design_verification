module axilite_s(
    input wire s_axi_aclk,
    input wire s_axi_aresetn,
    input wire s_axi_awvalid,
    output reg s_axi_awready,
    input wire [31:0] s_axi_awaddr,
    input wire s_axi_wvalid,
    output reg s_axi_wready,
    input wire [31:0] s_axi_wdata,
    output reg s_axi_bvalid,
    input wire s_axi_bready,
    output reg [1:0] s_axi_bresp,
    input wire s_axi_arvalid,
    output reg s_axi_arready,
    input wire [31:0] s_axi_araddr,
    output reg s_axi_rvalid,
    input wire s_axi_rready,
    output reg [31:0] s_axi_rdata,
    output reg [1:0] s_axi_rresp
);
localparam idle=4'd0,
           send_waddr_ack=4'd1,
           send_wdata_ack=4'd2,
           send_wr_resp=4'd3,
           send_wr_err=4'd4,
           send_raddr_ack=4'd5,
           gen_data=4'd6,
           send_rdata=4'd7,
           send_rd_err=4'd8;
reg [3:0] state;
reg [31:0] waddr,raddr,wdata;
reg [31:0] mem [0:127];
integer i;
always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
    if (!s_axi_aresetn) begin
        state<=idle;
        s_axi_awready<=0;
        s_axi_wready<=0;
        s_axi_bvalid<=0;
        s_axi_bresp<=0;
        s_axi_arready<=0;
        s_axi_rvalid<=0;
        s_axi_rdata<=0;
        s_axi_rresp<=0;
        waddr<=0;
        raddr<=0;
        wdata<=0;
        for (i=0;i<128;i=i+1)
            mem[i]<=0;
    end
    else begin
        case(state)
            idle: begin
                s_axi_awready<=0;
                s_axi_wready<=0;
                s_axi_bvalid<=0;
                s_axi_arready<=0;
                s_axi_rvalid<=0;
                if (s_axi_awvalid) begin
                    waddr<=s_axi_awaddr;
                    s_axi_awready<=1;
                    state<=send_waddr_ack;
                end
                else if (s_axi_arvalid) begin
                    raddr<=s_axi_araddr;
                    s_axi_arready<=1;
                    state<=send_raddr_ack;
                end
                else begin
                    state<=idle;
                end
            end
            send_waddr_ack: begin
                s_axi_awready<=0;
                if (s_axi_wvalid) begin
                    wdata<=s_axi_wdata;
                    s_axi_wready<=1;
                    state<=send_wdata_ack;
                end
                else begin
                    state<=send_waddr_ack;
                end
            end
            send_wdata_ack: begin
                s_axi_wready<=0;
                if (waddr<128) begin
                    mem[waddr]<=wdata;
                    s_axi_bresp<=2'b00;
                    s_axi_bvalid<=1;
                    state<=send_wr_resp;
                end
                else begin
                    s_axi_bresp<=2'b11;
                    s_axi_bvalid<=1;
                    state<=send_wr_err;
                end
            end
            send_wr_resp, send_wr_err: begin
                if (s_axi_bready) begin
                    s_axi_bvalid<=0;
                    state<=idle;
                end
                else begin
                    state<=state;
                end
            end
            send_raddr_ack: begin
                s_axi_arready<=0;
                if (raddr<128) begin
                    state<=gen_data;
                end
                else begin
                    s_axi_rdata<=0;
                    s_axi_rresp<=2'b11;
                    s_axi_rvalid<=1;
                    state<=send_rd_err;
                end
            end
            gen_data: begin
                s_axi_rdata<=mem[raddr];
                s_axi_rresp<=2'b00;
                s_axi_rvalid<=1;
                state<=send_rdata;
            end
            send_rdata, send_rd_err: begin
                if (s_axi_rready) begin
                    s_axi_rvalid<=0;
                    state<=idle;
                end
                else begin
                    state<=state;
                end
            end
            default: begin
                state<=idle;
            end
        endcase
    end
end

endmodule
