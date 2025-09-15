module ctrl # (
  parameter VEC_ADDRW  = 8,
  parameter MAT_ADDRW  = 9,
  parameter VEC_SIZEW  = VEC_ADDRW + 1,
  parameter MAT_SIZEW  = MAT_ADDRW + 1
)(
  input  logic                    clk,
  input  logic                    rst,
  input  logic                    start,
  input  logic [VEC_ADDRW-1:0]    vec_start_addr,
  input  logic [VEC_SIZEW-1:0]    vec_num_words,
  input  logic [MAT_ADDRW-1:0]    mat_start_addr,
  input  logic [MAT_SIZEW-1:0]    mat_num_rows_per_olane,
  output logic [VEC_ADDRW-1:0]    vec_raddr,
  output logic [MAT_ADDRW-1:0]    mat_raddr,
  output logic                    accum_first,
  output logic                    accum_last,
  output logic                    ovalid,
  output logic                    busy
);

typedef enum logic [0:1] {
 IDLE, COMPUTE 
} state_t;

state_t curr_state, next_state;
    
logic [VEC_SIZEW-1:0] chunk_counter;
logic [MAT_SIZEW-1:0] row_counter;

  // 1) register past start
logic start_d;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin                
            start_d <= 1'b0;
        end else begin                    
            start_d <= start;
        end
    end

  // 2) detect rising edge (for start signal)
wire start_pulse = start & ~start_d;
  
  // register inputs
    logic [VEC_ADDRW-1:0]    r_vec_start_addr;
    logic [VEC_SIZEW-1:0]    r_vec_num_words;
    logic [MAT_ADDRW-1:0]    r_mat_start_addr;
    logic [MAT_SIZEW-1:0]    r_mat_num_rows_per_olane;

  // sequential: state + counters
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            curr_state    <= IDLE;
            chunk_counter <= '0;
            row_counter   <= '0;
        end else begin
            curr_state <= next_state;            
            if (curr_state == IDLE && start_pulse) begin
                chunk_counter <= '0;
                row_counter   <= '0;                                                             
                r_vec_start_addr <= vec_start_addr;                
                r_vec_num_words <= vec_num_words;                  
                r_mat_start_addr <= mat_start_addr;                
                r_mat_num_rows_per_olane <= mat_num_rows_per_olane;
            end else if (curr_state == COMPUTE) begin
                if (chunk_counter < r_vec_num_words - 1) begin
                    chunk_counter <= chunk_counter + 1;
                end else begin
                    chunk_counter <= '0;
                    if (row_counter < r_mat_num_rows_per_olane - 1) begin
                        row_counter <= row_counter + 1;
                    end else begin
                        row_counter <= '0;
                    end
                end
            end
        end
    end

  // next-state using pulse
    always_comb begin
        case (curr_state)
            IDLE:
            next_state = start_pulse ? COMPUTE : IDLE;
            
            COMPUTE:
            next_state = (row_counter == r_mat_num_rows_per_olane - 1 && chunk_counter == r_vec_num_words   - 1) ? IDLE : COMPUTE;
            
            default: next_state = IDLE;
        endcase
    end

  // outputs
    always_comb begin
        busy        = (curr_state == COMPUTE);
        accum_first = (curr_state == COMPUTE && chunk_counter == 0);
        accum_last  = (curr_state == COMPUTE && chunk_counter == r_vec_num_words - 1);
        ovalid      = (chunk_counter == r_vec_num_words - 1 && row_counter   == r_mat_num_rows_per_olane - 1);
        vec_raddr   = (curr_state == COMPUTE) ? r_vec_start_addr + chunk_counter : '0;
        mat_raddr   = (curr_state == COMPUTE) ? r_mat_start_addr + row_counter * r_vec_num_words + chunk_counter : '0;
    end
endmodule