`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_processor(input wire         clk,             // main clock
                     input wire         rst,             // global reset
                     input wire         gwe,             // global we for single-step clock

                     output wire [15:0] o_cur_pc,        // address to read from instruction memory
                     input wire [15:0]  i_cur_insn_A,    // output of instruction memory (pipe A)
                     input wire [15:0]  i_cur_insn_B,    // output of instruction memory (pipe B)

                     output wire [15:0] o_dmem_addr,     // address to read/write from/to data memory
                     input wire [15:0]  i_cur_dmem_data, // contents of o_dmem_addr
                     output wire        o_dmem_we,       // data memory write enable
                     output wire [15:0] o_dmem_towrite,  // data to write to o_dmem_addr if we is set

                     // testbench signals (always emitted from the WB stage)
                     output wire [ 1:0] test_stall_A,        // is this a stall cycle?  (0: no stall,
                     output wire [ 1:0] test_stall_B,        // 1: pipeline stall, 2: branch stall, 3: load stall)

                     output wire [15:0] test_cur_pc_A,       // program counter
                     output wire [15:0] test_cur_pc_B,
                     output wire [15:0] test_cur_insn_A,     // instruction bits
                     output wire [15:0] test_cur_insn_B,
                     output wire        test_regfile_we_A,   // register file write-enable
                     output wire        test_regfile_we_B,
                     output wire [ 2:0] test_regfile_wsel_A, // which register to write
                     output wire [ 2:0] test_regfile_wsel_B,
                     output wire [15:0] test_regfile_data_A, // data to write to register file
                     output wire [15:0] test_regfile_data_B,
                     output wire        test_nzp_we_A,       // nzp register write enable
                     output wire        test_nzp_we_B,
                     output wire [ 2:0] test_nzp_new_bits_A, // new nzp bits
                     output wire [ 2:0] test_nzp_new_bits_B,
                     output wire        test_dmem_we_A,      // data memory write enable
                     output wire        test_dmem_we_B,
                     output wire [15:0] test_dmem_addr_A,    // address to read/write from/to memory
                     output wire [15:0] test_dmem_addr_B,
                     output wire [15:0] test_dmem_data_A,    // data to read/write from/to memory
                     output wire [15:0] test_dmem_data_B,

                     // zedboard switches/display/leds (ignore if you don't want to control these)
                     input  wire [ 7:0] switch_data,         // read on/off status of zedboard's 8 switches
                     output wire [ 7:0] led_data             // set on/off status of zedboard's 8 leds
                     );

   /***  YOUR CODE HERE ***/
   //========================================= F ============================================// 
   // pc wires attached to the PC register's ports
   wire [15:0] F_pc_out;   // Current program counter (read out from pc_reg)
   wire [15:0] F_pc_in = Switch ? pc_plus_one : 
                         flush_B ? X_alu_result_B : 
                         flush_A ? X_alu_result_A : pc_plus_two;    // Next program counter (you compute this and feed it into next_pc) 
   wire [15:0] pc_plus_one; 
   wire [15:0] pc_plus_two;
   wire pc_we;

   Nbit_reg #(16, 16'h8200) pc_reg_A (.in(F_pc_in), .out(F_pc_out), .clk(clk), .we(pc_we), .gwe(gwe), .rst(rst));

   assign o_cur_pc = F_pc_out;
  
   // Program counter register, starts at 8200h at bootup 
   cla16 adder_A (.a(F_pc_out), .b(16'h1), .cin(1'b0), .sum(pc_plus_one)); // pc_B = pc_A + 1
   cla16 adder_B (.a(F_pc_out), .b(16'h2), .cin(1'b0), .sum(pc_plus_two));

   //========================================= D ============================================// 
   wire [15:0] D_pc_out_A;
   wire [15:0] D_pc_out_B;
   wire [15:0] D_ir_out_A;
   wire [15:0] D_ir_out_B;
   wire D_we_A;
   wire D_we_B;

   wire [15:0] D_ir_in_A = Switch ? D_ir_out_B : (flush_A || flush_B) ? 16'b0 : i_cur_insn_A;
   wire [15:0] D_ir_in_B = Switch ? i_cur_insn_A : (flush_A || flush_B) ? 16'b0 : i_cur_insn_B;
   wire [15:0] D_pc_in_A = Switch ? D_pc_out_B : F_pc_out;
   wire [15:0] D_pc_in_B = Switch ? F_pc_out : pc_plus_one;
   

   Nbit_reg #(16, 0) D_pc_reg_A (.in(D_pc_in_A), .out(D_pc_out_A), .clk(clk), .we(D_we_A), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) D_pc_reg_B (.in(D_pc_in_B), .out(D_pc_out_B), .clk(clk), .we(D_we_B), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 0) D_ir_reg_A (.in(D_ir_in_A), .out(D_ir_out_A), .clk(clk), .we(D_we_A), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) D_ir_reg_B (.in(D_ir_in_B), .out(D_ir_out_B), .clk(clk), .we(D_we_B), .gwe(gwe), .rst(rst));

   wire [2:0] D_r1sel_A;  // rs
   wire [2:0] D_r2sel_A;
   wire [2:0] D_r1sel_B;  // rt
   wire [2:0] D_r2sel_B;
   wire [2:0] D_wsel_A;   // rd
   wire [2:0] D_wsel_B;
   wire D_r1re_A, D_r2re_A, D_select_pc_plus_one_A, D_is_load_A, D_is_store_A, D_is_branch_A, D_is_control_insn_A, D_nzp_we_A, D_regfile_we_A;
   wire D_r1re_B, D_r2re_B, D_select_pc_plus_one_B, D_is_load_B, D_is_store_B, D_is_branch_B, D_is_control_insn_B, D_nzp_we_B, D_regfile_we_B;

   lc4_decoder d_decoder_A (
      .insn(D_ir_out_A),                            // instruction in 
      .r1sel(D_r1sel_A),                            // rs [2:0]
      .r1re(D_r1re_A),                              // does this instruction read from rs? [3]
      .r2sel(D_r2sel_A),                            // rt [6:4]
      .r2re(D_r2re_A),                              // does this instruction read from rt? [7]
      .wsel(D_wsel_A),                              // rd [10:8]
      .regfile_we(D_regfile_we_A),                  // does this instruction write to rd? [11]
      .nzp_we(D_nzp_we_A),                          // does this instruction write the NZP bits? [12]
      .select_pc_plus_one(D_select_pc_plus_one_A),  // write PC+1 to the regfile? [13]
      .is_load(D_is_load_A),                        // is this a load instruction? [14]
      .is_store(D_is_store_A),                      // is this a store instruction? [15]
      .is_branch(D_is_branch_A),                    // is this a branch instruction? [16]
      .is_control_insn(D_is_control_insn_A)         // is this a control instruction (JSR, JSRR, RTI, JMPR, JMP, TRAP)? [17]
   );

   lc4_decoder d_decoder_B (
      .insn(D_ir_out_B),                            // instruction in 
      .r1sel(D_r1sel_B),                            // rs [2:0]
      .r1re(D_r1re_B),                              // does this instruction read from rs? [3]
      .r2sel(D_r2sel_B),                            // rt [6:4]
      .r2re(D_r2re_B),                              // does this instruction read from rt? [7]
      .wsel(D_wsel_B),                              // rd [10:8]
      .regfile_we(D_regfile_we_B),                  // does this instruction write to rd? [11]
      .nzp_we(D_nzp_we_B),                          // does this instruction write the NZP bits? [12]
      .select_pc_plus_one(D_select_pc_plus_one_B),  // write PC+1 to the regfile? [13]
      .is_load(D_is_load_B),                        // is this a load instruction? [14]
      .is_store(D_is_store_B),                      // is this a store instruction? [15]
      .is_branch(D_is_branch_B),                    // is this a branch instruction? [16]
      .is_control_insn(D_is_control_insn_B)         // is this a control instruction (JSR, JSRR, RTI, JMPR, JMP, TRAP)? [17]
   );

   wire [17:0] D_ctrl_out_A = {D_is_control_insn_A, D_is_branch_A, D_is_store_A, D_is_load_A, D_select_pc_plus_one_A,
                            D_nzp_we_A, D_regfile_we_A, D_wsel_A, D_r2re_A, D_r2sel_A, D_r1re_A, D_r1sel_A};

   wire [17:0] D_ctrl_out_B = {D_is_control_insn_B, D_is_branch_B, D_is_store_B, D_is_load_B, D_select_pc_plus_one_B,
                            D_nzp_we_B, D_regfile_we_B, D_wsel_B, D_r2re_B, D_r2sel_B, D_r1re_B, D_r1sel_B};

   wire [15:0] D_rs_data_A; //pipe A: output
   wire [15:0] D_rt_data_A; //pipe A: output
   wire [15:0] W_rd_data_A; //pipe A: input

   wire [15:0] D_rs_data_B; //pipe B: output
   wire [15:0] D_rt_data_B; //pipe B: output
   wire [15:0] W_rd_data_B; //pipe B: input

   lc4_regfile_ss regfile (
      .clk(clk),
      .gwe(gwe),
      .rst(rst),

      .i_rs_A(D_r1sel_A),        // pipe A: rs selector
      .o_rs_data_A(D_rs_data_A), // pipe A: rs contents
      .i_rt_A(D_r2sel_A),        // pipe A: rt selector
      .o_rt_data_A(D_rt_data_A), // pipe A: rt contents

      .i_rs_B(D_r1sel_B),        // pipe B: rs selector
      .o_rs_data_B(D_rs_data_B), // pipe B: rs contents
      .i_rt_B(D_r2sel_B),        // pipe B: rt selector
      .o_rt_data_B(D_rt_data_B), // pipe B: rt contents

      .i_rd_A(W_wsel_A),         // pipe A: rd selector
      .i_wdata_A(W_rd_data_A),   // pipe A: data to write
      .i_rd_we_A(W_regfile_we_A), // pipe A: write enable

      .i_rd_B(W_wsel_B),        // pipe B: rd selector
      .i_wdata_B(W_rd_data_B),   // pipe B: data to write
      .i_rd_we_B(W_regfile_we_B) // pipe B: write enable
   );

   assign X_r1data_in_A = D_rs_data_A;
   assign X_r2data_in_A = D_rt_data_A;

   assign X_r1data_in_B = D_rs_data_B;
   assign X_r2data_in_B = D_rt_data_B;

   // ============== Dependencies =================//
   
   // 1. LTU dependence with dest = D.A     from X.A to D.A or from X.B to D.A
   wire LTU_A_A2A = X_is_load_A && ((D_r1sel_A == X_wsel_A && D_r1re_A) || ((D_r2sel_A == X_wsel_A) && !D_is_store_A && D_r2re_A) || D_is_branch_A);
   wire LTU_A_B2A = X_is_load_B && ((D_r1sel_A == X_wsel_B && D_r1re_A) || ((D_r2sel_A == X_wsel_B) && !D_is_store_A && D_r2re_A) || D_is_branch_A);
   // wire LTU_A = (LTU_A_A2A && (X_wsel_B != D_r1sel_A && D_r1re_A || X_wsel_B != D_r2sel_A && D_r2re_A)) || LTU_A_B2A;
   wire LTU_A = (LTU_A_A2A && !(X_wsel_B == X_wsel_A && X_regfile_we_B && X_regfile_we_A)) || LTU_A_B2A;

   // 2. LTU dependence with dest = D.B     from X.A to D.B or from X.B to D.B
   wire LTU_B_A2B = X_is_load_A && ((D_r1sel_B == X_wsel_A && D_r1re_B) || ((D_r2sel_B == X_wsel_A) && !D_is_store_B && D_r2re_B) || D_is_branch_B);
   wire LTU_B_B2B = X_is_load_B && ((D_r1sel_B == X_wsel_B && D_r1re_B) || ((D_r2sel_B == X_wsel_B) && !D_is_store_B && D_r2re_B) || D_is_branch_B);
   // wire LTU_B = (LTU_B_A2B && (X_wsel_B != D_r1sel_B && D_r1re_B || X_wsel_B != D_r2sel_B && D_r2re_B)) || LTU_B_B2B;
   wire LTU_B = (LTU_B_A2B && !(X_wsel_B == X_wsel_A && X_regfile_we_A && X_regfile_we_B)) || LTU_B_B2B;

   // 3. Dependence from D.A to D.B (including the case where D.A is a load)
   wire AB_dep = (D_wsel_A == D_r1sel_B && D_regfile_we_A && D_r1re_B) || 
                 (D_wsel_A == D_r2sel_B && D_regfile_we_A && D_r2re_B && !D_is_store_B) ||
                 (D_is_branch_B && D_nzp_we_A); // NZP write to branch

   // 4. Structural hazard (both D.A and D.B access memory)
   wire struc_haz = D_is_load_A && D_is_load_B || D_is_load_A && D_is_store_B || 
                    D_is_store_A && D_is_load_B || D_is_store_A && D_is_store_B;

   // ================= Stall ======================//

   wire [1:0] stall_A = LTU_A ? 2'd3 : 2'd0;
   wire [1:0] stall_B = LTU_A ? 2'd1 : (struc_haz || AB_dep) ? 2'd1 : LTU_B ? 2'd3 : 2'd0;

   assign pc_we = !LTU_A;
   assign D_we_A = !LTU_A; // pipe A Decode stall
   assign D_we_B = !LTU_A; // pipe B Decode stall

   assign X_ir_in_A = LTU_A ? 16'b0 : (flush_A || flush_B) ? 16'd0 : D_ir_out_A;
   assign X_ir_in_B = Switch ? 16'b0 : (flush_A || flush_B) ? 16'd0 : D_ir_out_B;
   
   // ============== Switch =================//
   // add switch logic to X input    for 5 reg
   wire Switch = LTU_A || LTU_B || AB_dep || struc_haz; // pipe B stall // LTU_A no need

   //========================================= X ============================================// 
   wire [15:0] X_pc_out_A;  //pc A
   wire [15:0] X_pc_out_B;  //pc B

   wire [15:0] X_ir_in_A;   // pipe A:
   wire [15:0] X_ir_out_A;  // pipe A:

   wire [15:0] X_ir_in_B;   // pipe B:
   wire [15:0] X_ir_out_B;  // pipe B:

   wire [15:0] X_r1data_in_A;    // pipe A:
   wire [15:0] X_r1data_out_A;   // pipe A:
   wire [15:0] X_r2data_in_A;    // pipe A:
   wire [15:0] X_r2data_out_A;   // pipe A:
   wire [17:0] X_ctrl_out_A;     // pipe A:

   wire [15:0] X_r1data_in_B;    // pipe B:
   wire [15:0] X_r1data_out_B;   // pipe B:
   wire [15:0] X_r2data_in_B;    // pipe B:
   wire [15:0] X_r2data_out_B;   // pipe B:
   wire [17:0] X_ctrl_out_B;     // pipe B:

   wire X_we = 1'b1;
 
   Nbit_reg #(16, 0) X_pc_reg_A (.in(D_pc_out_A), .out(X_pc_out_A), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) X_pc_reg_B (.in(D_pc_out_B), .out(X_pc_out_B), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 0) X_ir_reg_A (.in(X_ir_in_A), .out(X_ir_out_A), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) X_ir_reg_B (.in(X_ir_in_B), .out(X_ir_out_B), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 0) X_r1data_reg_A (.in(X_r1data_in_A), .out(X_r1data_out_A), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) X_r2data_reg_A (.in(X_r2data_in_A), .out(X_r2data_out_A), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(18, 0) X_ctrl_reg_A (.in(D_ctrl_out_A), .out(X_ctrl_out_A), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst||LTU_A||flush_A||flush_B)); //stall & flush 

   Nbit_reg #(16, 0) X_r1data_reg_B (.in(X_r1data_in_B), .out(X_r1data_out_B), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) X_r2data_reg_B (.in(X_r2data_in_B), .out(X_r2data_out_B), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(18, 0) X_ctrl_reg_B (.in(D_ctrl_out_B), .out(X_ctrl_out_B), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst||Switch||flush_A||flush_B)); // || flush

   wire [15:0] X_r1_ALUin_A; // MUX bypass
   wire [15:0] X_r2_ALUin_A; // MUX bypass

   wire [15:0] X_r1_ALUin_B; // MUX bypass
   wire [15:0] X_r2_ALUin_B; // MUX bypass

   wire [15:0] X_alu_result_A;
   wire [15:0] X_alu_result_B;

   lc4_alu alu_A(
      .i_insn(X_ir_out_A),
      .i_pc(X_pc_out_A),
      .i_r1data(X_r1_ALUin_A),
      .i_r2data(X_r2_ALUin_A),
      .o_result(X_alu_result_A)
   );

   lc4_alu alu_B(
      .i_insn(X_ir_out_B),
      .i_pc(X_pc_out_B),
      .i_r1data(X_r1_ALUin_B),
      .i_r2data(X_r2_ALUin_B),
      .o_result(X_alu_result_B)
   );

   //pipe A:
   wire [2:0] X_r1sel_A = X_ctrl_out_A[2:0];    // rs
   wire X_r1re_A = X_ctrl_out_A[3];
   wire [2:0] X_r2sel_A = X_ctrl_out_A[6:4];    // rt
   wire X_r2re_A = X_ctrl_out_A[7];
   wire [2:0] X_wsel_A = X_ctrl_out_A[10:8];    // rd
   wire X_regfile_we_A = X_ctrl_out_A[11];
   wire X_nzp_we_A = X_ctrl_out_A[12];
   wire X_select_pc_plus_one_A = X_ctrl_out_A[13];
   wire X_is_load_A = X_ctrl_out_A[14];
   wire X_is_store_A = X_ctrl_out_A[15];
   wire X_is_branch_A = X_ctrl_out_A[16];
   wire X_is_control_insn_A = X_ctrl_out_A[17];

   //pipe B:
   wire [2:0] X_r1sel_B = X_ctrl_out_B[2:0];    // rs
   wire X_r1re_B = X_ctrl_out_B[3];
   wire [2:0] X_r2sel_B = X_ctrl_out_B[6:4];    // rt
   wire X_r2re_B = X_ctrl_out_B[7];
   wire [2:0] X_wsel_B = X_ctrl_out_B[10:8];    // rd
   wire X_regfile_we_B = X_ctrl_out_B[11];
   wire X_nzp_we_B = X_ctrl_out_B[12];
   wire X_select_pc_plus_one_B = X_ctrl_out_B[13];
   wire X_is_load_B = X_ctrl_out_B[14];
   wire X_is_store_B = X_ctrl_out_B[15];
   wire X_is_branch_B = X_ctrl_out_B[16];
   wire X_is_control_insn_B = X_ctrl_out_B[17];

   // ===================================== M =======================================// 
   //pipe A & pipe B:
   wire [15:0] M_O_out_A;
   wire [15:0] M_r2data_out_A;
   wire [15:0] M_ir_out_A;
   wire [15:0] M_pc_out_A;
   wire [17:0] M_ctrl_out_A;

   wire [15:0] M_O_out_B;
   wire [15:0] M_r2data_out_B;
   wire [15:0] M_ir_out_B;
   wire [15:0] M_pc_out_B;
   wire [17:0] M_ctrl_out_B;

   wire [15:0] M_ir_in_B = flush_A ? 16'b0 : X_ir_out_B;

   wire M_we = 1'b1;

   Nbit_reg #(16, 0) M_O_reg_A (.in(X_alu_result_A), .out(M_O_out_A), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) M_r2data_reg_A (.in(X_r2_ALUin_A), .out(M_r2data_out_A), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) M_ir_reg_A (.in(X_ir_out_A), .out(M_ir_out_A), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) M_pc_reg_A (.in(X_pc_out_A), .out(M_pc_out_A), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(18, 0) M_ctrl_reg_A (.in(X_ctrl_out_A), .out(M_ctrl_out_A), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));

   Nbit_reg #(16, 0) M_O_reg_B (.in(X_alu_result_B), .out(M_O_out_B), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) M_r2data_reg_B (.in(X_r2_ALUin_B), .out(M_r2data_out_B), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) M_ir_reg_B (.in(M_ir_in_B), .out(M_ir_out_B), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) M_pc_reg_B (.in(X_pc_out_B), .out(M_pc_out_B), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(18, 0) M_ctrl_reg_B (.in(X_ctrl_out_B), .out(M_ctrl_out_B), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst||flush_A));


   wire [2:0] M_r1sel_A = M_ctrl_out_A[2:0];    // rs
   wire M_r1re_A = M_ctrl_out_A[3];
   wire [2:0] M_r2sel_A = M_ctrl_out_A[6:4];    // rt
   wire M_r2re_A = M_ctrl_out_A[7];
   wire [2:0] M_wsel_A = M_ctrl_out_A[10:8];    // rd
   wire M_regfile_we_A = M_ctrl_out_A[11];
   wire M_nzp_we_A = M_ctrl_out_A[12];
   wire M_select_pc_plus_one_A = M_ctrl_out_A[13];
   wire M_is_load_A = M_ctrl_out_A[14];
   wire M_is_store_A = M_ctrl_out_A[15];
   wire M_is_branch_A = M_ctrl_out_A[16];
   wire M_is_control_insn_A = M_ctrl_out_A[17];

   wire [2:0] M_r1sel_B = M_ctrl_out_B[2:0];    // rs
   wire M_r1re_B = M_ctrl_out_B[3];
   wire [2:0] M_r2sel_B = M_ctrl_out_B[6:4];    // rt
   wire M_r2re_B = M_ctrl_out_B[7];
   wire [2:0] M_wsel_B = M_ctrl_out_B[10:8];    // rd
   wire M_regfile_we_B = M_ctrl_out_B[11];
   wire M_nzp_we_B = M_ctrl_out_B[12];
   wire M_select_pc_plus_one_B = M_ctrl_out_B[13];
   wire M_is_load_B = M_ctrl_out_B[14];
   wire M_is_store_B = M_ctrl_out_B[15];
   wire M_is_branch_B = M_ctrl_out_B[16];
   wire M_is_control_insn_B = M_ctrl_out_B[17];

   assign o_dmem_addr = (M_is_load_A | M_is_store_A) ? M_O_out_A : 
                        (M_is_load_B | M_is_store_B) ? M_O_out_B : 16'd0; 
   assign o_dmem_we = M_is_store_A | M_is_store_B;
   /*** Bypass ***/
   wire test1 = W_is_load_A && M_is_store_A && (W_wsel_A == M_r2sel_A) && (W_wsel_B != M_r2sel_A);
   assign o_dmem_towrite = (M_is_store_B && (M_wsel_A == M_r2sel_B) && M_regfile_we_A) ? M_O_out_A : // MM
                           (W_is_load_B && M_is_store_A && (W_wsel_B == M_r2sel_A)) ? W_rd_data_B : // WM_B2A
                           (W_is_load_B && M_is_store_B && (W_wsel_B == M_r2sel_B)) ? W_rd_data_B : // WM_B2B
                           (W_is_load_A && M_is_store_B && (W_wsel_A == M_r2sel_B)) ? W_rd_data_A : // WM_A2B
                           (W_is_load_A && M_is_store_A && (W_wsel_A == M_r2sel_A) && !(W_wsel_B == M_r2sel_A && W_regfile_we_B)) ? W_rd_data_A : // WM_A2A
                           (M_is_store_B || M_is_load_B) ? M_r2data_out_B :
                           (M_is_store_A || M_is_load_A) ? M_r2data_out_A : 16'd0;

   // ===================================== W =======================================// 
   //pipe A:
   wire [15:0] W_O_out_A;
   wire [15:0] W_D_out_A;
   wire [15:0] W_ir_out_A;
   wire [15:0] W_pc_out_A;
   wire [17:0] W_ctrl_out_A;

   //pipe B:
   wire [15:0] W_O_out_B;
   wire [15:0] W_D_out_B;
   wire [15:0] W_ir_out_B;
   wire [15:0] W_pc_out_B;
   wire [17:0] W_ctrl_out_B;

   wire W_we = 1'b1;

   //pipe A:
   Nbit_reg #(16, 0) W_ir_reg_A (.in(M_ir_out_A), .out(W_ir_out_A), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_O_reg_A (.in(M_O_out_A), .out(W_O_out_A), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_D_reg_A (.in(i_cur_dmem_data), .out(W_D_out_A), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_pc_reg_A (.in(M_pc_out_A), .out(W_pc_out_A), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(18, 0) W_ctrl_reg_A (.in(M_ctrl_out_A), .out(W_ctrl_out_A), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));
   
   //pipe B:
   Nbit_reg #(16, 0) W_ir_reg_B (.in(M_ir_out_B), .out(W_ir_out_B), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_O_reg_B (.in(M_O_out_B), .out(W_O_out_B), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_D_reg_B (.in(i_cur_dmem_data), .out(W_D_out_B), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 0) W_pc_reg_B (.in(M_pc_out_B), .out(W_pc_out_B), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(18, 0) W_ctrl_reg_B (.in(M_ctrl_out_B), .out(W_ctrl_out_B), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));

   //pipe A:
   wire [2:0] W_r1sel_A = W_ctrl_out_A[2:0];    // rs
   wire W_r1re_A = W_ctrl_out_A[3];
   wire [2:0] W_r2sel_A = W_ctrl_out_A[6:4];    // rt
   wire W_r2re_A = W_ctrl_out_A[7];
   wire [2:0] W_wsel_A = W_ctrl_out_A[10:8];    // rd
   wire W_regfile_we_A = W_ctrl_out_A[11];
   wire W_nzp_we_A = W_ctrl_out_A[12];
   wire W_select_pc_plus_one_A = W_ctrl_out_A[13];
   wire W_is_load_A = W_ctrl_out_A[14];
   wire W_is_store_A = W_ctrl_out_A[15];
   wire W_is_branch_A = W_ctrl_out_A[16];
   wire W_is_control_insn_A = W_ctrl_out_A[17];

   //pipe B:
   wire [2:0] W_r1sel_B = W_ctrl_out_B[2:0];    // rs
   wire W_r1re_B = W_ctrl_out_B[3];
   wire [2:0] W_r2sel_B = W_ctrl_out_B[6:4];    // rt
   wire W_r2re_B = W_ctrl_out_B[7];
   wire [2:0] W_wsel_B = W_ctrl_out_B[10:8];    // rd
   wire W_regfile_we_B = W_ctrl_out_B[11];
   wire W_nzp_we_B = W_ctrl_out_B[12];
   wire W_select_pc_plus_one_B = W_ctrl_out_B[13];
   wire W_is_load_B = W_ctrl_out_B[14];
   wire W_is_store_B = W_ctrl_out_B[15];
   wire W_is_branch_B = W_ctrl_out_B[16];
   wire W_is_control_insn_B = W_ctrl_out_B[17];

   // =============== RD data ==================//
   assign W_rd_data_A = W_select_pc_plus_one_A ? M_pc_out_A : W_is_load_A ? W_D_out_A : W_O_out_A;
   assign W_rd_data_B = W_select_pc_plus_one_B ? M_pc_out_A : W_is_load_B ? W_D_out_B : W_O_out_B;

   //============== WX & MX  Bypass ============// 

   // pipe A: ALU in
   assign X_r1_ALUin_A = (X_r1sel_A == M_wsel_B && M_regfile_we_B) ? M_O_out_B :
                       (X_r1sel_A == M_wsel_A && M_regfile_we_A) ? M_O_out_A :
                       (X_r1sel_A == W_wsel_B && W_regfile_we_B) ? W_rd_data_B :
                       (X_r1sel_A == W_wsel_A && W_regfile_we_A) ? W_rd_data_A : X_r1data_out_A;

   assign X_r2_ALUin_A = (X_r2sel_A == M_wsel_B && M_regfile_we_B) ? M_O_out_B :
                       (X_r2sel_A == M_wsel_A && M_regfile_we_A) ? M_O_out_A :
                       (X_r2sel_A == W_wsel_B && W_regfile_we_B) ? W_rd_data_B :
                       (X_r2sel_A == W_wsel_A && W_regfile_we_A) ? W_rd_data_A : X_r2data_out_A;

   // pipe B: ALU in
   assign X_r1_ALUin_B = (X_r1sel_B == M_wsel_B && M_regfile_we_B) ? M_O_out_B :
                       (X_r1sel_B == M_wsel_A && M_regfile_we_A) ? M_O_out_A :                          
                       (X_r1sel_B == W_wsel_B && W_regfile_we_B) ? W_rd_data_B :
                       (X_r1sel_B == W_wsel_A && W_regfile_we_A) ? W_rd_data_A : X_r1data_out_B;

   assign X_r2_ALUin_B = (X_r2sel_B == M_wsel_B && M_regfile_we_B) ? M_O_out_B :
                       (X_r2sel_B == M_wsel_A && M_regfile_we_A) ? M_O_out_A :     
                       (X_r2sel_B == W_wsel_B && W_regfile_we_B) ? W_rd_data_B :
                       (X_r2sel_B == W_wsel_A && W_regfile_we_A) ? W_rd_data_A : X_r2data_out_B;

   // =================================== BR =============================//
   wire [2:0] NZP_A = (X_alu_result_A[15] == 1'b1) ? 3'b100 :
                    (|X_alu_result_A) ? 3'b001 : 3'b10;
   wire [2:0] NZP_B = (X_alu_result_B[15] == 1'b1) ? 3'b100 :
                    (|X_alu_result_B) ? 3'b001 : 3'b10;           

   wire [2:0] last_NZP_A;
   wire [2:0] last_NZP_B;

   Nbit_reg #(3, 3'b000) nzp_reg_A (.in(NZP_A), .out(last_NZP_A), .clk(clk), .we(X_nzp_we_A), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'b000) nzp_reg_B (.in(NZP_B), .out(last_NZP_B), .clk(clk), .we(X_nzp_we_B), .gwe(gwe), .rst(rst));

   wire flush_A = X_is_branch_A && (|(X_ir_out_A[11:9] & last_NZP_B) && M_nzp_we_B || |(X_ir_out_A[11:9] & last_NZP_A) && !M_nzp_we_B) || X_is_control_insn_A;
   wire flush_B = X_is_branch_B && |(X_ir_out_B[11:9] & last_NZP_B) || X_is_control_insn_B; // NZP_A valid?

   wire D_flush_out_A, X_flush_out_A, M_flush_out_A, W_flush_out_A;
   wire D_flush_out_B, X_flush_out_B, M_flush_out_B, W_flush_out_B;

   Nbit_reg #(1, 1) D_flush_reg_A (.in(flush_A || flush_B), .out(D_flush_out_A), .clk(clk), .we(D_we_A), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1) X_flush_reg_A (.in(D_flush_out_A || flush_A || flush_B), .out(X_flush_out_A), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1) M_flush_reg_A (.in(X_flush_out_A), .out(M_flush_out_A), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1) W_flush_reg_A (.in(M_flush_out_A), .out(W_flush_out_A), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));

   Nbit_reg #(1, 1) D_flush_reg_B (.in(flush_B || flush_A), .out(D_flush_out_B), .clk(clk), .we(D_we_B), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1) X_flush_reg_B (.in(D_flush_out_B || flush_B || flush_A), .out(X_flush_out_B), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1) M_flush_reg_B (.in(X_flush_out_B || flush_A), .out(M_flush_out_B), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1) W_flush_reg_B (.in(M_flush_out_B), .out(W_flush_out_B), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));

   // =================================== LD & RD =======================//
   wire [15:0] W_dmem_data_out_A;
   wire [15:0] W_dmem_data_out_B;
   wire [15:0] W_dmem_data_in_A;
   wire [15:0] W_dmem_data_in_B;
   assign W_dmem_data_in_A = (M_is_store_A || M_is_load_A) ? o_dmem_towrite : 16'b0;
   assign W_dmem_data_in_B = (M_is_store_B || M_is_load_B) ? o_dmem_towrite : 16'b0;
   Nbit_reg #(16, 16'd0) dmem_data_reg_A (.in(W_dmem_data_in_A), .out(W_dmem_data_out_A), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'd0) dmem_data_reg_B (.in(W_dmem_data_in_B), .out(W_dmem_data_out_B), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   // ====================== Stall Passing ==========================//
   wire [3:0] X_stall_out;
   wire [3:0] M_stall_out;
   wire [3:0] W_stall_out;
   
   Nbit_reg #(4, 0) X_ss_reg (.in({stall_B, stall_A}), .out(X_stall_out), .clk(clk), .we(X_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(4, 0) M_ss_reg (.in(X_stall_out), .out(M_stall_out), .clk(clk), .we(M_we), .gwe(gwe), .rst(rst));
   Nbit_reg #(4, 0) W_ss_reg (.in(M_stall_out), .out(W_stall_out), .clk(clk), .we(W_we), .gwe(gwe), .rst(rst));

   // ====================== Testbench signals ==========================//
   assign test_stall_A = W_flush_out_A ? 2'd2 : W_stall_out[1:0];
   assign test_stall_B = W_flush_out_B ? 2'd2 : W_stall_out[3:2];

   assign test_cur_pc_A = W_pc_out_A;
   assign test_cur_pc_B = W_pc_out_B;

   assign test_cur_insn_A = W_ir_out_A;
   assign test_cur_insn_B = W_ir_out_B;

   assign test_regfile_we_A = W_regfile_we_A;
   assign test_regfile_we_B = W_regfile_we_B;

   assign test_regfile_wsel_A = W_wsel_A;
   assign test_regfile_wsel_B = W_wsel_B;

   assign test_regfile_data_A = W_rd_data_A;
   assign test_regfile_data_B = W_rd_data_B;

   assign test_nzp_we_A = W_nzp_we_A; //need nzp
   assign test_nzp_we_B = W_nzp_we_B; //need nzp

   assign test_nzp_new_bits_A = (W_rd_data_A[15] == 1'b1) ? 3'b100 :
                              (|W_rd_data_A) ? 3'b001 : 3'b10;
   assign test_nzp_new_bits_B = (W_rd_data_B[15] == 1'b1) ? 3'b100 :
                              (|W_rd_data_B) ? 3'b001 : 3'b10;

   assign test_dmem_we_A = W_is_store_A;
   assign test_dmem_we_B = W_is_store_B;  

   assign test_dmem_addr_A = (W_is_load_A | W_is_store_A) ? W_O_out_A : 16'd0;
   assign test_dmem_addr_B = (W_is_load_B | W_is_store_B) ? W_O_out_B : 16'd0;

   assign test_dmem_data_A = W_is_load_A ? W_D_out_A : W_dmem_data_out_A;
   assign test_dmem_data_B = W_is_load_B ? W_D_out_B : W_dmem_data_out_B;

   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    *
    * You may also use if statements inside the always block
    * to conditionally print out information.
    */
   always @(posedge gwe) begin
      $write("PC_A: %h;   ", D_pc_out_A);
      pinstr(D_ir_out_A);
      $display();
      $write("PC_B: %h;   ", D_pc_out_B);
      pinstr(D_ir_out_B);
      $display();
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nanoseconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display();
   end
endmodule
