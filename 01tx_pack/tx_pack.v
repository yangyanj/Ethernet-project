module tx_pack(
    clk          ,
    rst_n        ,
    cfg_sport    ,
    cfg_dport    ,
    cfg_sip      ,
    cfg_dip      ,
    cfg_mac_d    ,
    cfg_mac_s    ,
    tx_data      ,
    tx_sop       ,
    tx_eop       ,
    tx_vld       ,
    tx_rdy       ,
    tx_mty       ,
    dout         ,
    dout_sop     ,
    dout_eop     ,
    dout_vld     ,
    dout_rdy     ,
    dout_mty       

);
 `include "clogb2.v"

    parameter      DATA_W    = 16      ;
    parameter      D_DATA_W  = 16 +3   ;
    parameter      D_DEPT_W  = 4096    ;
    parameter      D_DEPT_W_C = clogb2(D_DEPT_W)-1;

    parameter      M_DATA_W  = 32      ;
    parameter      M_DEPT_W  = 512     ;
    parameter      M_DEPT_W_C = clogb2(M_DEPT_W)-1;

    parameter      MAC_TYPE  = 16'h0800;
    parameter      IP_VER    = 4'd4    ;
    parameter      IP_IHL    = 4'd5    ;
    parameter      IP_TOS    = 8'd0    ;
    parameter      IP_FLAG   = 3'b010  ;
    parameter      IP_OFFSET = 13'd0   ;
    parameter      IP_LIVE   = 8'd255  ;
    parameter      IP_PRL    = 8'd17   ;

    input          clk          ;
    input          rst_n        ;
    input[15:0]    cfg_sport    ;
    input[15:0]    cfg_dport    ;
    input[31:0]    cfg_sip      ;
    input[31:0]    cfg_dip      ;
    input[47:0]    cfg_mac_d    ;
    input[47:0]    cfg_mac_s    ;
    input[15:0]    tx_data      ;
    input          tx_sop       ;
    input          tx_eop       ;
    input          tx_vld       ;
    output         tx_rdy       ;
    input          tx_mty       ;
    output[15:0]   dout         ;
    output         dout_sop     ;
    output         dout_eop     ;
    output         dout_vld     ;
    input          dout_rdy     ;
    output         dout_mty     ; 


    reg            tx_rdy       ;
    reg   [15:0]   dout         ;
    reg            dout_sop     ;
    reg            dout_eop     ;
    reg            dout_vld     ;
    reg            dout_mty     ; 

    wire[D_DATA_W-1 :0] d_data  ;
    wire                d_rdreq ;
    wire                d_wrreq ;
    wire                d_empty ;
    wire                d_full  ;
    wire[D_DEPT_W_C-1 :0] d_usedw;
    wire[D_DATA_W-1 :0] d_q      ;

    wire[M_DATA_W-1 :0] m_data  ;
    wire                m_rdreq ;
    wire                m_wrreq ;
    wire                m_empty ;
    wire                m_full  ;
    wire[M_DEPT_W_C-1 :0] m_usedw;
    wire[M_DATA_W-1 :0] m_q      ;
    wire                d_q_sop  ;
    wire                d_q_eop  ;
    wire                d_q_mty  ;

    wire                end_dout ;
    

    fifo_ahead_sys#(.DATA_W(D_DATA_W),.DEPT_W(D_DEPT_W)) u_dfifo(
        .aclr  (~rst_n  ),
    	.clock (clk     ) ,
    	.data  (d_data  ) ,
    	.rdreq (d_rdreq ) ,
    	.wrreq (d_wrreq ) ,
    	.empty (d_empty ) ,
    	.full  (d_full  ) ,
        .usedw (d_usedw ) ,
    	.q     (d_q     ) );
    
    fifo_ahead_sys#(.DATA_W(M_DATA_W),.DEPT_W(M_DEPT_W)) u_mfifo(
        .aclr  (~rst_n  ),
    	.clock (clk     ) ,
    	.data  (m_data  ) ,
    	.rdreq (m_rdreq ) ,
    	.wrreq (m_wrreq ) ,
    	.empty (m_empty ) ,
    	.full  (m_full  ) ,
        .usedw (m_usedw ) ,
    	.q     (m_q     )    );
    
    
    assign d_data  = {tx_sop,tx_eop,tx_mty,tx_data};
    assign d_wrreq = tx_vld;
    assign d_rdreq = data_flag && d_empty==0 && dout_rdy;
    assign d_q_mty = d_q[16] ;
    assign d_q_eop = d_q[17] ;
    assign d_q_sop = d_q[18] ;
    
    assign m_data  = {data_len,data_sum_tmp1};
    assign m_wrreq = tx_eop && tx_vld        ;
    assign m_rdreq = end_dout                ;


    reg[15 :0 ]               cnt0    ;
    wire                      add_cnt0;
    wire                      end_cnt0;
    wire[15:0]                data_len;
    
    
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            cnt0 <= 0;
        end
        else if(add_cnt0)begin
            if(end_cnt0)
                cnt0 <= 0;
            else
                cnt0 <= cnt0 + 1;
        end
    end
    
    assign add_cnt0 = tx_vld             ;
    assign end_cnt0 = add_cnt0 && tx_eop ;
    assign data_len = (cnt0+1)*2 - tx_mty;

    reg[DATA_W-1 :0]  tx_data_2;

    always  @(*)begin
        if(tx_vld && tx_mty)
            tx_data_2 = {tx_data[15:8],8'b0};
        else
            tx_data_2 = tx_data             ;
    end

    reg[DATA_W+1-1 :0] data_sum_tmp0;
    wire[DATA_W-1   :0] data_sum_tmp1;
    reg [DATA_W-1   :0] data_sum     ;
    
    always  @(*)begin
        if(tx_vld && tx_sop)
            data_sum_tmp0 = tx_data_2;
        else if(tx_vld)
            data_sum_tmp0 = tx_data_2 + data_sum;
        else
            data_sum_tmp0 = data_sum;
    end
    
    assign data_sum_tmp1 = data_sum_tmp0[16] + data_sum_tmp0[15:0];
    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            data_sum <= 0;
        end
        else begin
            data_sum <= data_sum_tmp1;
        end
    end
    
    ///////////////////////////////////////////////////////////////////////////
    wire[111 :0]    mac_head;
    wire[159 :0]    ip_head ;
    wire[ 63 :0]    udp_head;
    wire[159 :0]    udp_prehead;
    wire[ 15 :0]    udp_len    ;
    wire[335 :0]    all_head   ;
    wire[ 15 :0]    udp_sum_n  ;

    assign  udp_sum_n = ~udp_sum;
    
    assign udp_head    = {cfg_sport,cfg_dport,udp_len,udp_sum_n};
    assign udp_prehead = {cfg_sip  ,cfg_dip  ,16'd17 ,udp_len,udp_head};
    
    assign udp_len     = m_q[31:16] + 8       ;


    reg [16:0]       udp_head_sum_ff0_tmp[5:0];
    reg [15:0]       udp_head_sum_ff0[5:0]    ;
    always  @(*)begin
        udp_head_sum_ff0_tmp[0] = udp_prehead[10*16-1 -:16] + udp_prehead[9*16-1 -:16];
        udp_head_sum_ff0_tmp[1] = udp_prehead[ 8*16-1 -:16] + udp_prehead[7*16-1 -:16];
        udp_head_sum_ff0_tmp[2] = udp_prehead[ 6*16-1 -:16] + udp_prehead[5*16-1 -:16];
        udp_head_sum_ff0_tmp[3] = udp_prehead[ 4*16-1 -:16] + udp_prehead[3*16-1 -:16];
        udp_head_sum_ff0_tmp[4] = udp_prehead[ 2*16-1 -:16] ;//+ udp_prehead[1*16-1 -:16];
        udp_head_sum_ff0_tmp[5] = m_q[15:0];
    end

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            udp_head_sum_ff0[0] = 0;
            udp_head_sum_ff0[1] = 0;
            udp_head_sum_ff0[2] = 0;
            udp_head_sum_ff0[3] = 0;
            udp_head_sum_ff0[4] = 0;
            udp_head_sum_ff0[5] = 0;
        end
        else begin
            udp_head_sum_ff0[0] = udp_head_sum_ff0_tmp[0][16] + udp_head_sum_ff0_tmp[0][15:0];
            udp_head_sum_ff0[1] = udp_head_sum_ff0_tmp[1][16] + udp_head_sum_ff0_tmp[1][15:0];
            udp_head_sum_ff0[2] = udp_head_sum_ff0_tmp[2][16] + udp_head_sum_ff0_tmp[2][15:0];
            udp_head_sum_ff0[3] = udp_head_sum_ff0_tmp[3][16] + udp_head_sum_ff0_tmp[3][15:0];
            udp_head_sum_ff0[4] = udp_head_sum_ff0_tmp[4][16] + udp_head_sum_ff0_tmp[4][15:0];
            udp_head_sum_ff0[5] = udp_head_sum_ff0_tmp[5][16] + udp_head_sum_ff0_tmp[5][15:0];
        end
    end


    reg[16:0]       udp_head_sum_ff1_tmp[4:0];
    reg[15:0]       udp_head_sum_ff1[4:0]    ;
    always  @(*)begin
        udp_head_sum_ff1_tmp[0] = udp_head_sum_ff0[0] + udp_head_sum_ff0[1];
        udp_head_sum_ff1_tmp[1] = udp_head_sum_ff0[2] + udp_head_sum_ff0[3];
        udp_head_sum_ff1_tmp[2] = udp_head_sum_ff0[4] + udp_head_sum_ff0[5];
        
    end


    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            udp_head_sum_ff1[0] = 0 ;
            udp_head_sum_ff1[1] = 0 ;
            udp_head_sum_ff1[2] = 0 ;
        end
        else begin
            udp_head_sum_ff1[0] = udp_head_sum_ff1_tmp[0][16] + udp_head_sum_ff1_tmp[0][15:0] ;
            udp_head_sum_ff1[1] = udp_head_sum_ff1_tmp[1][16] + udp_head_sum_ff1_tmp[1][15:0] ;
            udp_head_sum_ff1[2] = udp_head_sum_ff1_tmp[2][16] + udp_head_sum_ff1_tmp[2][15:0] ;
        end
    end

    reg[16:0]       udp_head_sum_ff2_tmp[2:0];
    reg[15:0]       udp_head_sum_ff2[2:0]    ;
    always  @(*)begin
        udp_head_sum_ff2_tmp[0] = udp_head_sum_ff1[0] + udp_head_sum_ff1[1];
        udp_head_sum_ff2_tmp[1] = udp_head_sum_ff1[2]                      ;
    end


    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            udp_head_sum_ff2[0] = 0 ;
            udp_head_sum_ff2[1] = 0 ;
        end
        else begin
            udp_head_sum_ff2[0] = udp_head_sum_ff2_tmp[0][16] + udp_head_sum_ff2_tmp[0][15:0] ;
            udp_head_sum_ff2[1] = udp_head_sum_ff2_tmp[1][16] + udp_head_sum_ff2_tmp[1][15:0] ;
        end
    end

    reg[16:0]       udp_sum_tmp;
    reg[15:0]       udp_sum    ;
    always  @(*)begin
        udp_sum_tmp = udp_head_sum_ff2[0] + udp_head_sum_ff2[1];
    end


    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            udp_sum = 0 ;
        end
        else begin
            udp_sum = udp_sum_tmp[16] + udp_sum_tmp[15:0] ;
        end
    end


    reg [15:0]    ip_sum    ;
    reg [16:0]    ip_sum_tmp;
    reg [15:0]    ip_len    ;
    reg [15:0]    ip_id     ;
    assign ip_head     = {IP_VER,IP_IHL,IP_TOS,ip_len,
                         ip_id,IP_FLAG,IP_OFFSET,
                         IP_LIVE,IP_PRL,~ip_sum,
                         cfg_sip,cfg_dip} ;


    reg [16:0]    ip_head_sum_ff0_tmp[4:0];
    reg [15:0]    ip_head_sum_ff0[4:0];
    always  @(*)begin
        ip_head_sum_ff0_tmp[0] = ip_head[16*1-1 -:16] + ip_head[16*2-1 -:16];
        ip_head_sum_ff0_tmp[1] = ip_head[16*3-1 -:16] + ip_head[16*4-1 -:16];
        ip_head_sum_ff0_tmp[2] = /*ip_head[16*5-1 -:16] + */ip_head[16*6-1 -:16];
        ip_head_sum_ff0_tmp[3] = ip_head[16*7-1 -:16] + ip_head[16*8-1 -:16];
        ip_head_sum_ff0_tmp[4] = ip_head[16*9-1 -:16] + ip_head[16*10-1 -:16];
    end

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            ip_head_sum_ff0[0] = 0;
            ip_head_sum_ff0[1] = 0;
            ip_head_sum_ff0[2] = 0;
            ip_head_sum_ff0[3] = 0;
            ip_head_sum_ff0[4] = 0;
        end
        else begin
            ip_head_sum_ff0[0] = ip_head_sum_ff0_tmp[0][16] + ip_head_sum_ff0_tmp[0][15:0];
            ip_head_sum_ff0[1] = ip_head_sum_ff0_tmp[1][16] + ip_head_sum_ff0_tmp[1][15:0];
            ip_head_sum_ff0[2] = ip_head_sum_ff0_tmp[2][16] + ip_head_sum_ff0_tmp[2][15:0];
            ip_head_sum_ff0[3] = ip_head_sum_ff0_tmp[3][16] + ip_head_sum_ff0_tmp[3][15:0];
            ip_head_sum_ff0[4] = ip_head_sum_ff0_tmp[4][16] + ip_head_sum_ff0_tmp[4][15:0];
        end
    end

    reg[16:0]       ip_head_sum_ff1_tmp[2:0];
    reg[15:0]       ip_head_sum_ff1[2:0];
    always  @(*)begin
        ip_head_sum_ff1_tmp[0] = ip_head_sum_ff0[0] + ip_head_sum_ff0[1];
        ip_head_sum_ff1_tmp[1] = ip_head_sum_ff0[2]                     ;
        ip_head_sum_ff1_tmp[2] = ip_head_sum_ff0[3] + ip_head_sum_ff0[4];
    end


    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            ip_head_sum_ff1[0] = 0 ;
            ip_head_sum_ff1[1] = 0 ;
            ip_head_sum_ff1[2] = 0 ;
        end
        else begin
            ip_head_sum_ff1[0] = ip_head_sum_ff1_tmp[0][16] + ip_head_sum_ff1_tmp[0][15:0] ;
            ip_head_sum_ff1[1] =                              ip_head_sum_ff1_tmp[1][15:0] ;
            ip_head_sum_ff1[2] = ip_head_sum_ff1_tmp[2][16] + ip_head_sum_ff1_tmp[2][15:0] ;
        end
    end

    reg[16:0]       ip_head_sum_ff2_tmp[1:0];
    reg[15:0]       ip_head_sum_ff2[1:0];
    always  @(*)begin
        ip_head_sum_ff2_tmp[0] = ip_head_sum_ff1[0] + ip_head_sum_ff1[1];
        ip_head_sum_ff2_tmp[1] = ip_head_sum_ff1[2]                     ;
    end


    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            ip_head_sum_ff2[0] = 0 ;
            ip_head_sum_ff2[1] = 0 ;
        end
        else begin
            ip_head_sum_ff2[0] = ip_head_sum_ff2_tmp[0][16] + ip_head_sum_ff2_tmp[0][15:0] ;
            ip_head_sum_ff2[1] =                              ip_head_sum_ff2_tmp[1][15:0] ;
        end
    end

    always  @(*)begin
        ip_sum_tmp = ip_head_sum_ff2[0] + ip_head_sum_ff2[1];
    end


    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            ip_sum = 0 ;
        end
        else begin
            ip_sum = ip_sum_tmp[16] + ip_sum_tmp[15:0] ;
        end
    end



     always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            ip_id <= 0;
        end
        else if(end_dout)begin
            ip_id <= ip_id + 1;
        end
    end
    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
             ip_len <= 0;
        end
        else begin
             ip_len  <= udp_len  + 20 ;
        end
    end



 
    assign mac_head   = {cfg_mac_d,cfg_mac_s, MAC_TYPE};
    
    assign all_head   = { mac_head, ip_head ,udp_head};
    
    
    reg[ 5:0]          cnt1    ;
    wire               add_cnt1;
    wire               end_cnt1;
    reg                data_flag;
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            cnt1 <= 0;
        end
        else if(add_cnt1)begin
            if(end_cnt1)
                cnt1 <= 0;
            else
                cnt1 <= cnt1 + 1;
        end
    end
    
    assign add_cnt1 = m_empty==0 && data_flag==0 && dout_rdy;
    assign end_cnt1 = add_cnt1 && cnt1==21-1 ;

    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            data_flag <= 0;
        end
        else if(end_cnt1) begin
            data_flag <= 1;        
        end
        else if(end_dout)begin
            data_flag <= 0;        
        end
    end
    
    ///////////////////////////////////////////////////////////////////
    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            dout_sop <= 0;
        end
        else if(add_cnt1 && cnt1==1-1) begin
            dout_sop <= 1;
        end
        else begin
            dout_sop <= 0;
        end
    end
    
    assign end_dout = d_rdreq && d_q_eop;
    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            dout_eop <= 0;
        end
        else begin
            dout_eop <= end_dout;
        end
    end
    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            dout <= 0;
        end
        else if(data_flag) begin
            dout <= d_q[15:0];
        end
        else begin
            dout <= all_head[(21-cnt1)*16-1 -:16];
        end
    end
    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            dout_vld <= 0;
        end
        else begin
            dout_vld <= add_cnt1 || d_rdreq;
        end
    end
    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            dout_mty <= 0;
        end
        else begin
            dout_mty <=d_rdreq && d_q_eop && d_q_mty;
        end
    end
    
    
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            tx_rdy <= 0;
        end
        else begin
            tx_rdy <=  d_usedw<(D_DEPT_W-16);
        end
    end
    

endmodule


 

