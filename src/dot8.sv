/***************************************************/
/* ECE 327: Digital Hardware Systems - Spring 2025 */
/* Lab 4                                           */
/* 8-Lane Dot Product Module                       */
/***************************************************/

module dot8 # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32
)(
    input clk,
    input rst,
    input logic signed [8*IWIDTH-1:0] vec0,
    input signed [8*IWIDTH-1:0] vec1,
    input ivalid,
    output logic signed [OWIDTH-1:0] result,
    output logic ovalid
);

/******* Your code starts here *******/

logic signed [IWIDTH-1:0] input_reg_a0, input_reg_a1, input_reg_a2, input_reg_a3, input_reg_a4, input_reg_a5, input_reg_a6, input_reg_a7;
logic signed [IWIDTH-1:0] input_reg_b0, input_reg_b1, input_reg_b2, input_reg_b3, input_reg_b4, input_reg_b5, input_reg_b6, input_reg_b7;

logic signed [(2*IWIDTH) - 1:0] mult_reg_0, mult_reg_1, mult_reg_2, mult_reg_3, mult_reg_4, mult_reg_5, mult_reg_6, mult_reg_7;

logic signed [(2*IWIDTH):0] add1_reg_0, add1_reg_1, add1_reg_2, add1_reg_3;

logic signed [(2*IWIDTH) + 1:0] add2_reg_0, add2_reg_1;

logic valid_0, valid_1, valid_2, valid_3;


always_ff @(posedge clk) begin
    if (rst) begin
        input_reg_a0 <= 0; input_reg_a1 <= 0; input_reg_a2 <= 0; input_reg_a3 <= 0; input_reg_a4 <= 0; input_reg_a5 <= 0; input_reg_a6 <= 0; input_reg_a7 <= 0;
        input_reg_b0 <= 0; input_reg_b1 <= 0; input_reg_b2 <= 0; input_reg_b3 <= 0; input_reg_b4 <= 0; input_reg_b5 <= 0; input_reg_b6 <= 0; input_reg_b7 <= 0;
       
       
        mult_reg_0 <= 0; mult_reg_1 <= 0; mult_reg_2 <= 0; mult_reg_3 <= 0;
        mult_reg_4 <= 0; mult_reg_5 <= 0; mult_reg_6 <= 0; mult_reg_7 <= 0;
       
        add1_reg_0 <= 0; add1_reg_1 <= 0; add1_reg_2 <= 0; add1_reg_3 <= 0;
       
        add2_reg_0 <= 0; add2_reg_1 <= 0;
       
        valid_0 <= 0; valid_1 <= 0; valid_2 <= 0; valid_3 <= 0;
       
        result <= 0;
       
        ovalid <= 1;
       
    end else begin
   
        // Registering Stage
        input_reg_a0 <= vec0[IWIDTH-1:0]; input_reg_a1 <= vec0[(2*IWIDTH)-1:IWIDTH]; input_reg_a2 <= vec0[(3*IWIDTH)-1:2*IWIDTH]; input_reg_a3 <= vec0[(4*IWIDTH)-1:3*IWIDTH];
        input_reg_a4 <= vec0[(5*IWIDTH)-1:4*IWIDTH]; input_reg_a5 <= vec0[(6*IWIDTH)-1:5*IWIDTH]; input_reg_a6 <= vec0[(7*IWIDTH)-1:6*IWIDTH]; input_reg_a7 <= vec0[(8*IWIDTH)-1:7*IWIDTH];
       
        input_reg_b0 <= vec1[IWIDTH-1:0]; input_reg_b1 <= vec1[(2*IWIDTH)-1:IWIDTH]; input_reg_b2 <= vec1[(3*IWIDTH)-1:2*IWIDTH]; input_reg_b3 <= vec1[(4*IWIDTH)-1:3*IWIDTH];
        input_reg_b4 <= vec1[(5*IWIDTH)-1:4*IWIDTH]; input_reg_b5 <= vec1[(6*IWIDTH)-1:5*IWIDTH]; input_reg_b6 <= vec1[(7*IWIDTH)-1:6*IWIDTH]; input_reg_b7 <= vec1[(8*IWIDTH)-1:7*IWIDTH];
        valid_0 <= ivalid;                    // for latency intesive, we need i_valid for this
       
        // Multiplication Stage
        mult_reg_0 <= input_reg_a0 * input_reg_b0; mult_reg_1 <= input_reg_a1 * input_reg_b1; mult_reg_2 <= input_reg_a2 * input_reg_b2; mult_reg_3 <= input_reg_a3 * input_reg_b3;
        mult_reg_4 <= input_reg_a4 * input_reg_b4; mult_reg_5 <= input_reg_a5 * input_reg_b5; mult_reg_6 <= input_reg_a6 * input_reg_b6; mult_reg_7 <= input_reg_a7 * input_reg_b7;        
        valid_1 <= valid_0;

        // First Addition Stage
        add1_reg_0 <= mult_reg_0 + mult_reg_1; add1_reg_1 <= mult_reg_2 + mult_reg_3; add1_reg_2 <= mult_reg_4 + mult_reg_5; add1_reg_3 <= mult_reg_6 + mult_reg_7;
        valid_2 <= valid_1;

        // Second Addition Stage
        add2_reg_0 <= add1_reg_0 + add1_reg_1; add2_reg_1 <= add1_reg_2 + add1_reg_3;    
        valid_3 <= valid_2;

        // Result
        result <= add2_reg_0 + add2_reg_1;
        ovalid <= valid_3;
   end
end

/******* Your code ends here ********/

endmodule
