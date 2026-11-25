# Implement `el2_cmp_and_mux`

Implement the complete `el2_cmp_and_mux` module. Preserve the module name, parameters, and ports shown below.

Return only the complete `module el2_cmp_and_mux` definition in a single SystemVerilog code block, with no text outside the block.

## Module declaration

```verilog
module el2_cmp_and_mux #(parameter ID_BITS=8,
                               INTPRIORITY_BITS = 4)
                    (
                        input  logic [ID_BITS-1:0]       a_id,
                        input  logic [INTPRIORITY_BITS-1:0] a_priority,

                        input  logic [ID_BITS-1:0]       b_id,
                        input  logic [INTPRIORITY_BITS-1:0] b_priority,

                        output logic [ID_BITS-1:0]       out_id,
                        output logic [INTPRIORITY_BITS-1:0] out_priority

                    );
```

## Parent instantiation

```verilog
       el2_cmp_and_mux  #(.ID_BITS(ID_BITS),
                      .INTPRIORITY_BITS(INTPRIORITY_BITS)) cmp_l1 (
                      .a_id(level_intpend_id[l][2*m]),
                      .a_priority(level_intpend_w_prior_en[l][2*m]),
                      .b_id(level_intpend_id[l][2*m+1]),
                      .b_priority(level_intpend_w_prior_en[l][2*m+1]),
                      .out_id(level_intpend_id[l+1][m]),
                      .out_priority(level_intpend_w_prior_en[l+1][m])) ;
```

## Documentation

```text
8. The priorities of a pair of interrupt sources are compared:
    1. If the two priorities are different, the higher priority and its associated hardwired interrupt source ID are forwarded to the second-level comparator.
    1. If the two priorities are the same, the priority and the lower hardwired interrupt source ID are forwarded to the second-level comparator.
9. Each subsequent level of comparators compares the priorities from two comparator outputs of the previous level:
    1. If the two priorities are different, the higher priority and its associated interrupt source ID are forwarded to the next-level comparator.
    1. If the two priorities are the same, the priority and the lower interrupt source ID are forwarded to the next-level comparator.
10. The output of the last-level comparator indicates the highest priority (maximum priority) and lowest interrupt source ID (interrupt ID) of all currently pending and enabled interrupts.
```
