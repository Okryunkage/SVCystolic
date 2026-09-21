// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_convBRAM.h for the primary calling header

#include "Vtb_convBRAM__pch.h"
#include "Vtb_convBRAM___024root.h"

VL_ATTR_COLD void Vtb_convBRAM___024root___eval_static__TOP(Vtb_convBRAM___024root* vlSelf);

VL_ATTR_COLD void Vtb_convBRAM___024root___eval_static(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_static\n"); );
    // Body
    Vtb_convBRAM___024root___eval_static__TOP(vlSelf);
    vlSelf->__Vm_traceActivity[6U] = 1U;
    vlSelf->__Vm_traceActivity[5U] = 1U;
    vlSelf->__Vm_traceActivity[4U] = 1U;
    vlSelf->__Vm_traceActivity[3U] = 1U;
    vlSelf->__Vm_traceActivity[2U] = 1U;
    vlSelf->__Vm_traceActivity[1U] = 1U;
    vlSelf->__Vm_traceActivity[0U] = 1U;
}

VL_ATTR_COLD void Vtb_convBRAM___024root___eval_static__TOP(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_static__TOP\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__clk = 0U;
    vlSelf->tb_convBRAM__DOT__rst = 1U;
    vlSelf->tb_convBRAM__DOT__start = 0U;
}

