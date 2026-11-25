# Implement `hpdcache_victim_random`

Implement the complete `hpdcache_victim_random` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_victim_random` definition in a single SystemVerilog code
block, with no text outside the block.

## Module declaration

```systemverilog
module hpdcache_victim_random
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    localparam type set_t        = logic [$clog2(HPDcacheCfg.u.sets)-1:0],
    localparam type way_vector_t = logic [HPDcacheCfg.u.ways-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Update interface
    input  logic                  updt_i, /* unused */
    input  set_t                  updt_set_i, /* unused */
    input  way_vector_t           updt_way_i, /* unused */

    //      Victim selection interface
    input  logic                  sel_victim_i,
    input  way_vector_t           sel_dir_valid_i,
    input  way_vector_t           sel_dir_wback_i, /* unused */
    input  way_vector_t           sel_dir_dirty_i,
    input  way_vector_t           sel_dir_fetch_i,
    input  set_t                  sel_victim_set_i, /* unused */
    output way_vector_t           sel_victim_way_o
);

```

## Dependency declarations

### `rtl/src/common/hpdcache_decoder.sv`

```systemverilog
module hpdcache_decoder
    //  Parameters
    //  {{{
#(
    parameter  int unsigned N     = 0,
    localparam int unsigned Pow2N = 2**N,
    localparam type in_t  = logic unsigned [N-1:0],
    localparam type out_t = logic unsigned [Pow2N-1:0]
)
    //  }}}

    //  Ports
    //  {{{
(
    input  logic   en_i,
    input  in_t    val_i,
    output out_t   val_o
);

```

### `rtl/src/common/hpdcache_lfsr.sv`

```systemverilog
module hpdcache_lfsr
//  Parameters
//  {{{
#(
    parameter int WIDTH = 8,

    localparam type data_t = logic [WIDTH-1:0]
)
//  }}}

//  Ports
//  {{{
(
    input  logic        clk_i,
    input  logic        rst_ni,
    input  logic        shift_i,
    output data_t       val_o
);

```

### `rtl/src/common/hpdcache_prio_1hot_encoder.sv`

```systemverilog
module hpdcache_prio_1hot_encoder
    //  Parameters
#(
    parameter int unsigned N = 0
)
    //  Ports
(
    input  logic [N-1:0] val_i,
    output logic [N-1:0] val_o
);

```

## Documentation

### `docs/source/architecture.rst`

```text
Cache Directory and Data
------------------------

State Bits in the Cache Directory
'''''''''''''''''''''''''''''''''

Each cacheline in the HPDcache has the following state bits:

  - **valid**: when this bit is set, it means that the cacheline is valid.
    Otherwise, the slot is available.
  - **wback**: when this bit is set, it means that the cacheline is in
    write-back mode. It is only valid when the valid bit is set.
  - **dirty**: when this bit is set, it means that the cacheline is in
    write-back mode and it is dirty (it has locally modified data which has not
    been transmitted to the next memory level). It is only valid when the valid
    bit is set.
  - **fetch**: when this bit is set, it means that the cacheline has been
    pre-selected to be replaced by a new one. While this bit is set, the refill
    response for the miss has not yet arrived.

Replacement Policy
''''''''''''''''''

The HPDcache supports the following two replacement policies: Pseudo Random or
Pseudo Least Recently Used (PLRU) replacement policy. The user selects the
actual policy at synthesis-time through the
:math:`\scriptsize\mathsf{CONF\_HPDCACHE\_VICTIM\_SEL}`
configuration parameter (:numref:`Table %s <tab_synthesis_parameters>`).

The cache uses the selected policy to select the victim way where a new
cacheline is written. In case of a read miss, CMO prefetch miss or a write miss
with the write-back policy the cache controller applies the replacement policy
to select the way of the corresponding set where the miss handler will write
the new cacheline.

The cache selects the victim way at the moment of a cache miss. At that moment,
it also asks for the missing cacheline to the memory. While waiting for the
refill response, the victim cacheline is still accessible but in **fetch** mode
(fetch bit set). This means that it has been pre-selected for replacement, and
cannot be a candidate for victim selection for a future miss (until the refill
response does not arrive).

...

Pseudo Random
~~~~~~~~~~~~~

This replacement policy requires only one 8-bit Linear Feedback Shift Register
(LFSR).

Each time there is a miss (read, CMO prefetch, write in write-back mode), the
cache controller selects either a free way (valid bit is set to 0), or a way
designated by the value in the LFSR. If the random way is in **fetch** mode,
then the cache controller selects the first way which is not in **fetch** mode,
giving the highest priority to clean ways. If all ways are in **fetch** mode,
then the request is put on-hold in the replay table. Each time the cache
controller uses the pseudo random value, it performs a shift of the LFSR.

```
