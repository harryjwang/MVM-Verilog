`timescale 1ns/1ps

module ctrl #(
  parameter VEC_ADDRW       = 8,
  parameter MAT_ADDRW       = 9,
  parameter VEC_SIZEW       = VEC_ADDRW + 1,
  parameter MAT_SIZEW       = MAT_ADDRW + 1
)(
  input  logic                          clk,
  input  logic                          rst,
  input  logic                          start,

  // configuration inputs (still pure ports)
  input  logic [VEC_ADDRW-1:0]          vec_start_addr,
  input  logic [VEC_SIZEW-1:0]          vec_num_words,
  input  logic [MAT_ADDRW-1:0]          mat_start_addr,
  input  logic [MAT_SIZEW-1:0]          mat_num_rows_per_olane,

  // generated read-addresses
  output logic [VEC_ADDRW-1:0]          vec_raddr,
  output logic [MAT_ADDRW-1:0]          mat_raddr,

  // accumulation control
  output logic                          accum_first,
  output logic                          accum_last,
  output logic                          ovalid,
  output logic                          busy
);

  // State machine
  typedef enum logic [1:0] { IDLE, COMPUTE } state_t;
  state_t curr_state, next_state;

  // Counters & pointers
  logic [VEC_SIZEW-1:0] chunk_counter;
  logic [MAT_SIZEW-1:0] row_counter;
  logic [VEC_ADDRW-1:0] vec_addr_ptr;
  logic [MAT_ADDRW-1:0] mat_addr_ptr;

  // Register the start pulse
  logic start_d;
  always_ff @(posedge clk or posedge rst) begin
    if (rst) start_d <= 1'b0;
    else     start_d <= start;
  end
  wire start_pulse = start & ~start_d;

  // Shadow registers for sizes
  logic [VEC_SIZEW-1:0] r_vec_num_words;
  logic [MAT_SIZEW-1:0] r_mat_num_rows;

  // Sequential: state, counters, pointers, and shadow regs
  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      curr_state          <= IDLE;
      chunk_counter       <= '0;
      row_counter         <= '0;
      vec_addr_ptr        <= '0;
      mat_addr_ptr        <= '0;
      r_vec_num_words     <= '0;
      r_mat_num_rows      <= '0;
    end else begin
      curr_state <= next_state;

      if (curr_state == IDLE && start_pulse) begin
        // snapshot config and reset pointers/counters
        chunk_counter   <= '0;
        row_counter     <= '0;
        vec_addr_ptr    <= vec_start_addr;
        mat_addr_ptr    <= mat_start_addr;
        r_vec_num_words <= vec_num_words;
        r_mat_num_rows  <= mat_num_rows_per_olane;
      end
      else if (curr_state == COMPUTE) begin
        // advance chunk & row counters
        if (chunk_counter < r_vec_num_words - 1) begin
          chunk_counter <= chunk_counter + 1;
        end else begin
          chunk_counter <= '0;
          if (row_counter < r_mat_num_rows - 1)
            row_counter <= row_counter + 1;
          else
            row_counter <= '0;
        end

        // increment pointers in lock-step
        vec_addr_ptr <= vec_addr_ptr + 1;
        mat_addr_ptr <= mat_addr_ptr + 1;
      end
    end
  end

  // Next-state logic
  always_comb begin
    case (curr_state)
      IDLE:    next_state = start_pulse ? COMPUTE : IDLE;
      COMPUTE: next_state = (row_counter == r_mat_num_rows-1 &&
                             chunk_counter == r_vec_num_words-1)
                            ? IDLE
                            : COMPUTE;
      default: next_state = IDLE;
    endcase
  end

  // Outputs (all registered datapath yields clean timing)
  always_comb begin
    busy        = (curr_state == COMPUTE);
    accum_first = (curr_state == COMPUTE && chunk_counter == 0);
    accum_last  = (curr_state == COMPUTE && chunk_counter == r_vec_num_words-1);
    ovalid      = (chunk_counter == r_vec_num_words-1 &&
                   row_counter   == r_mat_num_rows-1);
    vec_raddr   = (curr_state == COMPUTE) ? vec_addr_ptr : '0;
    mat_raddr   = (curr_state == COMPUTE) ? mat_addr_ptr : '0;
  end

endmodule