VL_ATTR_COLD void Vtb_convBRAM___024root___eval_initial__TOP(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_initial__TOP\n"); );
    // Init
    VlWide<5>/*159:0*/ __Vtemp_1;
    VlWide<5>/*159:0*/ __Vtemp_2;
    // Body
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[0U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[1U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[2U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[3U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[4U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[5U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[6U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[7U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[8U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__i = 9U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightWord = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe[0U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__p = 1U;
    VL_WRITEF("xpm_memory_spram_sim: loading memory file: tb_conv_w_tile.mem\n");
    __Vtemp_1[0U] = 0x2e6d656dU;
    __Vtemp_1[1U] = 0x74696c65U;
    __Vtemp_1[2U] = 0x765f775fU;
    __Vtemp_1[3U] = 0x5f636f6eU;
    __Vtemp_1[4U] = 0x7462U;
    VL_READMEM_N(true, 16, 9, 0, VL_CVT_PACK_STR_NW(5, __Vtemp_1)
                 ,  &(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem)
                 , 0, ~0ULL);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__mem[0U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__mem[1U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__i = 2U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasWord = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe[0U] = 0U;
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__p = 1U;
    VL_WRITEF("xpm_memory_spram_sim: loading memory file: tb_conv_b_tile.mem\n");
    __Vtemp_2[0U] = 0x2e6d656dU;
    __Vtemp_2[1U] = 0x74696c65U;
    __Vtemp_2[2U] = 0x765f625fU;
    __Vtemp_2[3U] = 0x5f636f6eU;
    __Vtemp_2[4U] = 0x7462U;
    VL_READMEM_N(true, 16, 2, 0, VL_CVT_PACK_STR_NW(5, __Vtemp_2)
                 ,  &(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__mem)
                 , 0, ~0ULL);
}

VL_ATTR_COLD void Vtb_convBRAM___024root___eval_final(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_final\n"); );
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_convBRAM___024root___dump_triggers__stl(Vtb_convBRAM___024root* vlSelf);
#endif  // VL_DEBUG
VL_ATTR_COLD bool Vtb_convBRAM___024root___eval_phase__stl(Vtb_convBRAM___024root* vlSelf);

VL_ATTR_COLD void Vtb_convBRAM___024root___eval_settle(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_settle\n"); );
    // Init
    IData/*31:0*/ __VstlIterCount;
    CData/*0:0*/ __VstlContinue;
    // Body
    __VstlIterCount = 0U;
    vlSelf->__VstlFirstIteration = 1U;
    __VstlContinue = 1U;
    while (__VstlContinue) {
        if (VL_UNLIKELY((0x64U < __VstlIterCount))) {
#ifdef VL_DEBUG
            Vtb_convBRAM___024root___dump_triggers__stl(vlSelf);
#endif
            VL_FATAL_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 3, "", "Settle region did not converge.");
        }
        __VstlIterCount = ((IData)(1U) + __VstlIterCount);
        __VstlContinue = 0U;
        if (Vtb_convBRAM___024root___eval_phase__stl(vlSelf)) {
            __VstlContinue = 1U;
        }
        vlSelf->__VstlFirstIteration = 0U;
    }
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_convBRAM___024root___dump_triggers__stl(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___dump_triggers__stl\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VstlTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VstlTriggered.word(0U))) {
        VL_DBG_MSGF("         'stl' region trigger index 0 is active: Internal 'stl' trigger - first iteration\n");
    }
}
#endif  // VL_DEBUG

void Vtb_convBRAM___024root___nba_sequent__TOP__42(Vtb_convBRAM___024root* vlSelf);

VL_ATTR_COLD void Vtb_convBRAM___024root___eval_stl(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_stl\n"); );
    // Body
    if ((1ULL & vlSelf->__VstlTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__42(vlSelf);
    }
}

VL_ATTR_COLD void Vtb_convBRAM___024root___eval_triggers__stl(Vtb_convBRAM___024root* vlSelf);

VL_ATTR_COLD bool Vtb_convBRAM___024root___eval_phase__stl(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_phase__stl\n"); );
    // Init
    CData/*0:0*/ __VstlExecute;
    // Body
    Vtb_convBRAM___024root___eval_triggers__stl(vlSelf);
    __VstlExecute = vlSelf->__VstlTriggered.any();
    if (__VstlExecute) {
        Vtb_convBRAM___024root___eval_stl(vlSelf);
    }
    return (__VstlExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_convBRAM___024root___dump_triggers__act(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___dump_triggers__act\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VactTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VactTriggered.word(0U))) {
        VL_DBG_MSGF("         'act' region trigger index 0 is active: @(posedge tb_convBRAM.clk)\n");
    }
    if ((2ULL & vlSelf->__VactTriggered.word(0U))) {
        VL_DBG_MSGF("         'act' region trigger index 1 is active: @(posedge tb_convBRAM.clk or posedge tb_convBRAM.rst)\n");
    }
    if ((4ULL & vlSelf->__VactTriggered.word(0U))) {
        VL_DBG_MSGF("         'act' region trigger index 2 is active: @([changed] tb_convBRAM.done)\n");
    }
    if ((8ULL & vlSelf->__VactTriggered.word(0U))) {
        VL_DBG_MSGF("         'act' region trigger index 3 is active: @([true] __VdlySched.awaitingCurrentTime())\n");
    }
}
#endif  // VL_DEBUG

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_convBRAM___024root___dump_triggers__nba(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___dump_triggers__nba\n"); );
    // Body
    if ((1U & (~ (IData)(vlSelf->__VnbaTriggered.any())))) {
        VL_DBG_MSGF("         No triggers active\n");
    }
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        VL_DBG_MSGF("         'nba' region trigger index 0 is active: @(posedge tb_convBRAM.clk)\n");
    }
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        VL_DBG_MSGF("         'nba' region trigger index 1 is active: @(posedge tb_convBRAM.clk or posedge tb_convBRAM.rst)\n");
    }
    if ((4ULL & vlSelf->__VnbaTriggered.word(0U))) {
        VL_DBG_MSGF("         'nba' region trigger index 2 is active: @([changed] tb_convBRAM.done)\n");
    }
    if ((8ULL & vlSelf->__VnbaTriggered.word(0U))) {
        VL_DBG_MSGF("         'nba' region trigger index 3 is active: @([true] __VdlySched.awaitingCurrentTime())\n");
    }
}
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtb_convBRAM___024root___ctor_var_reset(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___ctor_var_reset\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__clk = VL_RAND_RESET_I(1);
    vlSelf->tb_convBRAM__DOT__rst = VL_RAND_RESET_I(1);
    vlSelf->tb_convBRAM__DOT__start = VL_RAND_RESET_I(1);
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        for (int __Vi1 = 0; __Vi1 < 3; ++__Vi1) {
            for (int __Vi2 = 0; __Vi2 < 3; ++__Vi2) {
                vlSelf->tb_convBRAM__DOT__inData[__Vi0][__Vi1][__Vi2] = VL_RAND_RESET_I(8);
            }
        }
    }
    vlSelf->tb_convBRAM__DOT__busy = VL_RAND_RESET_I(1);
    vlSelf->tb_convBRAM__DOT__done = VL_RAND_RESET_I(1);
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        for (int __Vi1 = 0; __Vi1 < 3; ++__Vi1) {
            for (int __Vi2 = 0; __Vi2 < 3; ++__Vi2) {
                vlSelf->tb_convBRAM__DOT__outData[__Vi0][__Vi1][__Vi2] = VL_RAND_RESET_I(32);
            }
        }
    }
    for (int __Vi0 = 0; __Vi0 < 9; ++__Vi0) {
        vlSelf->tb_convBRAM__DOT__expected0[__Vi0] = 0;
    }
    vlSelf->tb_convBRAM__DOT__index = 0;
    vlSelf->tb_convBRAM__DOT__row = 0;
    vlSelf->tb_convBRAM__DOT__column = 0;
    vlSelf->tb_convBRAM__DOT__dut__DOT__waddr = VL_RAND_RESET_I(4);
    vlSelf->tb_convBRAM__DOT__dut__DOT__baddr = VL_RAND_RESET_I(1);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightWord = VL_RAND_RESET_I(16);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasWord = VL_RAND_RESET_I(16);
    for (int __Vi0 = 0; __Vi0 < 9; ++__Vi0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[__Vi0] = VL_RAND_RESET_I(16);
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe[__Vi0] = VL_RAND_RESET_I(16);
    }
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__old_word = VL_RAND_RESET_I(16);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__new_word = VL_RAND_RESET_I(16);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__read_word = VL_RAND_RESET_I(16);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__i = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__p = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__lane = VL_RAND_RESET_I(32);
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__mem[__Vi0] = VL_RAND_RESET_I(16);
    }
    for (int __Vi0 = 0; __Vi0 < 1; ++__Vi0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe[__Vi0] = VL_RAND_RESET_I(16);
    }
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__old_word = VL_RAND_RESET_I(16);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__new_word = VL_RAND_RESET_I(16);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__read_word = VL_RAND_RESET_I(16);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__i = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__p = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__lane = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state = VL_RAND_RESET_I(4);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex = VL_RAND_RESET_I(1);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm = VL_RAND_RESET_I(4);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm = VL_RAND_RESET_I(4);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow = VL_RAND_RESET_I(2);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn = VL_RAND_RESET_I(2);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress = VL_RAND_RESET_I(4);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid = VL_RAND_RESET_I(2);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone = VL_RAND_RESET_I(1);
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue[__Vi0] = VL_RAND_RESET_I(32);
    }
    for (int __Vi0 = 0; __Vi0 < 2; ++__Vi0) {
        vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator[__Vi0] = VL_RAND_RESET_I(32);
    }
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__lane = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__channel = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__row = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__column = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputChannel = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__kernelRow = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__kernelColumn = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputRow = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputColumn = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputValue = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValue = VL_RAND_RESET_I(32);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__product = VL_RAND_RESET_Q(64);
    vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT____Vlvbound_hc16deefc__0 = VL_RAND_RESET_I(32);
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe__v0 = VL_RAND_RESET_I(16);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe__v0 = 0;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe__v0 = VL_RAND_RESET_I(16);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe__v0 = 0;
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__state = VL_RAND_RESET_I(4);
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex = VL_RAND_RESET_I(1);
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm = VL_RAND_RESET_I(4);
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm = VL_RAND_RESET_I(4);
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow = VL_RAND_RESET_I(2);
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn = VL_RAND_RESET_I(2);
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress = VL_RAND_RESET_I(4);
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid = VL_RAND_RESET_I(2);
    vlSelf->__Vdly__tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone = VL_RAND_RESET_I(1);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v0 = 0;
    vlSelf->__Vdlyvdim0__tb_convBRAM__DOT__outData__v18 = 0;
    vlSelf->__Vdlyvdim1__tb_convBRAM__DOT__outData__v18 = 0;
    vlSelf->__Vdlyvdim2__tb_convBRAM__DOT__outData__v18 = 0;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__outData__v18 = VL_RAND_RESET_I(32);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__outData__v18 = 0;
    vlSelf->__Vdlyvdim0__tb_convBRAM__DOT__outData__v19 = 0;
    vlSelf->__Vdlyvdim1__tb_convBRAM__DOT__outData__v19 = 0;
    vlSelf->__Vdlyvdim2__tb_convBRAM__DOT__outData__v19 = 0;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__outData__v19 = VL_RAND_RESET_I(32);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__outData__v19 = 0;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v2 = VL_RAND_RESET_I(32);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v2 = 0;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v3 = VL_RAND_RESET_I(32);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v3 = 0;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v4 = VL_RAND_RESET_I(32);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v4 = 0;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v5 = VL_RAND_RESET_I(32);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator__v5 = 0;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v2 = VL_RAND_RESET_I(32);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v2 = 0;
    vlSelf->__Vdlyvval__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v3 = VL_RAND_RESET_I(32);
    vlSelf->__Vdlyvset__tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue__v3 = 0;
    vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__clk__0 = VL_RAND_RESET_I(1);
    vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__rst__0 = VL_RAND_RESET_I(1);
    vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__done__0 = VL_RAND_RESET_I(1);
    vlSelf->__VactDidInit = 0;
    for (int __Vi0 = 0; __Vi0 < 7; ++__Vi0) {
        vlSelf->__Vm_traceActivity[__Vi0] = 0;
    }
}
