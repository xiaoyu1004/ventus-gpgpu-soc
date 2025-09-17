`define host_req_valid          gpu_test.host_req_valid_i
`define l2_flush_finish         test_gpu_top.gpu_test.B1[0].l2cache.SourceD_finish_issue_o
`define mem                     u_mem_inter.mem

module mem_inter(
    input                                     clk,                    // Clock signal
    input                                     rstn,                   // Active-low reset signal
    input   [`NUM_L2CACHE-1:0]                out_a_valid_o,          // Valid signal of L2 cache request (per L2 instance)
    output  [`NUM_L2CACHE-1:0]                out_a_ready_i,          // Ready signal to L2 cache (per L2 instance)
    input   [`NUM_L2CACHE*`OP_BITS-1:0]       out_a_opcode_o,         // Opcode of L2 request (read/write, per L2 instance)
    input   [`NUM_L2CACHE*`SIZE_BITS-1:0]     out_a_size_o,           // Data size of L2 request (per L2 instance)
    input   [`NUM_L2CACHE*`SOURCE_BITS-1:0]   out_a_source_o,         // Source ID of L2 request (per L2 instance)
    input   [`NUM_L2CACHE*`ADDRESS_BITS-1:0]  out_a_address_o,        // Target address of L2 request (per L2 instance)
    input   [`NUM_L2CACHE*`MASK_BITS-1:0]     out_a_mask_o,           // Byte mask for write request (per L2 instance)
    input   [`NUM_L2CACHE*`DATA_BITS-1:0]     out_a_data_o,           // Write data from L2 cache (per L2 instance)
    input   [`NUM_L2CACHE*3-1:0]              out_a_param_o,          // Additional parameters of L2 request (per L2 instance)

    output  [`NUM_L2CACHE-1:0]                out_d_valid_i,          // Valid signal of response to L2 (per L2 instance)
    input   [`NUM_L2CACHE-1:0]                out_d_ready_o,          // Ready signal of L2 for response (per L2 instance)
    output  [`NUM_L2CACHE*`OP_BITS-1:0]       out_d_opcode_i,         // Opcode of response (per L2 instance)
    output  [`NUM_L2CACHE*`SIZE_BITS-1:0]     out_d_size_i,           // Data size of response (per L2 instance)
    output  [`NUM_L2CACHE*`SOURCE_BITS-1:0]   out_d_source_i,         // Source ID of response (per L2 instance)
    output  [`NUM_L2CACHE*`DATA_BITS-1:0]     out_d_data_i,           // Read data in response (per L2 instance)
    output  [`NUM_L2CACHE*3-1:0]              out_d_param_i           // Additional parameters of response (per L2 instance)
);
    //-------------------------------------------------------------------------
    // Register Definition: For signal synchronization and output driving
    //-------------------------------------------------------------------------
    reg  [`NUM_L2CACHE-1:0]                out_a_ready_r;          // Register for out_a_ready_i
    reg  [`NUM_L2CACHE-1:0]                out_d_valid_r;          // Register for out_d_valid_i
    reg  [`NUM_L2CACHE*`OP_BITS-1:0]       out_d_opcode_r;         // Register for out_d_opcode_i
    reg  [`NUM_L2CACHE*`SIZE_BITS-1:0]     out_d_size_r;           // Register for out_d_size_i
    reg  [`NUM_L2CACHE*`SOURCE_BITS-1:0]   out_d_source_r;         // Register for out_d_source_i
    reg  [`NUM_L2CACHE*`DATA_BITS-1:0]     out_d_data_r;           // Register for out_d_data_i
    reg  [`NUM_L2CACHE*3-1:0]              out_d_param_r;          // Register for out_d_param_i
 
    //-------------------------------------------------------------------------
    // Output Assignment: Connect registers to module ports
    //-------------------------------------------------------------------------
    assign  out_a_ready_i  = out_a_ready_r;
    assign  out_d_valid_i  = out_d_valid_r;
    assign  out_d_opcode_i = out_d_opcode_r;
    assign  out_d_size_i   = out_d_size_r;
    assign  out_d_source_i = out_d_source_r;
    assign  out_d_data_i   = out_d_data_r;
    assign  out_d_param_i  = out_d_param_r;

    //-------------------------------------------------------------------------
    // Initialization: Set initial values for registers
    //-------------------------------------------------------------------------
    initial begin
        out_a_ready_r  = {(`NUM_L2CACHE){1'b0}};
        out_d_valid_r  = {(`NUM_L2CACHE){1'b0}};
        out_d_opcode_r = {(`NUM_L2CACHE){1'b0}};
        out_d_size_r   = {(`NUM_L2CACHE){1'b0}};
        out_d_source_r = {(`NUM_L2CACHE){1'b0}};
        out_d_data_r   = {(`NUM_L2CACHE){1'b0}};
        out_d_param_r  = {(`NUM_L2CACHE){1'b0}};
    end
  
    //-------------------------------------------------------------------------
    // Parameter Definition: File & Buffer Configuration
    //-------------------------------------------------------------------------
    parameter META_FNAME_SIZE = 128;    // Length of metadata filename (in bits)
    parameter METADATA_SIZE   = 1024;   // Size of metadata temporary array
    parameter DATA_FNAME_SIZE = 128;    // Length of data filename (in bits)
    parameter DATADATA_SIZE   = 2000;   // Size of data temporary array
    parameter BUF_NUM         = 18;     // Number of memory buffers
    parameter MEM_ADDR        = 32;     // Bit-width of memory address

    //-------------------------------------------------------------------------
    // Array Definition: Temporary Storage & Memory Model
    //-------------------------------------------------------------------------
    reg [31:0] data          [DATADATA_SIZE-1:0];      // Temporary array for data read from file
    reg [31:0] metadata      [METADATA_SIZE-1:0];      // Temporary array for metadata read from file
    reg [63:0] buf_ba_w      [BUF_NUM-1:0];             // Buffer base address (write-side)
    reg [63:0] buf_size      [BUF_NUM-1:0];             // Actual size of each buffer
    reg [63:0] buf_size_tmp  [BUF_NUM-1:0];             // Buffer size (4-byte aligned)
    reg [63:0] buf_asize     [BUF_NUM-1:0];             // Allocated size of each buffer (unused)
    logic [7:0] mem [bit unsigned [MEM_ADDR-1:0]];      // Main memory model (8-bit data, 32-bit unsigned address)


    //-------------------------------------------------------------------------
    // Task: Initialize Memory (Load data from files to mem array)
    //-------------------------------------------------------------------------
    task init_mem;
        input [META_FNAME_SIZE*8-1:0] fn_metadata;  // Metadata filename (input)
        input [DATA_FNAME_SIZE*8-1:0] fn_data;      // Data filename (input)
        reg   [63:0] buf_num_soft;                  // Number of buffers configured by software
        reg   [31:0] mem_addr [0:BUF_NUM-1];        // Start address of data in temporary array
        integer i, m;                                // Loop variables
    begin
        // 1.kernel arg1 buffer 90000000->00000200
        // 2.kernel arg2 buffer 90001000->00000200
        // 3.kernel arg3 buffer 90002000->00000200
        // 4.kernel arg base buffer 90003000->0000000c
        // 5.code buffer 80000000->0000041c
        // 6.print buffer 90004000->00000000
        // 7.metadata buffer 90084000->00000040

        // 1. Read data from files into temporary arrays
        $readmemh(fn_data, data);
        $readmemh(fn_metadata, metadata);

        // 2. Parse buffer count from metadata (64-bit: metadata[27] = high32, metadata[26] = low32)
        buf_num_soft = {metadata[27], metadata[26]};

        // 3. Initialize base address for each buffer
        for (i = 0; i < buf_num_soft; i = i + 1) begin
            buf_ba_w[i] = {metadata[i*2+29], metadata[i*2+28]};
        end

        // 4. Initialize actual size for each buffer
        for (i = 0; i < buf_num_soft; i = i + 1) begin
            buf_size[i] = {metadata[i*2+29+(buf_num_soft*2)], metadata[i*2+28+(buf_num_soft*2)]};
        end

        // 5. Initialize allocated size for each buffer (unused)
        for (i = 0; i < buf_num_soft; i = i + 1) begin
            buf_asize[i] = {metadata[i*2+29+buf_num_soft*4], metadata[i*2+28+buf_num_soft*4]};
        end
        
        // 6. Calculate start address in temporary array (4-byte alignment)
        mem_addr[0]       = 32'h0;
        buf_size_tmp[0]   = (buf_size[0] % 4 == 0) ? buf_size[0] : (buf_size[0]/4)*4 + 4;
        
        for (i = 1; i < buf_num_soft; i = i + 1) begin
            mem_addr[i] = mem_addr[i-1] + buf_size_tmp[i-1];  // Start = previous buffer's end
            buf_size_tmp[i] = (buf_size[i] % 4 == 0) ? buf_size[i] : (buf_size[i]/4)*4 + 4;
        end 

        // 7. Load temporary data into main memory model (mem array)
        for (i = 0; i < buf_num_soft; i = i + 1) begin
            for (int m = 0; m < buf_size_tmp[i]; m = m + 1) begin
                // Extract 8-bit byte from 32-bit temp data and write to mem
                mem[buf_ba_w[i] + m] <= data[(mem_addr[i] + m)/4][(m%4 + 1)*8 - 1 -: 8];
            end
        end
    end
    endtask

    //-------------------------------------------------------------------------
    // Local Parameter: Log2 of L2 cache count (for bus number bit-width)
    //-------------------------------------------------------------------------
    localparam CLOG_L2CAC_N = $clog2(`NUM_L2CACHE);

    //-------------------------------------------------------------------------
    // Task: Tile Read/Write Handling (Respond to L2 cache requests)
    //-------------------------------------------------------------------------
    task tile_read_and_write;
        input [CLOG_L2CAC_N-1:0] bus_n;  // Target bus number (maps to L2 instance)
    begin
        @(posedge clk);  // Synchronize to clock rising edge
        
        // 1. Assert ready to receive request from target L2
        out_a_ready_r[bus_n] = 1'b1;

        // 2. Handle read request (opcode = 4)
        if (out_a_valid_o[bus_n] & out_a_ready_i[bus_n] & 
            (out_a_opcode_o[(bus_n*`OP_BITS)+:`OP_BITS] == 4)) begin
            
            out_a_ready_r[bus_n] = 1'b0;  // Deassert ready to avoid duplicate requests
            // Prepare read response signals
            out_d_valid_r[bus_n]                             = 1'b1;
            out_d_opcode_r[bus_n*`OP_BITS+:`OP_BITS]         = 1'b1;
            out_d_size_r[bus_n*`SIZE_BITS+:`SIZE_BITS]       = out_a_size_o; 
            out_d_source_r[bus_n*`SOURCE_BITS+:`SOURCE_BITS] = out_a_source_o;
            out_d_param_r[bus_n*3+:3]                        = out_a_param_o; 
            // Read data from mem (byte-wise concatenation)
            for (int k = 0; k < `DCACHE_BLOCKWORDS*`BYTESOFWORD; k = k + 1) begin
                out_d_data_r[(bus_n*64 + (k+1)*8) - 1 -: 8] = mem[out_a_address_o + k];
            end
        end

        // 3. Handle write request (opcode = 0 or 1)
        else if (out_a_valid_o[bus_n] & out_a_ready_i[bus_n] & 
                 ((out_a_opcode_o[(bus_n*`OP_BITS)+:`OP_BITS] == 0) || 
                  (out_a_opcode_o[(bus_n*`OP_BITS)+:`OP_BITS] == 1))) begin
            
            out_a_ready_r[bus_n] = 1'b0;  // Deassert ready to avoid duplicate requests
            // Prepare write response signals
            out_d_valid_r[bus_n]                             = 1'b1;
            out_d_opcode_r[bus_n*`OP_BITS+:`OP_BITS]         = 1'b0;
            out_d_size_r[bus_n*`SIZE_BITS+:`SIZE_BITS]       = out_a_size_o; 
            out_d_source_r[bus_n*`SOURCE_BITS+:`SOURCE_BITS] = out_a_source_o;
            out_d_param_r[bus_n*3+:3]                        = out_a_param_o; 
            // Write data to mem (update if mask is 1, keep original if 0)
            for (int k = 0; k < `DCACHE_BLOCKWORDS*`BYTESOFWORD; k = k + 1) begin
                mem[out_a_address_o + k] = out_a_mask_o[k] ? out_a_data_o[(k+1)*8 - 1 -: 8] : mem[out_a_address_o + k];
            end
        end 

        // 4. Deassert response valid and re-assert request ready when L2 is ready
        else if (out_d_valid_i[bus_n] & out_d_ready_o[bus_n]) begin
            out_d_valid_r[bus_n] = 1'b0;
            out_a_ready_r[bus_n] = 1'b1;
        end
    end
    endtask

endmodule