// SPDX-License-Identifier: Apache-2.0
module observe_ifu_fetch_redirect (
    input logic clk,
    input logic rst_l,
    input logic redirect,
    input logic no_redirect,
    input logic [31:1] redirect_address,
    input logic [31:1] protection_address
);
    always @(posedge clk) begin
        if (rst_l && redirect && !no_redirect)
            $display("IFU_FETCH_REDIRECT expected=%08h actual=%08h",
                     {redirect_address, 1'b0}, {protection_address, 1'b0});
    end
endmodule

bind el2_ifu observe_ifu_fetch_redirect observe_ifu_fetch_redirect_i (
    .clk(clk),
    .rst_l(rst_l),
    .redirect(exu_flush_final),
    .no_redirect(dec_tlu_flush_noredir_wb),
    .redirect_address(exu_flush_path_final),
    .protection_address(ifu_pmp_addr)
);
