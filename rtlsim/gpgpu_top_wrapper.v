`timescale 1ns/10ps

`include "define.v"

module gpgpu_top_wrapper;
  //GPGPU inputs and outputs
  wire                                  clk                                             ;
  wire                                  rst_n                                           ;

  wire                                  host_req_valid_i                                ;
  wire                                  host_req_ready_o                                ;
  wire [`WG_ID_WIDTH-1:0]               host_req_wg_id_i                                ;
  wire [`WF_COUNT_WIDTH-1:0]            host_req_num_wf_i                               ;
  wire [`WAVE_ITEM_WIDTH-1:0]           host_req_wf_size_i                              ;
  wire [`MEM_ADDR_WIDTH-1:0]            host_req_start_pc_i                             ;
  wire [`WG_SIZE_X_WIDTH*3-1:0]         host_req_kernel_size_3d_i                       ;
  wire [`MEM_ADDR_WIDTH-1:0]            host_req_pds_baseaddr_i                         ;
  wire [`MEM_ADDR_WIDTH-1:0]            host_req_csr_knl_i                              ;
  wire [`VGPR_ID_WIDTH:0]               host_req_vgpr_size_total_i                      ;
  wire [`SGPR_ID_WIDTH:0]               host_req_sgpr_size_total_i                      ;
  wire [`LDS_ID_WIDTH:0]                host_req_lds_size_total_i                       ;
  wire [`GDS_ID_WIDTH:0]                host_req_gds_size_total_i                       ;
  wire [`VGPR_ID_WIDTH:0]               host_req_vgpr_size_per_wf_i                     ;
  wire [`SGPR_ID_WIDTH:0]               host_req_sgpr_size_per_wf_i                     ;
  wire [`MEM_ADDR_WIDTH-1:0]            host_req_gds_baseaddr_i                         ;

  wire                                  host_rsp_valid_o                                ;
  wire                                  host_rsp_ready_i                                ;
  wire [`WG_ID_WIDTH-1:0]               host_rsp_inflight_wg_buffer_host_wf_done_wg_id_o;

  wire [`NUM_L2CACHE-1:0]               out_a_valid_o                                   ;
  wire [`NUM_L2CACHE-1:0]               out_a_ready_i                                   ;
  wire [`NUM_L2CACHE*`OP_BITS-1:0]      out_a_opcode_o                                  ;
  wire [`NUM_L2CACHE*`SIZE_BITS-1:0]    out_a_size_o                                    ;
  wire [`NUM_L2CACHE*`SOURCE_BITS-1:0]  out_a_source_o                                  ;
  wire [`NUM_L2CACHE*`ADDRESS_BITS-1:0] out_a_address_o                                 ;
  wire [`NUM_L2CACHE*`MASK_BITS-1:0]    out_a_mask_o                                    ;
  wire [`NUM_L2CACHE*`DATA_BITS-1:0]    out_a_data_o                                    ;
  wire [`NUM_L2CACHE*3-1:0]             out_a_param_o                                   ;

  wire [`NUM_L2CACHE-1:0]               out_d_valid_i                                   ;
  wire [`NUM_L2CACHE-1:0]               out_d_ready_o                                   ;
  wire [`NUM_L2CACHE*`OP_BITS-1:0]      out_d_opcode_i                                  ;
  wire [`NUM_L2CACHE*`SIZE_BITS-1:0]    out_d_size_i                                    ;
  wire [`NUM_L2CACHE*`SOURCE_BITS-1:0]  out_d_source_i                                  ;
  wire [`NUM_L2CACHE*`DATA_BITS-1:0]    out_d_data_i                                    ;
  wire [`NUM_L2CACHE*3-1:0]             out_d_param_i                                   ;

  GPGPU_top gpu_top(
    .clk                                              (clk                                             ),
    .rst_n                                            (rst_n                                           ),
    .host_req_valid_i                                 (host_req_valid_i                                ),
    .host_req_ready_o                                 (host_req_ready_o                                ),
    .host_req_wg_id_i                                 (host_req_wg_id_i                                ),
    .host_req_num_wf_i                                (host_req_num_wf_i                               ),
    .host_req_wf_size_i                               (host_req_wf_size_i                              ),
    .host_req_start_pc_i                              (host_req_start_pc_i                             ),
    .host_req_kernel_size_3d_i                        (host_req_kernel_size_3d_i                       ),
    .host_req_pds_baseaddr_i                          (host_req_pds_baseaddr_i                         ),
    .host_req_csr_knl_i                               (host_req_csr_knl_i                              ),
    .host_req_vgpr_size_total_i                       (host_req_vgpr_size_total_i                      ),
    .host_req_sgpr_size_total_i                       (host_req_sgpr_size_total_i                      ),
    .host_req_lds_size_total_i                        (host_req_lds_size_total_i                       ),
    .host_req_gds_size_total_i                        (host_req_gds_size_total_i                       ),
    .host_req_vgpr_size_per_wf_i                      (host_req_vgpr_size_per_wf_i                     ),
    .host_req_sgpr_size_per_wf_i                      (host_req_sgpr_size_per_wf_i                     ),
    .host_req_gds_baseaddr_i                          (host_req_gds_baseaddr_i                         ),
    .host_rsp_valid_o                                 (host_rsp_valid_o                                ),
    .host_rsp_ready_i                                 (host_rsp_ready_i                                ),
    .host_rsp_inflight_wg_buffer_host_wf_done_wg_id_o (host_rsp_inflight_wg_buffer_host_wf_done_wg_id_o),
    .out_a_valid_o                                    (out_a_valid_o                                   ),
    .out_a_ready_i                                    (out_a_ready_i                                   ),
    .out_a_opcode_o                                   (out_a_opcode_o                                  ),
    .out_a_size_o                                     (out_a_size_o                                    ),
    .out_a_source_o                                   (out_a_source_o                                  ),
    .out_a_address_o                                  (out_a_address_o                                 ),
    .out_a_mask_o                                     (out_a_mask_o                                    ),
    .out_a_data_o                                     (out_a_data_o                                    ),
    .out_a_param_o                                    (out_a_param_o                                   ),
    .out_d_valid_i                                    (out_d_valid_i                                   ),
    .out_d_ready_o                                    (out_d_ready_o                                   ),
    .out_d_opcode_i                                   (out_d_opcode_i                                  ),
    .out_d_size_i                                     (out_d_size_i                                    ),
    .out_d_source_i                                   (out_d_source_i                                  ),
    .out_d_data_i                                     (out_d_data_i                                    ),
    .out_d_param_i                                    (out_d_param_i                                   )
  );

endmodule