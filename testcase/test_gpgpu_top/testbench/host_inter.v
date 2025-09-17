`include "define.v"

module host_inter(
    input                           clk,                                           // Clock signal
    input                           rst_n,                                          // Active-low reset signal
    output                          host_req_valid_i,                               // Valid signal for host request to GPU
    input                           host_req_ready_o,                               // Ready signal from GPU for host request
    output [`WG_ID_WIDTH-1:0]       host_req_wg_id_i,                               // Work-group ID in host request
    output [`WF_COUNT_WIDTH-1:0]    host_req_num_wf_i,                              // Number of wavefronts in work-group
    output [`WAVE_ITEM_WIDTH-1:0]   host_req_wf_size_i,                             // Size of each wavefront
    output [`MEM_ADDR_WIDTH-1:0]    host_req_start_pc_i,                            // Start program counter for kernel execution
    output [`WG_SIZE_X_WIDTH*3-1:0] host_req_kernel_size_3d_i,                      // 3D kernel size (x,y,z dimensions)
    output [`MEM_ADDR_WIDTH-1:0]    host_req_pds_baseaddr_i,                        // Base address of parameter data structure
    output [`MEM_ADDR_WIDTH-1:0]    host_req_csr_knl_i,                             // CSR address for kernel configuration
    output [`VGPR_ID_WIDTH:0]       host_req_vgpr_size_total_i,                     // Total VGPR size across all wavefronts
    output [`SGPR_ID_WIDTH:0]       host_req_sgpr_size_total_i,                     // Total SGPR size across all wavefronts
    output [`LDS_ID_WIDTH:0]        host_req_lds_size_total_i,                      // Total LDS size required
    output [`GDS_ID_WIDTH:0]        host_req_gds_size_total_i,                      // Total GDS size required
    output [`VGPR_ID_WIDTH:0]       host_req_vgpr_size_per_wf_i,                    // VGPR size per wavefront
    output [`SGPR_ID_WIDTH:0]       host_req_sgpr_size_per_wf_i,                    // SGPR size per wavefront
    output [`MEM_ADDR_WIDTH-1:0]    host_req_gds_baseaddr_i,                        // Base address of GDS region

    input                           host_rsp_valid_o,                               // Valid signal for response from GPU
    output                          host_rsp_ready_i,                               // Ready signal for host to receive response
    input  [`WG_ID_WIDTH-1:0]       host_rsp_inflight_wg_buffer_host_wf_done_wg_id_o // Completed work-group ID in response
);
    //--------------------------------------------------------------------------------
    // Register Definition: For signal synchronization and output driving
    //--------------------------------------------------------------------------------
    reg                          host_req_valid_r;           // Register for host_req_valid_i
    reg [`WG_ID_WIDTH-1:0]       host_req_wg_id_r;           // Register for host_req_wg_id_i
    reg [`WF_COUNT_WIDTH-1:0]    host_req_num_wf_r;          // Register for host_req_num_wf_i
    reg [`WAVE_ITEM_WIDTH-1:0]   host_req_wf_size_r;         // Register for host_req_wf_size_i
    reg [`MEM_ADDR_WIDTH-1:0]    host_req_start_pc_r;        // Register for host_req_start_pc_i
    reg [`WG_SIZE_X_WIDTH*3-1:0] host_req_kernel_size_3d_r;  // Register for host_req_kernel_size_3d_i
    reg [`MEM_ADDR_WIDTH-1:0]    host_req_pds_baseaddr_r;    // Register for host_req_pds_baseaddr_i
    reg [`MEM_ADDR_WIDTH-1:0]    host_req_csr_knl_r;         // Register for host_req_csr_knl_i
    reg [`VGPR_ID_WIDTH:0]       host_req_vgpr_size_total_r; // Register for host_req_vgpr_size_total_i
    reg [`SGPR_ID_WIDTH:0]       host_req_sgpr_size_total_r; // Register for host_req_sgpr_size_total_i
    reg [`LDS_ID_WIDTH:0]        host_req_lds_size_total_r;  // Register for host_req_lds_size_total_i
    reg [`GDS_ID_WIDTH:0]        host_req_gds_size_total_r;  // Register for host_req_gds_size_total_i
    reg [`VGPR_ID_WIDTH:0]       host_req_vgpr_size_per_wf_r;// Register for host_req_vgpr_size_per_wf_i
    reg [`SGPR_ID_WIDTH:0]       host_req_sgpr_size_per_wf_r;// Register for host_req_sgpr_size_per_wf_i
    reg [`MEM_ADDR_WIDTH-1:0]    host_req_gds_baseaddr_r;    // Register for host_req_gds_baseaddr_i
    reg                          host_rsp_ready_r;           // Register for host_rsp_ready_i
    
    //--------------------------------------------------------------------------------
    // Output Assignment: Connect registers to module ports
    //--------------------------------------------------------------------------------
    assign host_req_valid_i            = host_req_valid_r;
    assign host_req_wg_id_i            = host_req_wg_id_r;
    assign host_req_num_wf_i           = host_req_num_wf_r;
    assign host_req_wf_size_i          = host_req_wf_size_r;
    assign host_req_start_pc_i         = host_req_start_pc_r;
    assign host_req_kernel_size_3d_i   = host_req_kernel_size_3d_r;
    assign host_req_pds_baseaddr_i     = host_req_pds_baseaddr_r;
    assign host_req_csr_knl_i          = host_req_csr_knl_r;
    assign host_req_vgpr_size_total_i  = host_req_vgpr_size_total_r;
    assign host_req_sgpr_size_total_i  = host_req_sgpr_size_total_r;
    assign host_req_lds_size_total_i   = host_req_lds_size_total_r;
    assign host_req_gds_size_total_i   = host_req_gds_size_total_r;
    assign host_req_vgpr_size_per_wf_i = host_req_vgpr_size_per_wf_r;
    assign host_req_sgpr_size_per_wf_i = host_req_sgpr_size_per_wf_r;
    assign host_req_gds_baseaddr_i     = host_req_gds_baseaddr_r;
    assign host_rsp_ready_i            = host_rsp_ready_r;
 
    //--------------------------------------------------------------------------------
    // Initialization: Set initial values for registers
    //--------------------------------------------------------------------------------
    initial begin
        host_req_valid_r           = 1'd0;
        host_req_wg_id_r           = {`WG_ID_WIDTH{1'd0}};
        host_req_num_wf_r          = {`WF_COUNT_WIDTH{1'd0}};
        host_req_wf_size_r         = {`WAVE_ITEM_WIDTH{1'd0}};
        host_req_start_pc_r        = {`MEM_ADDR_WIDTH{1'd0}};
        host_req_kernel_size_3d_r  = {`WG_SIZE_X_WIDTH*3{1'd0}};
        host_req_pds_baseaddr_r    = {`MEM_ADDR_WIDTH{1'd0}};
        host_req_csr_knl_r         = {`MEM_ADDR_WIDTH{1'd0}};
        host_req_vgpr_size_total_r = {`VGPR_ID_WIDTH{1'd0}};
        host_req_sgpr_size_total_r = {`SGPR_ID_WIDTH{1'd0}};
        host_req_lds_size_total_r  = {`LDS_ID_WIDTH{1'd0}};
        host_req_gds_size_total_r  = {`GDS_ID_WIDTH{1'd0}};
        host_req_vgpr_size_per_wf_r= {`VGPR_ID_WIDTH{1'd0}};
        host_req_sgpr_size_per_wf_r= {`SGPR_ID_WIDTH{1'd0}};
        host_req_gds_baseaddr_r    = {`MEM_ADDR_WIDTH{1'd0}};
        host_rsp_ready_r           = 1'd0;
    end

    //--------------------------------------------------------------------------------
    // Parameter Definition: File & Buffer Configuration
    //--------------------------------------------------------------------------------
    parameter META_FNAME_SIZE = 128;    // Length of metadata filename (in bits)
    parameter METADATA_SIZE   = 500;    // Size of metadata storage array
    parameter DATA_FNAME_SIZE = 128;    // Length of data filename (in bits)
    parameter DATADATA_SIZE   = 500;    // Size of data storage array
  
    //--------------------------------------------------------------------------------
    // Array Definition: Metadata Storage & Parsed Results
    //--------------------------------------------------------------------------------
    reg [31:0] metadata [METADATA_SIZE-1:0];  // Storage array for metadata from file
    reg [31:0] parsed_base_r  [0:10-1];       // Parsed base addresses (up to 10 buffers)
    reg [31:0] parsed_size_r  [0:10-1];       // Parsed sizes (up to 10 buffers)

    //--------------------------------------------------------------------------------
    // Task: Drive GPU Configuration (Initialize and send host request)
    //--------------------------------------------------------------------------------
    task drv_gpu;
        input [META_FNAME_SIZE*8-1:0] fn_metadata;  // Metadata filename
        input [DATA_FNAME_SIZE*8-1:0] fn_data;      // Data filename
        reg [31:0] block_id = 0;                    // Block ID (initialized to 0)
        reg [63:0] noused;                          // Unused metadata field
        reg [63:0] kernel_id;                       // Kernel ID from metadata
        reg [63:0] kernal_size0;                     // Kernel size dimension 0
        reg [63:0] kernal_size1;                     // Kernel size dimension 1
        reg [63:0] kernal_size2;                     // Kernel size dimension 2
        reg [63:0] wf_size;                          // Wavefront size
        reg [63:0] wg_size;                          // Work-group size
        reg [63:0] metaDataBaseAddr;                 // Base address of metadata
        reg [63:0] ldsSize;                          // LDS size requirement
        reg [63:0] pdsSize;                          // PDS size requirement
        reg [63:0] sgprUsage;                        // SGPR usage per wavefront
        reg [63:0] vgprUsage;                        // VGPR usage per wavefront
        reg [63:0] pdsBaseAddr;                      // Base address of PDS
        reg [63:0] num_buffer;                       // Number of buffers
        reg [31:0] pds_size;                         // PDS size (initialized to 0)
    begin
        // Read metadata from file into storage array
        $readmemh(fn_metadata, metadata);
        
        // Print test initialization information
        $display("============================================");
        $display("Begin test:");
        $display("metadata file: %s", fn_metadata);
        $display("data file: %s", fn_data);
        $display("");
        
        // Synchronize to clock rising edge
        @(posedge clk);
        
        // Parse 64-bit values from 32-bit metadata array (high word + low word)
        noused           <= {metadata[ 1], metadata[ 0]};
        kernel_id        <= {metadata[ 3], metadata[ 2]}; 
        kernal_size0     <= {metadata[ 5], metadata[ 4]}; 
        kernal_size1     <= {metadata[ 7], metadata[ 6]}; 
        kernal_size2     <= {metadata[ 9], metadata[ 8]}; 
        wf_size          <= {metadata[11], metadata[10]}; 
        wg_size          <= {metadata[13], metadata[12]}; 
        metaDataBaseAddr <= {metadata[15], metadata[14]}; 
        ldsSize          <= {metadata[17], metadata[16]}; 
        pdsSize          <= {metadata[19], metadata[18]}; 
        sgprUsage        <= {metadata[21], metadata[20]}; 
        vgprUsage        <= {metadata[23], metadata[22]}; 
        pdsBaseAddr      <= {metadata[25], metadata[24]}; 
        num_buffer       <= {metadata[27], metadata[26]}; 
        pds_size         <= 32'd0;
        
        // Synchronize to next clock edge
        @(posedge clk);
        
        // Configure host request registers with parsed values
        host_req_wg_id_r           <= {`WG_ID_WIDTH{1'd0}};
        host_req_num_wf_r          <= wg_size[31:0];
        host_req_wf_size_r         <= wf_size[31:0];
        host_req_start_pc_r        <= 32'h8000_0000;  // Fixed start PC
        host_req_kernel_size_3d_r  <= {`WG_SIZE_X_WIDTH{1'd0}};  // Initialized to 0
        host_req_pds_baseaddr_r    <= pdsBaseAddr[31:0] + block_id * pds_size * wf_size[31:0] * wg_size[31:0];
        host_req_csr_knl_r         <= metaDataBaseAddr[31:0];
        host_req_vgpr_size_total_r <= wg_size[31:0] * vgprUsage[31:0];
        host_req_sgpr_size_total_r <= wg_size[31:0] * sgprUsage[31:0];
        host_req_lds_size_total_r  <= 128;  // Fixed LDS size
        host_req_gds_size_total_r  <= 0;    // No GDS used
        host_req_vgpr_size_per_wf_r<= vgprUsage[31:0];
        host_req_sgpr_size_per_wf_r<= sgprUsage[31:0];
        host_req_gds_baseaddr_r    <= 0;    // No GDS base address
        
        // Wait for 1 clock cycle
        repeat(1) @(posedge clk);
        
        // Synchronize to clock edge and assert request valid
        @(posedge clk);
        host_req_valid_r <= 1'b1;
        
        // Wait for GPU to be ready (handshake completion)
        wait (host_req_valid_r && host_req_ready_o);
        
        // Synchronize to clock edge and deassert request valid
        @(posedge clk);
        host_req_valid_r <= 1'b0;
        
        // Print configuration completion information
        $display("");
        $display("*********");
        $display("metadata file: %s", fn_metadata);
        $display("data file: %s", fn_data);
        $display("Config finish!");
        $display("");
    end
    endtask

    //--------------------------------------------------------------------------------
    // Task: Handle Execution Completion (Wait for and process GPU response)
    //--------------------------------------------------------------------------------
    task exe_finish;
        input [META_FNAME_SIZE*8-1:0] fn_metadata;  // Metadata filename
        input [DATA_FNAME_SIZE*8-1:0] fn_data;      // Data filename
    begin
        // Prepare to receive response by asserting ready
        host_rsp_ready_r <= 1'b1;
        @(posedge clk);
        
        // Wait for valid response from GPU
        wait(host_rsp_valid_o && host_rsp_ready_r);
        
        // Synchronize to clock edge after response received
        @(posedge clk);
        
        // Print completion information
        $display("");
        $display("metadata file: %s", fn_metadata);
        $display("data file: %s", fn_data);
        $display("exe finish! wg_id: %0h", host_rsp_inflight_wg_buffer_host_wf_done_wg_id_o);
        $display("");
        $display("============================================");
        $display("");
    end
    endtask
  
    //--------------------------------------------------------------------------------
    // Task: Get Result Addresses (Parse buffer addresses and sizes from metadata)
    //--------------------------------------------------------------------------------
    task get_result_addr;
        input [META_FNAME_SIZE*8-1:0] fn_metadata;  // Metadata filename
        input [DATA_FNAME_SIZE*8-1:0] fn_data;      // Data filename
        reg   [31:0]                  num_buffer;   // Number of buffers from metadata
        integer i;                                  // Loop variable
    begin
        // Read metadata from file
        $readmemh(fn_metadata, metadata);
        @(posedge clk);
        
        // Parse number of buffers and extract base addresses and sizes
        num_buffer          = metadata[26]; 
        for(i = 0; i < num_buffer; i = i + 1) begin
            parsed_base_r[i]  = metadata[28 + i*2];
            parsed_size_r[i]  = metadata[28 + i*2 + num_buffer*2];
        end
    end
    endtask

endmodule
