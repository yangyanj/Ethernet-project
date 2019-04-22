
`timescale 1 ns/1 ns

module test_tx_pack();

    reg               	 clk    			;
    reg               	 rst_n  			;

    reg [   15: 0]         cfg_sport		; //本地的端口号
    reg [   15: 0]         cfg_dport		; //目的的端口号
    reg [   31: 0]         cfg_sip			; //源IP地址
    reg [   31: 0]         cfg_dip			; //目的IP地址
    reg [   47: 0]         cfg_mac_s		; //源MAC地址
    reg [   47: 0]         cfg_mac_d		; //目的MAC地址

    reg [   15: 0]         tx_data			;
    reg                    tx_vld			;
    reg                    tx_sop			;
    reg                    tx_eop			;
    reg                    tx_mty			;
    reg                    dout_rdy			;

    wire[   15: 0]         dout 			;
    wire                   dout_vld 		;
    wire                   dout_sop			;
    wire                   dout_eop 		;
    wire                   dout_mty			;
    wire                    tx_rdy			;


    parameter CYCLE    = 10;

    parameter RST_TIME = 3 ;

    integer     ii; 

    tx_pack uut(
	    .clk    		(clk    		),	
	    .rst_n  		(rst_n  		),	

	    .cfg_sport		(cfg_sport		),	
	    .cfg_dport		(cfg_dport		),	
	    .cfg_sip		(cfg_sip		),	
	    .cfg_dip		(cfg_dip		),	
	    .cfg_mac_s		(cfg_mac_s		),	
	    .cfg_mac_d		(cfg_mac_d		),	

	    .tx_data		(tx_data		),	
	    .tx_vld			(tx_vld			),	
	    .tx_sop			(tx_sop			),	
	    .tx_eop			(tx_eop			),	
		.tx_rdy			(tx_rdy			),	
		.tx_mty			(tx_mty			),	

		.dout 			(dout 			),	
		.dout_vld		(dout_vld		),	
	    .dout_sop		(dout_sop		),	
	    .dout_eop		(dout_eop		),	
	    .dout_rdy		(dout_rdy		),	
	    .dout_mty		(dout_mty		)	
        );


        initial begin
            clk = 0;
            forever
            #(CYCLE/2)
            clk=~clk;
        end

        initial begin
            rst_n = 1;
            #2;
            rst_n = 0;
            #(CYCLE*RST_TIME);
            rst_n = 1;
        end

        initial begin
            #1;
            cfg_sport 	= 	16'h1388			;    //本地的端口 
            cfg_dport 	= 	16'h0bb8			;    //目的的端口 
            cfg_sip 	=	32'hc0a8010a		;    //源IP地址
            cfg_dip 	=	32'hc0a80109		;    //目的IP地址
            cfg_mac_d   =	48'h010203040506	;    //源MAC地址
            cfg_mac_s   =	48'h2c0203040507	;    //目的MAC地址

            tx_data    	=	0   				;
            tx_sop		=	0   				;
            tx_eop		=	0   				;
            tx_vld		=	0   				;
            tx_mty		=	0 					;
           
            #(100*CYCLE);
            tx_data    	=	0   				;
            tx_sop		=	0   				;
            tx_eop		=	0   				;
            tx_vld		=	0   				;
            tx_mty		=	0 					;
            #(100*CYCLE);
            t_send(15);

            t_send(16);

            t_send(17);
             tx_data[15:8] = 0 ;
                        tx_data[ 7:0] = 0 ;
                        tx_vld        = 0 ;
                        tx_sop        = 0 ;
                        tx_eop        = 0 ;
                        tx_mty        = 0 ;
        end


        initial begin
            #1;
            forever begin
                dout_rdy = $random;
                #CYCLE;
            end
        end



        reg [31:0]  len_2b;

        task t_send;
            input[31:0] length;
            
            begin
                len_2b = length[31:1] + length[0];
                ii = 0 ;
                while(ii!=len_2b)begin
                    if(tx_rdy==1)begin
                        tx_data[15:8] = ii*2 + 0 ;
                        tx_data[ 7:0] = ii*2 + 1 ;
                        tx_vld        = 1;
                        tx_sop        = (ii==0)?1:0;
                        tx_eop        = (ii==len_2b-1)?1:0;
                        tx_mty        = length[0] ;
                        ii = ii + 1 ;
                    end
                    else begin
                        tx_data[15:8] = 0 ;
                        tx_data[ 7:0] = 0 ;
                        tx_vld        = 0 ;
                        tx_sop        = 0 ;
                        tx_eop        = 0 ;
                        tx_mty        = 0 ;
                    end
                    #(CYCLE);
                end
            end
        endtask

        wire[99*16-1 :0] exp_pack[2:0];


        //第1个包文是15字节，期望输出是57字节，输出58个字节，所以未尾要补(128-58)*16个0。
        assign exp_pack[0] = {16'h000a,16'h0001,16'h0002,16'h0003,
                              16'h0004,16'h0005,16'h0006,16'h0007,
                              16'h0008,16'h0009,16'h0010,16'h0011,
                              16'h0012,16'h0013,16'h0014,16'h0015,
                              16'h0016,16'h0017,16'h0018,16'h0019,
                              16'h0020,16'h0021,16'h0022,16'h0023,
                              16'h0024,16'h0025,16'h0026,16'h0027,
                              16'h0028,1120'h0}; 

       //第2个包文是16字节，期望输出是58字节，输出58个字节，所以未尾要补(128-58)*16个0。 
       assign exp_pack[1] =  {16'h000a,16'h0001,16'h0002,16'h0003,
                              16'h0004,16'h0005,16'h0006,16'h0007,
                              16'h0008,16'h0009,16'h0010,16'h0011,
                              16'h0012,16'h0013,16'h0014,16'h0015,
                              16'h0016,16'h0017,16'h0018,16'h0019,
                              16'h0020,16'h0021,16'h0022,16'h0023,
                              16'h0024,16'h0025,16'h0026,16'h0027,
                              16'h0028,1120'h0};      

       //第3个包文是17字节，期望输出是59字节，输出60个字节，所以未尾要补(128-60)*16个0。 
       assign exp_pack[2] =  {16'h000a,16'h0001,16'h0002,16'h0003,
                              16'h0004,16'h0005,16'h0006,16'h0007,
                              16'h0008,16'h0009,16'h0010,16'h0011,
                              16'h0012,16'h0013,16'h0014,16'h0015,
                              16'h0016,16'h0017,16'h0018,16'h0019,
                              16'h0020,16'h0021,16'h0022,16'h0023,
                              16'h0024,16'h0025,16'h0026,16'h0027,
                              16'h0028,16'h0029,1104'h0}; 

       reg[31:0] cnt_data ;
       reg[31:0] cnt_pack ;
       reg  dout_rdy_ff ;

       always  @(posedge clk or negedge rst_n)begin
           if(rst_n==1'b0)begin
               cnt_data <= 0;
               cnt_pack <= 0;
           end
           else if(dout_vld && dout_eop) begin
               cnt_data <= 0;
               cnt_pack <= cnt_pack + 1;
           end
           else if(dout_vld)begin
               cnt_data <= cnt_data + 1;
           end
       end

       always  @(posedge clk)begin
           if(dout_vld )begin
               if(dout != exp_pack[cnt_pack][(128-cnt_data)*16-1 -:16])begin
                   if(dout != 16'h1011 && cnt_data==29 && cnt_pack==2)begin
                   $display("Err at %t for dout",$time);
               end
               end
               
               if(dout_sop!=1 && cnt_data==0)begin
                   $display("Err at %t for dout_sop",$time);
               end

               if(dout_eop!=1 && ((cnt_pack==0 && cnt_data==28) || (cnt_pack==1 && cnt_data==28) ||(cnt_pack==2 && cnt_data==29)))begin
                   $display("Err at %t for dout_eop",$time);
               end
               
               if(dout_eop && ((cnt_pack==0 && dout_mty!=1) || (cnt_pack==1 && dout_mty!=0) ||(cnt_pack==2 && dout_mty!=1)))begin
                   $display("Err at %t for dout_mty",$time);
               end

               if(dout_rdy_ff==0)begin
                   $display("Err at %t for dout_vld",$time);
               end

           end
       end

       always  @(posedge clk or negedge rst_n)begin
           if(rst_n==1'b0)begin
               dout_rdy_ff <= 1;
           end
           else begin
               dout_rdy_ff <= dout_rdy;
           end
       end






endmodule

