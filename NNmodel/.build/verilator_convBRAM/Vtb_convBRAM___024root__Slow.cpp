// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_convBRAM.h for the primary calling header

#include "Vtb_convBRAM__pch.h"
#include "Vtb_convBRAM__Syms.h"
#include "Vtb_convBRAM___024root.h"

void Vtb_convBRAM___024root___ctor_var_reset(Vtb_convBRAM___024root* vlSelf);

Vtb_convBRAM___024root::Vtb_convBRAM___024root(Vtb_convBRAM__Syms* symsp, const char* v__name)
    : VerilatedModule{v__name}
    , __VdlySched{*symsp->_vm_contextp__}
    , __Vm_mtaskstate_43(1U)
    , __Vm_mtaskstate_41(1U)
    , __Vm_mtaskstate_32(1U)
    , __Vm_mtaskstate_35(1U)
    , __Vm_mtaskstate_29(0x11U)
    , __Vm_mtaskstate_47(4U)
    , __Vm_mtaskstate_42(1U)
    , __Vm_mtaskstate_33(1U)
    , __Vm_mtaskstate_39(1U)
    , __Vm_mtaskstate_48(1U)
    , __Vm_mtaskstate_53(1U)
    , __Vm_mtaskstate_49(1U)
    , __Vm_mtaskstate_40(1U)
    , __Vm_mtaskstate_30(1U)
    , __Vm_mtaskstate_34(1U)
    , __Vm_mtaskstate_final__nba(8U)
    , vlSymsp{symsp}
 {
    // Reset structure values
    Vtb_convBRAM___024root___ctor_var_reset(this);
}

void Vtb_convBRAM___024root::__Vconfigure(bool first) {
    if (false && first) {}  // Prevent unused
}

Vtb_convBRAM___024root::~Vtb_convBRAM___024root() {
}
