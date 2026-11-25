#include "Vibex_fetch_fifo.h"
#include "verilated.h"
#include <iostream>
#include <stdexcept>

static Vibex_fetch_fifo d;
struct ObservationUnavailable : std::runtime_error {
  using std::runtime_error::runtime_error;
};
static unsigned observation=0;
static void eval() {
  d.eval();
  std::cout << "INPUT " << observation++ << " clk=" << unsigned(d.clk_i)
            << " reset_n=" << unsigned(d.rst_ni) << " clear=" << unsigned(d.clear_i)
            << " in_valid=" << unsigned(d.in_valid_i) << " in_addr=" << std::hex
            << d.in_addr_i << " in_data=" << d.in_rdata_i << std::dec
            << " in_err=" << unsigned(d.in_err_i) << " force_uc="
            << unsigned(d.cheriot_force_uc_i) << " out_ready=" << unsigned(d.out_ready_i)
            << " out_valid=" << unsigned(d.out_valid_o) << " out_err="
            << unsigned(d.out_err_o) << " plus2=" << unsigned(d.out_err_plus2_o)
            << " out_pc=" << std::hex << d.out_addr_o << " out_data=" << d.out_rdata_o
            << std::dec << '\n';
}
static void tick() { d.clk_i=0;eval();d.clk_i=1;eval();d.clk_i=0;eval(); }
static void require(bool ok,const char* label) {
  std::cout << label << " observed valid=" << unsigned(d.out_valid_o)
            << " err=" << unsigned(d.out_err_o) << " plus2="
            << unsigned(d.out_err_plus2_o) << " pc=" << std::hex
            << d.out_addr_o << " data=" << d.out_rdata_o << std::dec
            << " result=" << (ok?"PASS":"FAIL") << '\n';
  if (!ok) throw std::runtime_error(label);
}
static void start(unsigned pc) {
  d.clk_i=0;d.rst_ni=0;d.clear_i=0;d.in_valid_i=0;d.in_addr_i=0;
  d.in_rdata_i=0;d.in_err_i=0;d.cheriot_force_uc_i=0;d.out_ready_i=0;
  eval();tick();d.rst_ni=1;d.clear_i=1;d.in_addr_i=pc;tick();d.clear_i=0;eval();
  require(d.out_addr_o==pc,"clear initializes instruction PC");
}
static void first_word(bool error) {
  d.in_valid_i=1;d.in_rdata_i=0x00130001;d.in_err_i=error;tick();
  d.in_valid_i=0;d.in_err_i=0;eval();
}
static void second_word(unsigned data,bool error) {
  d.in_valid_i=1;d.in_rdata_i=data;d.in_err_i=error;eval();
  if (!d.out_valid_o) {
    tick();
    d.in_valid_i=0;d.in_err_i=0;eval();
  }
  if (!d.out_valid_o) throw ObservationUnavailable("second word observation budget exhausted");
}
static void await_valid() {
  for (unsigned edge=0; !d.out_valid_o && edge<8; ++edge) {
    tick();
    if (d.in_valid_i) { d.in_valid_i=0;eval(); }
  }
  if (!d.out_valid_o) throw ObservationUnavailable("transfer observation budget exhausted");
}
static void expect_instruction(unsigned pc,unsigned data,unsigned mask,const char* label) {
  await_valid();
  std::cout << "EXPECT pc=" << std::hex << pc << " data=" << data << " mask=" << mask
            << std::dec << " label=" << label << '\n';
  require(!d.out_err_o && d.out_addr_o==pc && (d.out_rdata_o & mask)==data,label);
}
static void store_word(unsigned data) {
  d.out_ready_i=0;d.in_valid_i=1;d.in_rdata_i=data;d.in_err_i=0;tick();
  d.in_valid_i=0;eval();
}
static void exchange_case(bool two_buffered_words) {
  start(0x100);store_word(0x00100093);
  if (two_buffered_words) store_word(0x00200113);
  expect_instruction(0x100,0x00100093,0xffffffff,"oldest word before simultaneous transfer");
  d.in_valid_i=1;d.in_rdata_i=0x00300193;d.out_ready_i=1;eval();
  expect_instruction(0x100,0x00100093,0xffffffff,"incoming word does not replace accepted oldest word");
  tick();d.in_valid_i=0;d.out_ready_i=0;eval();
  if (two_buffered_words) {
    expect_instruction(0x104,0x00200113,0xffffffff,"second buffered word survives simultaneous transfer");
    d.out_ready_i=1;tick();d.out_ready_i=0;eval();
  }
  expect_instruction(two_buffered_words ? 0x108 : 0x104,0x00300193,0xffffffff,
                     "incoming word remains after simultaneous transfer");
}
static void compressed_transfer_case() {
  start(0x100);store_word(0x00850001);
  expect_instruction(0x100,0x0001,0xffff,"lower compressed instruction before transfer");
  d.in_valid_i=1;d.in_rdata_i=0x00100093;d.out_ready_i=1;eval();tick();
  d.in_valid_i=0;d.out_ready_i=0;eval();
  expect_instruction(0x102,0x0085,0xffff,"upper compressed instruction retained after lower half consumption");
  d.out_ready_i=1;tick();d.out_ready_i=0;eval();
  expect_instruction(0x104,0x00100093,0xffffffff,"next word follows retained upper half");
}
static void nonempty_clear_case(bool incoming,bool consume) {
  start(0x100);store_word(0x00100093);store_word(0x00200113);
  expect_instruction(0x100,0x00100093,0xffffffff,"nonempty FIFO before clear");
  d.clear_i=1;d.in_addr_i=0x200;d.in_valid_i=incoming;
  d.in_rdata_i=0x00300193;d.out_ready_i=consume;eval();tick();
  d.clear_i=0;d.in_valid_i=0;d.out_ready_i=0;eval();
  require(!d.out_valid_o && d.out_addr_o==0x200,"clear discards queued and same-edge incoming words");
  d.in_valid_i=1;d.in_rdata_i=0x00400213;eval();
  expect_instruction(0x200,0x00400213,0xffffffff,"new word uses clear-selected PC");
  tick();d.in_valid_i=0;eval();
  expect_instruction(0x200,0x00400213,0xffffffff,"new word remains available after clear");
}
int main(int argc,char** argv) {
  Verilated::commandArgs(argc,argv);
  try {
    start(0x100);d.in_valid_i=1;d.in_err_i=1;eval();
    require(d.out_valid_o && d.out_err_o,"aligned incoming fetch error");
    start(0x102);first_word(false);
    require(!d.out_valid_o,"normal halfword instruction waits for second word");
    second_word(0x0000dead,false);
    require(d.out_valid_o && !d.out_err_o && d.out_rdata_o==0xdead0013,
            "normal halfword instruction reassembles both words");
    start(0x102);first_word(false);
    second_word(0,true);
    require(d.out_valid_o && d.out_err_o && d.out_err_plus2_o,
            "second-half-only fetch error");
    start(0x102);first_word(true);
    second_word(0,false);
    require(d.out_valid_o && d.out_err_o && !d.out_err_plus2_o,
            "first-half fetch error is not second-half-only");
    start(0x102);first_word(true);
    second_word(0,true);
    require(d.out_valid_o && d.out_err_o && !d.out_err_plus2_o,
            "errors on both fetch words identify the first half");
    start(0x350);
    d.in_valid_i=1;d.out_ready_i=1;d.in_rdata_i=0x00000093;eval();
    bool transferred=d.out_valid_o;
    tick();d.in_valid_i=0;eval();
    if (!transferred) {
      expect_instruction(0x350,0x00000093,0xffffffff,"first word transferred from storage");
      tick();
    }
    d.in_valid_i=1;d.in_rdata_i=0x00008106;d.out_ready_i=0;eval();
    expect_instruction(0x354,0x8106,0xffff,"second word follows accepted first word");
    exchange_case(false);
    exchange_case(true);
    compressed_transfer_case();
    nonempty_clear_case(false,false);
    nonempty_clear_case(true,false);
    nonempty_clear_case(false,true);
    nonempty_clear_case(true,true);
    std::cout << "PASS all selected fetch error cases\n";return 0;
  } catch (const ObservationUnavailable& e) {
    std::cerr << "INVALID " << e.what() << '\n';return 2;
  } catch (const std::exception& e) {
    std::cerr << "FETCH_FIFO_PORT_MISMATCH " << e.what() << '\n';return 1;
  }
}
