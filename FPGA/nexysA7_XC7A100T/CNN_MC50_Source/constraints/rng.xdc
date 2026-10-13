# Only intentionally preserved RO loops are allowed. No CNN loop is waived.
set roNets [get_nets -hier -filter {NAME =~ *rngSource/GEN_RO*}]
set_property ALLOW_COMBINATORIAL_LOOPS TRUE $roNets
# Asynchronous oscillator outputs terminate at the first sampling stage.
set_false_path -to [get_pins -hier -filter {NAME =~ *rngSource/sampleMeta_reg*/D}]
