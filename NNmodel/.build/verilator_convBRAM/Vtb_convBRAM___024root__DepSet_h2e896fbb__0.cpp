// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_convBRAM.h for the primary calling header

#include "Vtb_convBRAM__pch.h"
#include "Vtb_convBRAM___024root.h"

VL_ATTR_COLD void Vtb_convBRAM___024root___eval_initial__TOP(Vtb_convBRAM___024root* vlSelf);
VlCoroutine Vtb_convBRAM___024root___eval_initial__TOP__Vtiming__0(Vtb_convBRAM___024root* vlSelf);
VlCoroutine Vtb_convBRAM___024root___eval_initial__TOP__Vtiming__1(Vtb_convBRAM___024root* vlSelf);

void Vtb_convBRAM___024root___eval_initial(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_initial\n"); );
    // Body
    Vtb_convBRAM___024root___eval_initial__TOP(vlSelf);
    vlSelf->__Vm_traceActivity[1U] = 1U;
    Vtb_convBRAM___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    Vtb_convBRAM___024root___eval_initial__TOP__Vtiming__1(vlSelf);
    vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__clk__0 
        = vlSelf->tb_convBRAM__DOT__clk;
    vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__rst__0 
        = vlSelf->tb_convBRAM__DOT__rst;
    vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__done__0 
        = vlSelf->tb_convBRAM__DOT__done;
}

VL_INLINE_OPT VlCoroutine Vtb_convBRAM___024root___eval_initial__TOP__Vtiming__1(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_initial__TOP__Vtiming__1\n"); );
    // Body
    while (1U) {
        co_await vlSelf->__VdlySched.delay(0x1388ULL, 
                                           nullptr, 
                                           "/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 
                                           17);
        vlSelf->tb_convBRAM__DOT__clk = (1U & (~ (IData)(vlSelf->tb_convBRAM__DOT__clk)));
    }
}

