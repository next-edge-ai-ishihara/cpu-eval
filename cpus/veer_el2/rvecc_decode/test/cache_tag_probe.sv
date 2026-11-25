module cache_tag_probe;
    logic en = 1;
    logic sed_ded = 1;
    logic [31:0] din;
    logic [6:0] ecc_in;
    wire [31:0] dout;
    wire [6:0] ecc_out;
    wire single_ecc_error, double_ecc_error;

    rvecc_decode decoder(.*);

    task automatic check(input logic [31:0] data_in, input logic [6:0] check_bits,
                         input logic expected_error);
        din = data_in;
        ecc_in = check_bits;
        #1;
        $display("CACHE_TAG_PORT_OBSERVATION en=%b din=%h ecc_in=%h flags=%b%b dout=%h ecc_out=%h expected_error=%b",
                 en, din, ecc_in, single_ecc_error, double_ecc_error, dout, ecc_out, expected_error);
        if ((single_ecc_error | double_ecc_error) !== expected_error ||
            {dout, ecc_out} !== {din, ecc_in})
            $display("CACHE_TAG_PORT_MISMATCH en=%b din=%h ecc_in=%h", en, din, ecc_in);
    endtask

    initial begin
        // The tag format omits overall parity. Only the data bit 0 and check bits 0 and 1 are set.
        check(32'h00000001, 7'b0000011, 0);
        check(32'h00000001, 7'b1000011, 0);
        check(32'h00000000, 7'b0000011, 1);
        check(32'h00000001, 7'b0000001, 1);
        en = 0;
        check(32'h00000000, 7'b0000011, 0);
        $display("CACHE_TAG_PORT_COMPLETE");
        $finish;
    end
endmodule
