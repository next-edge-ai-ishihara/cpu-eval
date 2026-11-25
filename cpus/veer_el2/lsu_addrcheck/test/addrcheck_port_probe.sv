// SPDX-License-Identifier: Apache-2.0
module addrcheck_port_probe
    import el2_pkg::*;
#(
    `include "el2_param.vh"
);
    logic lsu_c2_m_clk = 1'b0;
    logic rst_l = 1'b0;
    logic [31:0] rs1_d = pt.PIC_BASE_ADDR;
    logic [3:0] rs1_region_d = pt.PIC_REGION;
    logic [31:0] start_addr_d = pt.PIC_BASE_ADDR;
    logic [31:0] end_addr_d;
    logic [31:0] dec_tlu_mrac_ff = '0;
    logic lsu_pmp_error_start = 1'b0;
    logic lsu_pmp_error_end = 1'b0;
    logic scan_mode = 1'b0;
    el2_lsu_pkt_t lsu_pkt_d = '0;
    logic is_sideeffects_m, addr_in_dccm_d, addr_in_pic_d, addr_external_d;
    logic access_fault_d, misaligned_fault_d;
    logic [3:0] exc_mscause_d;
    logic fir_dccm_access_error_d, fir_nondccm_access_error_d;

    el2_lsu_addrcheck #(.pt(pt)) dut (.*);

    task automatic report(input string scenario);
        $display("ADDRCHECK_PORT_OBSERVED: %s addr=%08h pic=%0b access=%0b misaligned=%0b cause=%0h",
                 scenario, start_addr_d, addr_in_pic_d, access_fault_d, misaligned_fault_d, exc_mscause_d);
    endtask

    initial begin
        #1;
        rst_l = 1'b1;
        lsu_pkt_d.valid = 1'b1;
        lsu_pkt_d.load = 1'b1;
        lsu_pkt_d.word = 1'b1;
        end_addr_d = start_addr_d + 32'd3;
        #1;
        report("aligned PIC word");
        if (!addr_in_pic_d || access_fault_d || misaligned_fault_d) begin
            $display("ADDRCHECK_PORT_MISMATCH: aligned PIC word must complete without a fault");
        end else begin
            lsu_pkt_d.word = 1'b0;
            lsu_pkt_d.by = 1'b1;
            end_addr_d = start_addr_d;
            #1;
            report("aligned PIC byte");
            if (!addr_in_pic_d || !access_fault_d || misaligned_fault_d || exc_mscause_d != 4'h6)
                $display("ADDRCHECK_PORT_MISMATCH: aligned PIC byte must report access fault with secondary cause 6");
            else
                $display("ADDRCHECK_PORT_PASS");
        end
        $finish;
    end
endmodule
