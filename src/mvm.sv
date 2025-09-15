/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2025 */
/* Lab 4                                           */
/* Matrix-Vector Mult. (MVM) Module                */
/***************************************************/

module mvm # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32,
    parameter MEM_DATAW = IWIDTH * 8,
    parameter VEC_MEM_DEPTH = 256,
    parameter VEC_ADDRW = $clog2(VEC_MEM_DEPTH),
    parameter MAT_MEM_DEPTH = 512,
    parameter MAT_ADDRW = $clog2(MAT_MEM_DEPTH),
    parameter NUM_OLANES = 8
)(
    input  logic                   clk,
    input  logic                   rst,

    // vector write port
    input  logic [MEM_DATAW-1:0]   i_vec_wdata,
    input  logic [VEC_ADDRW-1:0]   i_vec_waddr,
    input  logic                   i_vec_wen,

    // matrix write ports (one per lane)
    input  logic [MEM_DATAW-1:0]   i_mat_wdata,
    input  logic [MAT_ADDRW-1:0]   i_mat_waddr,
    input  logic [NUM_OLANES-1:0]  i_mat_wen,

    // start & MVM params
    input  logic                   i_start,
    input  logic [VEC_ADDRW-1:0]   i_vec_start_addr,
    input  logic [VEC_ADDRW:0]     i_vec_num_words,
    input  logic [MAT_ADDRW-1:0]   i_mat_start_addr,
    input  logic [MAT_ADDRW:0]     i_mat_num_rows_per_olane,

    // outputs
    output logic                   o_busy,
    output logic [OWIDTH-1:0]      o_result  [0:NUM_OLANES-1],
    output logic                   o_valid
);

  // ----------------------------------------------------
  // Vector RAM + single controller
  // ----------------------------------------------------
  logic [VEC_ADDRW-1:0]  cntrl_vec_raddr;
  logic [MEM_DATAW-1:0]  r_vec_data;
  
  mem #(
    .DATAW(MEM_DATAW),
    .DEPTH(VEC_MEM_DEPTH),
    .ADDRW(VEC_ADDRW)
  ) vec_mem_inst (
    .clk   (clk),
    .wdata (i_vec_wdata),
    .waddr (i_vec_waddr),
    .wen   (i_vec_wen),
    .raddr (cntrl_vec_raddr),
    .rdata (r_vec_data)
  );

  logic [MAT_ADDRW-1:0] cntrl_mat_raddr;
  logic                  cntrl_accum_first, cntrl_accum_last;
  logic                  cntrl_busy;

  ctrl #(
    .VEC_ADDRW(VEC_ADDRW),
    .MAT_ADDRW(MAT_ADDRW)
  ) ctrl_inst (
    .clk                    (clk),
    .rst                    (rst),
    .start                  (i_start),
    .vec_start_addr         (i_vec_start_addr),
    .vec_num_words          (i_vec_num_words),
    .mat_start_addr         (i_mat_start_addr),
    .mat_num_rows_per_olane (i_mat_num_rows_per_olane),
    .vec_raddr              (cntrl_vec_raddr),
    .mat_raddr              (cntrl_mat_raddr),
    .accum_first            (cntrl_accum_first),
    .accum_last             (cntrl_accum_last),
    .ovalid                 (cntrl_ovalid),
    .busy                   (cntrl_busy)
  );

  // ----------------------------------------------------
  // Pipeline controller signals to match mem latency
  // ----------------------------------------------------
  logic [6:1] busy_r;
  logic [6:1] first_r;
  logic [6:1] last_r;

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      busy_r <= 7'b0;
      first_r <= 7'b0;
      last_r <= 7'b0;
    end else begin
      // stage 1: latch controller outputs
        busy_r[1]  <= cntrl_busy;
        first_r[1] <= cntrl_accum_first;
        last_r[1] <= cntrl_accum_last;
        
        busy_r[2]  <= busy_r[1];
        first_r[2] <= first_r[1];
        last_r [2] <= last_r [1];
        
        // dot8: cycles 3-7
        busy_r[3]  <= busy_r[2];
        first_r[3] <= first_r[2];
        last_r [3] <= last_r [2];
    
        busy_r[4]  <= busy_r[3];
        first_r[4] <= first_r[3];
        last_r [4] <= last_r [3];
    
        busy_r[5]  <= busy_r[4];
        first_r[5] <= first_r[4];
        last_r [5] <= last_r [4];
    
        busy_r[6]  <= busy_r[5];
        first_r[6] <= first_r[5];
        last_r [6] <= last_r [5];
    end
  end

  // ----------------------------------------------------
  // Per-lane MVM datapath
  // ----------------------------------------------------
  logic [MEM_DATAW-1:0] r_mat_data       [NUM_OLANES];
  logic [OWIDTH-1:0]    r_dot_result     [NUM_OLANES];
  logic                 r_dot_res_valid  [NUM_OLANES];
  logic [NUM_OLANES-1:0] r_accum_res_valid;
  
  
  genvar computation_num;
  generate
    for (computation_num = 0; computation_num < NUM_OLANES; computation_num = computation_num + 1) begin : OLANE
      // matrix memory for this lane
      mem #(
        .DATAW(MEM_DATAW),
        .DEPTH(MAT_MEM_DEPTH),
        .ADDRW(MAT_ADDRW)
      ) mat_mem_inst (
        .clk   (clk),
        .wdata (i_mat_wdata),
        .waddr (i_mat_waddr),
        .wen   (i_mat_wen[computation_num]),
        .raddr (cntrl_mat_raddr),
        .rdata (r_mat_data[computation_num])
      );

      // dot-product engine: use busy_d2 as ivalid
      dot8 #(
        .IWIDTH(IWIDTH),
        .OWIDTH(OWIDTH)
      ) dot8_inst (
        .clk    (clk),
        .rst    (rst),
        .vec0   (r_vec_data),
        .vec1   (r_mat_data[computation_num]),
        .ivalid (busy_r[1]),
        .result (r_dot_result[computation_num]),
        .ovalid (r_dot_res_valid[computation_num])
      );

      // accumulator: use first_d2/last_d2 aligned with dot result
      accum #(
        .DATAW(OWIDTH),
        .ACCUMW(OWIDTH)
      ) accum_inst (
        .clk    (clk),
        .rst    (rst),
        .data   (r_dot_result[computation_num]),
        .ivalid (r_dot_res_valid[computation_num]),
        .first  (first_r[6]),
        .last   (last_r[6]),
        .result (o_result[computation_num]),
        .ovalid (r_accum_res_valid[computation_num])
      );
    end
  endgenerate

  // top-level busy = controller busy
  assign o_busy  = cntrl_busy;
  // valid when all lanes have done their last
  assign o_valid  = &r_accum_res_valid;

endmodule

