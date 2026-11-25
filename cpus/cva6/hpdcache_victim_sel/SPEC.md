# Implement `hpdcache_victim_sel`

Implement the complete `hpdcache_victim_sel` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module hpdcache_victim_sel` definition in a single SystemVerilog code
block, with no text outside the block.

## Package and imports

### `rtl/src/hpdcache_pkg.sv`

```systemverilog
    //  Definition of constants and types for HPDcache directory memory
    //  {{{
    //      Victim selection policy
    typedef enum logic {
        HPDCACHE_VICTIM_RANDOM = 1'b0,
        HPDCACHE_VICTIM_PLRU   = 1'b1
    } hpdcache_victim_sel_policy_t;
    //  }}}
// ...
    typedef struct packed {
        //  Number of requesters
        int unsigned nRequesters;
        //  Physical Address Width
        int unsigned paWidth;
        //  Word width (bits)
        int unsigned wordWidth;
        //  Number of sets
        int unsigned sets;
        //  Number of ways
        int unsigned ways;
        //  Cache-Line width (words)
        int unsigned clWords;
        //  Number of words in the request data channels (request and response)
        int unsigned reqWords;
        //  Request transaction ID width (bits)
        int unsigned reqTransIdWidth;
        //  Request source ID width (bits)
        int unsigned reqSrcIdWidth;
        //  Victim select
        hpdcache_victim_sel_policy_t victimSel;
// ...
    } hpdcache_user_cfg_t;

    typedef struct packed {
        //  User configuration parameters
        hpdcache_user_cfg_t u;
// ...
    } hpdcache_cfg_t;

```

## Module declaration

```systemverilog
module hpdcache_victim_sel
import hpdcache_pkg::*;
//  Parameters
//  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_way_vector_t = logic
)
//  }}}

//  Ports
//  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //      Victim policy update interface
    input  logic                  updt_i,
    input  hpdcache_set_t         updt_set_i,
    input  hpdcache_way_vector_t  updt_way_i,

    //      Victim selection interface
    input  logic                  sel_victim_i,
    input  hpdcache_way_vector_t  sel_dir_valid_i,
    input  hpdcache_way_vector_t  sel_dir_wback_i,
    input  hpdcache_way_vector_t  sel_dir_dirty_i,
    input  hpdcache_way_vector_t  sel_dir_fetch_i,
    input  hpdcache_set_t         sel_victim_set_i,
    output hpdcache_way_vector_t  sel_victim_way_o
);

```

## Dependency declarations

### `rtl/src/hpdcache_victim_plru.sv`

```systemverilog
module hpdcache_victim_plru
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

    //      PLRU update interface
    input  logic                  updt_i,
    input  set_t                  updt_set_i,
    input  way_vector_t           updt_way_i,

    //      Victim selection interface
    input  logic                  sel_victim_i, /* unused */
    input  way_vector_t           sel_dir_valid_i,
    input  way_vector_t           sel_dir_wback_i,
    input  way_vector_t           sel_dir_dirty_i,
    input  way_vector_t           sel_dir_fetch_i,
    input  set_t                  sel_victim_set_i,
    output way_vector_t           sel_victim_way_o
);

```

### `rtl/src/hpdcache_victim_random.sv`

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

```