void Vtb_convBRAM___024root___eval_act(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_act\n"); );
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__0(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__0\n"); );
    // Body
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__1(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__1\n"); );
    // Body
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__2(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__2\n"); );
    // Body
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__3(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__3\n"); );
    // Body
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__4(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__4\n"); );
    // Body
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__5(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__5\n"); );
    // Body
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__6(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__6\n"); );
    // Body
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__7(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__7\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v2 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__8(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__8\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v3 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__9(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__9\n"); );
    // Body
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__10(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__10\n"); );
    // Body
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__11(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__11\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v2 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__12(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__12\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v3 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__13(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__13\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v4 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__14(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__14\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v5 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__15(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__15\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__outData__v18 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__16(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__16\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__outData__v19 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__17(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__17\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v0 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__18(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__18\n"); );
    // Body
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe__v0 = 0U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__19(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__19\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__p = 1U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__20(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__20\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__p = 1U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__lane = 1U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__21(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__21\n"); );
    // Body
    if ((9U > (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__waddr))) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__lane = 1U;
    }
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__24(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__24\n"); );
    // Body
    if ((9U > (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__waddr))) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__old_word 
            = ((8U >= (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__waddr))
                ? vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem
               [vlSelf->tb_convBRAM__DOT__dut__DOT__waddr]
                : 0U);
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__new_word 
            = vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__old_word;
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__read_word 
            = vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__old_word;
    } else {
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__read_word = 0U;
    }
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe__v0 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__read_word;
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe__v0 = 1U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__25(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__25\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__old_word 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__mem
        [vlSelf->tb_convBRAM__DOT__dut__DOT__baddr];
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__new_word 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__old_word;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__read_word 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__old_word;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe__v0 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__read_word;
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe__v0 = 1U;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__27(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__27\n"); );
    // Init
    IData/*31:0*/ __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendInput__0__Vfuncout;
    __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendInput__0__Vfuncout = 0;
    CData/*7:0*/ __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendInput__0__value;
    __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendInput__0__value = 0;
    IData/*31:0*/ __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__Vfuncout;
    __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__Vfuncout = 0;
    CData/*7:0*/ __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__value;
    __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__value = 0;
    IData/*31:0*/ __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__Vfuncout;
    __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__Vfuncout = 0;
    CData/*7:0*/ __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__value;
    __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__value = 0;
    // Body
    if (vlSelf->tb_convBRAM__DOT__rst) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__lane = 2U;
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__column = 3U;
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__row = 3U;
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__channel = 2U;
        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 0U;
        vlSelf->tb_convBRAM__DOT__busy = 0U;
        vlSelf->tb_convBRAM__DOT__done = 0U;
        vlSelf->tb_convBRAM__DOT__dut__DOT__baddr = 0U;
        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex = 0U;
        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm = 0U;
        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm = 0U;
        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow = 0U;
        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn = 0U;
        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress = 0U;
        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid = 0U;
        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone = 0U;
        vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v0 = 1U;
    } else {
        vlSelf->tb_convBRAM__DOT__done = 0U;
        if ((8U & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state))) {
            vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 0U;
        } else if ((4U & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state))) {
            if ((2U & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state))) {
                if ((1U & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state))) {
                    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT____Vlvbound_hc16deefc__0 
                        = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator
                        [0U];
                    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__lane = 2U;
                    if (((2U >= (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn)) 
                         && (2U >= (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow)))) {
                        vlSelf->__Vdlyvval__tb_convBRAM__DOT__outData__v18 
                            = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT____Vlvbound_hc16deefc__0;
                        vlSelf->__Vdlyvset__tb_convBRAM__DOT__outData__v18 = 1U;
                        vlSelf->__Vdlyvdim2__tb_convBRAM__DOT__outData__v18 
                            = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn;
                        vlSelf->__Vdlyvdim1__tb_convBRAM__DOT__outData__v18 
                            = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow;
                        vlSelf->__Vdlyvdim0__tb_convBRAM__DOT__outData__v18 
                            = (1U & VL_SHIFTL_III(1,32,32, (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex), 1U));
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT____Vlvbound_hc16deefc__0 
                            = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator
                            [1U];
                        vlSelf->__Vdlyvval__tb_convBRAM__DOT__outData__v19 
                            = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT____Vlvbound_hc16deefc__0;
                        vlSelf->__Vdlyvset__tb_convBRAM__DOT__outData__v19 = 1U;
                        vlSelf->__Vdlyvdim2__tb_convBRAM__DOT__outData__v19 
                            = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn;
                        vlSelf->__Vdlyvdim1__tb_convBRAM__DOT__outData__v19 
                            = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow;
                        vlSelf->__Vdlyvdim0__tb_convBRAM__DOT__outData__v19 
                            = (1U & ((IData)(1U) + 
                                     VL_SHIFTL_III(1,32,32, (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex), 1U)));
                    } else {
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT____Vlvbound_hc16deefc__0 
                            = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator
                            [1U];
                    }
                    if ((2U != (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn))) {
                        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn 
                            = (3U & ((IData)(1U) + (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn)));
                        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 5U;
                    } else if ((2U != (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow))) {
                        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow 
                            = (3U & ((IData)(1U) + (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow)));
                        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn = 0U;
                        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 5U;
                    } else {
                        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress 
                            = (0xfU & ((IData)(9U) 
                                       + (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress)));
                        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn = 0U;
                        vlSelf->tb_convBRAM__DOT__dut__DOT__baddr 
                            = (1U & ((IData)(1U) + (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex)));
                        vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 1U;
                    }
                } else {
                    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid 
                        = ((2U & ((IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid) 
                                  << 1U)) | (1U & (~ (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone))));
                    if ((1U & (~ (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone)))) {
                        if ((8U == (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm))) {
                            vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone = 1U;
                        } else {
                            vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm 
                                = (0xfU & ((IData)(1U) 
                                           + (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm)));
                        }
                    }
                    if ((2U & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid))) {
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputChannel 
                            = VL_DIV_III(32, (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm), (IData)(9U));
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__kernelRow 
                            = VL_MODDIV_III(32, VL_DIV_III(32, (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm), (IData)(3U)), (IData)(3U));
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__lane = 2U;
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__kernelColumn 
                            = VL_MODDIV_III(32, (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm), (IData)(3U));
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputRow 
                            = (((IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn) 
                                + vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__kernelColumn) 
                               - (IData)(1U));
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputValue 
                            = ((((VL_GTS_III(32, 0U, vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputRow) 
                                  | VL_LTES_III(32, 3U, vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputRow)) 
                                 | VL_GTS_III(32, 0U, vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputColumn)) 
                                | VL_LTES_III(32, 3U, vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputColumn))
                                ? 0U : ([&]() {
                                    __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendInput__0__value 
                                        = ((2U >= (3U 
                                                   & vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputColumn))
                                            ? vlSelf->tb_convBRAM__DOT__inData
                                           [((0U >= 
                                              (1U & vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputChannel)) 
                                             && (1U 
                                                 & vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputChannel))]
                                           [((2U >= 
                                              (3U & vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputRow))
                                              ? (3U 
                                                 & vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputRow)
                                              : 0U)]
                                           [(3U & vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputColumn)]
                                            : 0U);
                                    __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendInput__0__Vfuncout 
                                        = __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendInput__0__value;
                                }(), __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendInput__0__Vfuncout));
                        __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__value 
                            = (0xffU & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightWord));
                        __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__Vfuncout 
                            = (((- (IData)((1U & ((IData)(__Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__value) 
                                                  >> 7U)))) 
                                << 8U) | (IData)(__Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__value));
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValue 
                            = __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__Vfuncout;
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__product 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputValue), 
                                          VL_EXTENDS_QI(64,32, vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValue));
                        vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v2 
                            = (vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator
                               [0U] + (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__product));
                        vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v2 = 1U;
                        __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__value 
                            = (0xffU & ((IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightWord) 
                                        >> 8U));
                        __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__Vfuncout 
                            = (((- (IData)((1U & ((IData)(__Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__value) 
                                                  >> 7U)))) 
                                << 8U) | (IData)(__Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__value));
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValue 
                            = __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendWeight__1__Vfuncout;
                        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__product 
                            = VL_MULS_QQQ(64, VL_EXTENDS_QI(64,32, vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputValue), 
                                          VL_EXTENDS_QI(64,32, vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValue));
                        vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v3 
                            = (vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator
                               [1U] + (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__product));
                        vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v3 = 1U;
                        if ((8U == (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm))) {
                            vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid = 0U;
                            vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 7U;
                        } else {
                            vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm 
                                = (0xfU & ((IData)(1U) 
                                           + (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm)));
                        }
                    }
                }
            } else if ((1U & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state))) {
                vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__lane = 2U;
                vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v4 
                    = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue
                    [0U];
                vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v4 = 1U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm = 0U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm = 0U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid = 0U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone = 0U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 6U;
                vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v5 
                    = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue
                    [1U];
                vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v5 = 1U;
            } else {
                __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__value 
                    = (0xffU & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasWord));
                vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__lane = 2U;
                __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__Vfuncout 
                    = (((- (IData)((1U & ((IData)(__Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__value) 
                                          >> 7U)))) 
                        << 8U) | (IData)(__Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__value));
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 5U;
                vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v2 
                    = __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__Vfuncout;
                vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v2 = 1U;
                __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__value 
                    = (0xffU & ((IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasWord) 
                                >> 8U));
                __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__Vfuncout 
                    = (((- (IData)((1U & ((IData)(__Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__value) 
                                          >> 7U)))) 
                        << 8U) | (IData)(__Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__value));
                vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v3 
                    = __Vfunc_tb_convBRAM__DOT__dut__DOT__core__DOT__extendBias__2__Vfuncout;
                vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v3 = 1U;
            }
        } else if ((2U & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state))) {
            vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state 
                = ((1U & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state))
                    ? 4U : 3U);
        } else if ((1U & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state))) {
            vlSelf->tb_convBRAM__DOT__dut__DOT__baddr 
                = vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex;
            vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 2U;
        } else {
            vlSelf->tb_convBRAM__DOT__busy = 0U;
            if (vlSelf->tb_convBRAM__DOT__start) {
                vlSelf->tb_convBRAM__DOT__busy = 1U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex = 0U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow = 0U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn = 0U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress = 0U;
                vlSelf->tb_convBRAM__DOT__dut__DOT__baddr = 0U;
                vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = 1U;
            }
        }
    }
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__28(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__28\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone 
        = vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__29(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__29\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid 
        = vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__30(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__30\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn 
        = vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__31(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__31\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow 
        = vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__32(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__32\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm 
        = vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__33(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__33\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex 
        = vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__37(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__37\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state 
        = vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__38(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__38\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress 
        = vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__39(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__39\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm 
        = vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm;
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__42(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__42\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__waddr = (0xfU 
                                                 & ((IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm) 
                                                    + (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress)));
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__43(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__43\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightWord 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe
        [0U];
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__44(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__44\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasWord 
        = vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe
        [0U];
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__47(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__47\n"); );
    // Body
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe__v0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe[0U] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe__v0;
    }
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__48(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__48\n"); );
    // Body
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe__v0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe[0U] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe__v0;
    }
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__49(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__49\n"); );
    // Body
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue[0U] = 0U;
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue[1U] = 0U;
    }
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v2) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue[0U] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v2;
    }
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v3) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue[1U] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v3;
    }
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__50(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__50\n"); );
    // Body
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator[0U] = 0U;
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator[1U] = 0U;
    }
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v2) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator[0U] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v2;
    }
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v3) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator[1U] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v3;
    }
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v4) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator[0U] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v4;
    }
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v5) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator[1U] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v5;
    }
}

VL_INLINE_OPT void Vtb_convBRAM___024root___nba_sequent__TOP__51(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___nba_sequent__TOP__51\n"); );
    // Body
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v0) {
        vlSelf->tb_convBRAM__DOT__outData[0U][0U][0U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[0U][0U][1U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[0U][0U][2U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[0U][1U][0U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[0U][1U][1U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[0U][1U][2U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[0U][2U][0U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[0U][2U][1U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[0U][2U][2U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[1U][0U][0U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[1U][0U][1U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[1U][0U][2U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[1U][1U][0U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[1U][1U][1U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[1U][1U][2U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[1U][2U][0U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[1U][2U][1U] = 0U;
        vlSelf->tb_convBRAM__DOT__outData[1U][2U][2U] = 0U;
    }
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__outData__v18) {
        vlSelf->tb_convBRAM__DOT__outData[vlSelf->__Vdlyvdim0__tb_convBRAM__DOT__outData__v18][vlSelf->__Vdlyvdim1__tb_convBRAM__DOT__outData__v18][vlSelf->__Vdlyvdim2__tb_convBRAM__DOT__outData__v18] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__outData__v18;
    }
    if (vlSelf->__Vdlyvset__tb_convBRAM__DOT__outData__v19) {
        vlSelf->tb_convBRAM__DOT__outData[vlSelf->__Vdlyvdim0__tb_convBRAM__DOT__outData__v19][vlSelf->__Vdlyvdim1__tb_convBRAM__DOT__outData__v19][vlSelf->__Vdlyvdim2__tb_convBRAM__DOT__outData__v19] 
            = vlSelf->__Vdlyvval__tb_convBRAM__DOT__outData__v19;
    }
}

void Vtb_convBRAM___024root___timing_resume(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___timing_resume\n"); );
    // Body
    if ((1ULL & vlSelf->__VactTriggered.word(0U))) {
        vlSelf->__VtrigSched_h52bcd072__0.resume("@(posedge tb_convBRAM.clk)");
    }
    if ((4ULL & vlSelf->__VactTriggered.word(0U))) {
        vlSelf->__VtrigSched_hba22dc0b__0.resume("@([changed] tb_convBRAM.done)");
    }
    if ((8ULL & vlSelf->__VactTriggered.word(0U))) {
        vlSelf->__VdlySched.resume();
    }
}

void Vtb_convBRAM___024root___timing_commit(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___timing_commit\n"); );
    // Body
    if ((! (1ULL & vlSelf->__VactTriggered.word(0U)))) {
        vlSelf->__VtrigSched_h52bcd072__0.commit("@(posedge tb_convBRAM.clk)");
    }
    if ((! (4ULL & vlSelf->__VactTriggered.word(0U)))) {
        vlSelf->__VtrigSched_hba22dc0b__0.commit("@([changed] tb_convBRAM.done)");
    }
}

void Vtb_convBRAM___024root___eval_triggers__act(Vtb_convBRAM___024root* vlSelf);

bool Vtb_convBRAM___024root___eval_phase__act(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_phase__act\n"); );
    // Init
    VlTriggerVec<4> __VpreTriggered;
    CData/*0:0*/ __VactExecute;
    // Body
    Vtb_convBRAM___024root___eval_triggers__act(vlSelf);
    Vtb_convBRAM___024root___timing_commit(vlSelf);
    __VactExecute = vlSelf->__VactTriggered.any();
    if (__VactExecute) {
        __VpreTriggered.andNot(vlSelf->__VactTriggered, vlSelf->__VnbaTriggered);
        vlSelf->__VnbaTriggered.thisOr(vlSelf->__VactTriggered);
        Vtb_convBRAM___024root___timing_resume(vlSelf);
        Vtb_convBRAM___024root___eval_act(vlSelf);
    }
    return (__VactExecute);
}

void Vtb_convBRAM___024root___eval_nba(Vtb_convBRAM___024root* vlSelf);

bool Vtb_convBRAM___024root___eval_phase__nba(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_phase__nba\n"); );
    // Init
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = vlSelf->__VnbaTriggered.any();
    if (__VnbaExecute) {
        Vtb_convBRAM___024root___eval_nba(vlSelf);
        vlSelf->__VnbaTriggered.clear();
    }
    return (__VnbaExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_convBRAM___024root___dump_triggers__nba(Vtb_convBRAM___024root* vlSelf);
#endif  // VL_DEBUG
#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_convBRAM___024root___dump_triggers__act(Vtb_convBRAM___024root* vlSelf);
#endif  // VL_DEBUG

void Vtb_convBRAM___024root___eval(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval\n"); );
    // Init
    IData/*31:0*/ __VnbaIterCount;
    CData/*0:0*/ __VnbaContinue;
    // Body
    __VnbaIterCount = 0U;
    __VnbaContinue = 1U;
    while (__VnbaContinue) {
        if (VL_UNLIKELY((0x64U < __VnbaIterCount))) {
#ifdef VL_DEBUG
            Vtb_convBRAM___024root___dump_triggers__nba(vlSelf);
#endif
            VL_FATAL_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 3, "", "NBA region did not converge.");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        __VnbaContinue = 0U;
        vlSelf->__VactIterCount = 0U;
        vlSelf->__VactContinue = 1U;
        while (vlSelf->__VactContinue) {
            if (VL_UNLIKELY((0x64U < vlSelf->__VactIterCount))) {
#ifdef VL_DEBUG
                Vtb_convBRAM___024root___dump_triggers__act(vlSelf);
#endif
                VL_FATAL_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 3, "", "Active region did not converge.");
            }
            vlSelf->__VactIterCount = ((IData)(1U) 
                                       + vlSelf->__VactIterCount);
            vlSelf->__VactContinue = 0U;
            if (Vtb_convBRAM___024root___eval_phase__act(vlSelf)) {
                vlSelf->__VactContinue = 1U;
            }
        }
        if (Vtb_convBRAM___024root___eval_phase__nba(vlSelf)) {
            __VnbaContinue = 1U;
        }
    }
}

#ifdef VL_DEBUG
void Vtb_convBRAM___024root___eval_debug_assertions(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_debug_assertions\n"); );
}
#endif  // VL_DEBUG
