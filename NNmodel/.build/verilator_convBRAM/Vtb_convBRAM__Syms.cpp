// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vtb_convBRAM__pch.h"
#include "Vtb_convBRAM.h"
#include "Vtb_convBRAM___024root.h"

// FUNCTIONS
Vtb_convBRAM__Syms::~Vtb_convBRAM__Syms()
{
}

Vtb_convBRAM__Syms::Vtb_convBRAM__Syms(VerilatedContext* contextp, const char* namep, Vtb_convBRAM* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    , __Vm_threadPoolp{static_cast<VlThreadPool*>(contextp->threadPoolp())}
    // Setup module instances
    , TOP{this, namep}
{
    // Configure time unit / time precision
    _vm_contextp__->timeunit(-9);
    _vm_contextp__->timeprecision(-12);
    // Setup each module's pointers to their submodules
    // Setup each module's pointer back to symbol table (for public functions)
    TOP.__Vconfigure(true);
    // Setup scopes
    __Vscope_tb_convBRAM.configure(this, name(), "tb_convBRAM", "tb_convBRAM", -9, VerilatedScope::SCOPE_OTHER);
}
