// SPDX-License-Identifier: Apache-2.0
module cpu_eval_div_cancel_observer (
    input logic clk,
    input logic rst_l,
    input logic valid,
    input logic cancel,
    input logic finish
);
    bit canceled;
    always @(posedge clk) begin
        if (!rst_l) begin
            canceled <= 0;
        end else begin
            if (valid) canceled <= 0;
            if (cancel) begin
                canceled <= 1;
                $display("CPU_EVAL_DIV_CANCEL_OBSERVED");
            end
            if (finish && (cancel || (canceled && !valid)))
                $display("CPU_EVAL_DIV_CANCEL_MISMATCH");
        end
    end
endmodule

bind el2_exu_div_ctl cpu_eval_div_cancel_observer cpu_eval_div_cancel (
    .clk(clk), .rst_l(rst_l), .valid(dp.valid), .cancel(cancel), .finish(finish_dly)
);
