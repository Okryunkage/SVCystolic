// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VTB_CONVBRAM__SYMS_H_
#define VERILATED_VTB_CONVBRAM__SYMS_H_  // guard

#include "verilated.h"

// INCLUDE MODEL CLASS

#include "Vtb_convBRAM.h"

// INCLUDE MODULE CLASSES
#include "Vtb_convBRAM___024root.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vtb_convBRAM__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtb_convBRAM* const __Vm_modelp;
    bool __Vm_activity = false;  ///< Used by trace routines to determine change occurred
    uint32_t __Vm_baseCode = 0;  ///< Used by trace routines when tracing multiple models
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MULTI-THREADING
    VlThreadPool* __Vm_threadPoolp;
    bool __Vm_even_cycle__ico = false;
    bool __Vm_even_cycle__act = false;
    bool __Vm_even_cycle__nba = false;

    // MODULE INSTANCE STATE
    Vtb_convBRAM___024root         TOP;

    // SCOPE NAMES
    VerilatedScope __Vscope_tb_convBRAM;

    // CONSTRUCTORS
    Vtb_convBRAM__Syms(VerilatedContext* contextp, const char* namep, Vtb_convBRAM* modelp);
    ~Vtb_convBRAM__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
};

#endif  // guard
