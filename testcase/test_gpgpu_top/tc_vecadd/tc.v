
`define drv_gpu               u_host_inter.drv_gpu
`define exe_finish            u_host_inter.exe_finish
`define get_result_addr       u_host_inter.get_result_addr
`define parsed_base           u_host_inter.parsed_base_r
`define parsed_size           u_host_inter.parsed_size_r

`define init_mem              u_mem_inter.init_mem
`define tile_read_and_write   u_mem_inter.tile_read_and_write
`define mem                   u_mem_inter.mem
`define host_rsp_valid        u_host_inter.host_rsp_valid_o

//**********Selsct vecadd test case, remember modify `define NUM_THREAD at the same time**********//
//`define CASE_8W4T
//`define CASE_4W16T
`define CASE_4W32T
//`define CASE_4W8T

module tc;
  //parameter MAX_NUM_BUF     = 10; //the maximun of num_buffer
  //parameter MEM_ADDR        = 32;
  parameter METADATA_SIZE   = 1024; //the maximun size of .data
  parameter DATADATA_SIZE   = 2000; //the maximun size of .metadata

  parameter META_FNAME_SIZE = 128;
  parameter DATA_FNAME_SIZE = 128;

  parameter BUF_NUM         = 18;

  defparam u_host_inter.META_FNAME_SIZE = META_FNAME_SIZE;
  defparam u_host_inter.DATA_FNAME_SIZE = DATA_FNAME_SIZE;
  defparam u_host_inter.METADATA_SIZE   = METADATA_SIZE;
  defparam u_host_inter.DATADATA_SIZE   = DATADATA_SIZE;

  defparam u_mem_inter.META_FNAME_SIZE = META_FNAME_SIZE;
  defparam u_mem_inter.DATA_FNAME_SIZE = DATA_FNAME_SIZE;
  defparam u_mem_inter.METADATA_SIZE   = METADATA_SIZE;
  defparam u_mem_inter.DATADATA_SIZE   = DATADATA_SIZE;
  defparam u_mem_inter.BUF_NUM         = BUF_NUM;

  wire clk  = u_gen_clk.clk;
  wire rstn = u_gen_rst.rst_n;
 
  reg [META_FNAME_SIZE*8-1:0] meta_fname[7:0];
  reg [DATA_FNAME_SIZE*8-1:0] data_fname[7:0];

  initial begin
    repeat(500)
    @(posedge clk);
    init_test_file();
    test_vecadd();
    repeat(500)
    @(posedge clk);
    $finish();
  end

  initial begin
    mem_drv();
  end

  task init_test_file;
    begin

     `ifdef CASE_8W4T
     meta_fname[0] = "8w4t/vecadd_0.metadata";
     data_fname[0] = "8w4t/vecadd_0.data";
     `endif

     `ifdef CASE_4W16T
     meta_fname[0] = "4w16t/vecadd_0.metadata";
     data_fname[0] = "4w16t/vecadd_0.data";
     `endif
     
     `ifdef CASE_4W32T
     meta_fname[0] = "4w32t/vecadd_0.metadata";
     data_fname[0] = "4w32t/vecadd_0.data";
     `endif
     
     `ifdef CASE_4W8T
     meta_fname[0] = "4x8/vecadd_0.metadata";
     data_fname[0] = "4x8/vecadd_0.data";
     `endif
    end
  endtask

  task test_vecadd;
    begin
      `init_mem(meta_fname[0], data_fname[0]);
      `drv_gpu(meta_fname[0], data_fname[0]);
      `get_result_addr(meta_fname[0], data_fname[0]);
      `exe_finish(meta_fname[0], data_fname[0]);
      print_result();
    end
  endtask

  task mem_drv;
    begin
      while(1) fork
        `tile_read_and_write(0);
      join
    end
  endtask

  task print_result;
    reg [31:0]    sum_32_hard   [31:0]  ;
    reg [31:0]    sum_64_hard   [63:0]  ;
    reg [31:0]    sum_128_hard  [127:0] ;
    reg [31:0]    sum_32_pass           ;
    reg [63:0]    sum_64_pass           ;
    reg [127:0]   sum_128_pass          ;

    if(`host_rsp_valid) begin
      @(posedge clk);
      @(posedge clk);
      @(posedge clk);
      $display("-----------case_vecadd result-----------");
      $display("--------------sum result:---------------");
      for(integer addr=`parsed_base[2]; addr<`parsed_base[2]+`parsed_size[2]; addr=addr+4) begin
        //$fwrite(file1,"0x%h %h%h%h%h\n",addr,`mem[addr+3],`mem[addr+2],`mem[addr+1],`mem[addr]);
        $display("          0x%h %h%h%h%h",addr,`mem[addr+3],`mem[addr+2],`mem[addr+1],`mem[addr]);
         `ifdef CASE_8W4T
           sum_32_hard[(addr-`parsed_base[2])/4]  = {`mem[addr+3],`mem[addr+2],`mem[addr+1],`mem[addr]};
         `endif
         `ifdef CASE_4W16T
           sum_64_hard[(addr-`parsed_base[2])/4]  = {`mem[addr+3],`mem[addr+2],`mem[addr+1],`mem[addr]};
         `endif
         `ifdef CASE_4W32T
           sum_128_hard[(addr-`parsed_base[2])/4]  = {`mem[addr+3],`mem[addr+2],`mem[addr+1],`mem[addr]};
         `endif
         `ifdef CASE_4W8T
           sum_32_hard[(addr-`parsed_base[2])/4]  = {`mem[addr+3],`mem[addr+2],`mem[addr+1],`mem[addr]};
         `endif
      end

      `ifdef CASE_8W4T
          for(integer j=0; j<32; j=j+1) begin        
            if(sum_32_hard[j]==32'h42000000) begin
              sum_32_pass[j]  = 1'b1;
            end else begin
              sum_32_pass[j]  = 1'b0;
            end
          end
      `endif
      `ifdef CASE_4W16T
          for(integer j=0; j<64; j=j+1) begin        
            if(sum_64_hard[j]==32'h42800000) begin
              sum_64_pass[j]  = 1'b1;
            end else begin
              sum_64_pass[j]  = 1'b0;
            end
          end
      `endif
      `ifdef CASE_4W32T
          for(integer j=0; j<128; j=j+1) begin        
            if(sum_128_hard[j]==32'h43000000) begin
              sum_128_pass[j]  = 1'b1;
            end else begin
              sum_128_pass[j]  = 1'b0;
            end
          end
      `endif
      `ifdef CASE_4W8T
          for(integer j=0; j<32; j=j+1) begin        
            if(sum_32_hard[j]==32'h42000000) begin
              sum_32_pass[j]  = 1'b1;
            end else begin
              sum_32_pass[j]  = 1'b0;
            end
          end
      `endif

      `ifdef CASE_8W4T
            if(&sum_32_pass) begin
              $display("***********case_vecadd_8w4t************");
              $display("*****************PASS******************");
            end else begin
              $display("***********case_vecadd_8w4t************");
              $display("****************FAILED*****************");
            end
      `endif
      `ifdef CASE_4W16T
            if(&sum_64_pass) begin
              $display("***********case_vecadd_4w16t***********");
              $display("*****************PASS******************");
            end else begin
              $display("***********case_vecadd_4w16t***********");
              $display("****************FAILED*****************");
            end
      `endif
      `ifdef CASE_4W32T
            if(&sum_128_pass) begin
              $display("***********case_vecadd_4w32t***********");
              $display("*****************PASS******************");
            end else begin
              $display("***********case_vecadd_4w32t***********");
              $display("****************FAILED*****************");
            end
      `endif
      `ifdef CASE_4W8T
            if(&sum_32_pass) begin
              $display("***********case_vecadd_4w8t************");
              $display("*****************PASS******************");
            end else begin
              $display("***********case_vecadd_4w8t************");
              $display("****************FAILED*****************");
            end
      `endif
    end
  endtask

endmodule

