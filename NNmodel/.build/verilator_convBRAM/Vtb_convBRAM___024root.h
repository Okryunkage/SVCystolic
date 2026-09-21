// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb_convBRAM.h for the primary calling header

#ifndef VERILATED_VTB_CONVBRAM___024ROOT_H_
#define VERILATED_VTB_CONVBRAM___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_threads.h"
#include "verilated_timing.h"


class Vtb_convBRAM__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_convBRAM___024root final : public VerilatedModule {
  public:

    // DESIGN SPECIFIC STATE
    // Anonymous structures to workaround compiler member-count bugs
    struct {
        VlUnpacked<SData/*15:0*/, 1> tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe;
        SData/*15:0*/ __Vdlyvval__tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe__v0;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe__v0;
        SData/*15:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__old_word;
        SData/*15:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__new_word;
        SData/*15:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__read_word;
        VlUnpacked<SData/*15:0*/, 2> tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__mem;
        CData/*0:0*/ tb_convBRAM__DOT__dut__DOT__baddr;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__p;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__lane;
        CData/*1:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid;
        CData/*1:0*/ __Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid;
        CData/*1:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn;
        CData/*1:0*/ __Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn;
        CData/*1:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow;
        CData/*1:0*/ __Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow;
        CData/*3:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm;
        CData/*3:0*/ __Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm;
        CData/*0:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex;
        CData/*0:0*/ __Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex;
        CData/*3:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__state;
        CData/*3:0*/ __Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state;
        CData/*3:0*/ __Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress;
        CData/*3:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress;
        CData/*3:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm;
        CData/*3:0*/ __Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm;
        SData/*15:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__biasWord;
        SData/*15:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__weightWord;
        CData/*0:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone;
        CData/*0:0*/ __Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone;
        CData/*0:0*/ tb_convBRAM__DOT__rst;
        CData/*0:0*/ tb_convBRAM__DOT__start;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__lane;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__channel;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__row;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__column;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__inputChannel;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__kernelRow;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__kernelColumn;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__inputRow;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__inputColumn;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__inputValue;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__weightValue;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT____Vlvbound_hc16deefc__0;
        QData/*63:0*/ tb_convBRAM__DOT__dut__DOT__core__DOT__product;
        VlUnpacked<VlUnpacked<VlUnpacked<CData/*7:0*/, 3>, 3>, 1> tb_convBRAM__DOT__inData;
        IData/*31:0*/ __Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v2;
        IData/*31:0*/ __Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v3;
        VlUnpacked<IData/*31:0*/, 2> tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v2;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v3;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v0;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v5;
        IData/*31:0*/ __Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v2;
        IData/*31:0*/ __Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v3;
        IData/*31:0*/ __Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v4;
        IData/*31:0*/ __Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v5;
        VlUnpacked<IData/*31:0*/, 2> tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v3;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v4;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v2;
        CData/*0:0*/ __Vdlyvdim0__tb_convBRAM__DOT__outData__v18;
        CData/*1:0*/ __Vdlyvdim1__tb_convBRAM__DOT__outData__v18;
        CData/*1:0*/ __Vdlyvdim2__tb_convBRAM__DOT__outData__v18;
    };
    struct {
        CData/*0:0*/ __Vdlyvdim0__tb_convBRAM__DOT__outData__v19;
        CData/*1:0*/ __Vdlyvdim1__tb_convBRAM__DOT__outData__v19;
        CData/*1:0*/ __Vdlyvdim2__tb_convBRAM__DOT__outData__v19;
        IData/*31:0*/ __Vdlyvval__tb_convBRAM__DOT__outData__v18;
        IData/*31:0*/ __Vdlyvval__tb_convBRAM__DOT__outData__v19;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__outData__v18;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__outData__v19;
        VlUnpacked<VlUnpacked<VlUnpacked<IData/*31:0*/, 3>, 3>, 2> tb_convBRAM__DOT__outData;
        CData/*0:0*/ tb_convBRAM__DOT__done;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__p;
        SData/*15:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__old_word;
        SData/*15:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__new_word;
        SData/*15:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__read_word;
        VlUnpacked<SData/*15:0*/, 9> tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem;
        CData/*0:0*/ __Vdlyvset__tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe__v0;
        SData/*15:0*/ __Vdlyvval__tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe__v0;
        VlUnpacked<SData/*15:0*/, 1> tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe;
        CData/*0:0*/ tb_convBRAM__DOT__busy;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__lane;
        CData/*3:0*/ tb_convBRAM__DOT__dut__DOT__waddr;
        CData/*0:0*/ tb_convBRAM__DOT__clk;
        CData/*0:0*/ __VstlFirstIteration;
        CData/*0:0*/ __Vtrigprevexpr___TOP__tb_convBRAM__DOT__clk__0;
        CData/*0:0*/ __Vtrigprevexpr___TOP__tb_convBRAM__DOT__rst__0;
        CData/*0:0*/ __Vtrigprevexpr___TOP__tb_convBRAM__DOT__done__0;
        CData/*0:0*/ __VactDidInit;
        CData/*0:0*/ __VactContinue;
        IData/*31:0*/ tb_convBRAM__DOT__index;
        IData/*31:0*/ tb_convBRAM__DOT__row;
        IData/*31:0*/ tb_convBRAM__DOT__column;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__i;
        IData/*31:0*/ tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__i;
        IData/*31:0*/ __VactIterCount;
        VlUnpacked<IData/*31:0*/, 9> tb_convBRAM__DOT__expected0;
        VlUnpacked<CData/*0:0*/, 7> __Vm_traceActivity;
    };
    VlDelayScheduler __VdlySched;
    VlTriggerScheduler __VtrigSched_h52bcd072__0;
    VlTriggerScheduler __VtrigSched_hba22dc0b__0;
    VlTriggerVec<1> __VstlTriggered;
    VlTriggerVec<4> __VactTriggered;
    VlTriggerVec<4> __VnbaTriggered;
    VlMTaskVertex __Vm_mtaskstate_43;
    VlMTaskVertex __Vm_mtaskstate_41;
    VlMTaskVertex __Vm_mtaskstate_32;
    VlMTaskVertex __Vm_mtaskstate_35;
    VlMTaskVertex __Vm_mtaskstate_29;
    VlMTaskVertex __Vm_mtaskstate_47;
    VlMTaskVertex __Vm_mtaskstate_42;
    VlMTaskVertex __Vm_mtaskstate_33;
    VlMTaskVertex __Vm_mtaskstate_39;
    VlMTaskVertex __Vm_mtaskstate_48;
    VlMTaskVertex __Vm_mtaskstate_53;
    VlMTaskVertex __Vm_mtaskstate_49;
    VlMTaskVertex __Vm_mtaskstate_40;
    VlMTaskVertex __Vm_mtaskstate_30;
    VlMTaskVertex __Vm_mtaskstate_34;
    VlMTaskVertex __Vm_mtaskstate_final__nba;

    // INTERNAL VARIABLES
    Vtb_convBRAM__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vtb_convBRAM___024root(Vtb_convBRAM__Syms* symsp, const char* v__name);
    ~Vtb_convBRAM___024root();
    VL_UNCOPYABLE(Vtb_convBRAM___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
