// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vtb_convBRAM__Syms.h"


void Vtb_convBRAM___024root__trace_chg_0_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_convBRAM___024root__trace_chg_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_0\n"); );
    // Init
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb_convBRAM___024root__trace_chg_0_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_convBRAM___024root__trace_chg_0_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_0_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 1);
    // Body
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[1U])) {
        bufp->chgSData(oldp+0,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__mem[0]),16);
        bufp->chgSData(oldp+1,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__mem[1]),16);
        bufp->chgIData(oldp+2,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__i),32);
        bufp->chgSData(oldp+3,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[0]),16);
        bufp->chgSData(oldp+4,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[1]),16);
        bufp->chgSData(oldp+5,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[2]),16);
        bufp->chgSData(oldp+6,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[3]),16);
        bufp->chgSData(oldp+7,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[4]),16);
        bufp->chgSData(oldp+8,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[5]),16);
        bufp->chgSData(oldp+9,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[6]),16);
        bufp->chgSData(oldp+10,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[7]),16);
        bufp->chgSData(oldp+11,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__mem[8]),16);
        bufp->chgIData(oldp+12,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__i),32);
    }
}

void Vtb_convBRAM___024root__trace_chg_1_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_convBRAM___024root__trace_chg_1(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_1\n"); );
    // Init
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb_convBRAM___024root__trace_chg_1_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_convBRAM___024root__trace_chg_1_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_1_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 14);
    // Body
    if (VL_UNLIKELY((vlSelf->__Vm_traceActivity[1U] 
                     | vlSelf->__Vm_traceActivity[2U]))) {
        bufp->chgBit(oldp+0,(vlSelf->tb_convBRAM__DOT__rst));
        bufp->chgBit(oldp+1,(vlSelf->tb_convBRAM__DOT__start));
        bufp->chgCData(oldp+2,(vlSelf->tb_convBRAM__DOT__inData
                               [0U][0U][0U]),8);
        bufp->chgCData(oldp+3,(vlSelf->tb_convBRAM__DOT__inData
                               [0U][0U][1U]),8);
        bufp->chgCData(oldp+4,(vlSelf->tb_convBRAM__DOT__inData
                               [0U][0U][2U]),8);
        bufp->chgCData(oldp+5,(vlSelf->tb_convBRAM__DOT__inData
                               [0U][1U][0U]),8);
        bufp->chgCData(oldp+6,(vlSelf->tb_convBRAM__DOT__inData
                               [0U][1U][1U]),8);
        bufp->chgCData(oldp+7,(vlSelf->tb_convBRAM__DOT__inData
                               [0U][1U][2U]),8);
        bufp->chgCData(oldp+8,(vlSelf->tb_convBRAM__DOT__inData
                               [0U][2U][0U]),8);
        bufp->chgCData(oldp+9,(vlSelf->tb_convBRAM__DOT__inData
                               [0U][2U][1U]),8);
        bufp->chgCData(oldp+10,(vlSelf->tb_convBRAM__DOT__inData
                                [0U][2U][2U]),8);
        bufp->chgIData(oldp+11,(vlSelf->tb_convBRAM__DOT__expected0[0]),32);
        bufp->chgIData(oldp+12,(vlSelf->tb_convBRAM__DOT__expected0[1]),32);
        bufp->chgIData(oldp+13,(vlSelf->tb_convBRAM__DOT__expected0[2]),32);
        bufp->chgIData(oldp+14,(vlSelf->tb_convBRAM__DOT__expected0[3]),32);
        bufp->chgIData(oldp+15,(vlSelf->tb_convBRAM__DOT__expected0[4]),32);
        bufp->chgIData(oldp+16,(vlSelf->tb_convBRAM__DOT__expected0[5]),32);
        bufp->chgIData(oldp+17,(vlSelf->tb_convBRAM__DOT__expected0[6]),32);
        bufp->chgIData(oldp+18,(vlSelf->tb_convBRAM__DOT__expected0[7]),32);
        bufp->chgIData(oldp+19,(vlSelf->tb_convBRAM__DOT__expected0[8]),32);
    }
}

void Vtb_convBRAM___024root__trace_chg_2_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_convBRAM___024root__trace_chg_2(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_2\n"); );
    // Init
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb_convBRAM___024root__trace_chg_2_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_convBRAM___024root__trace_chg_2_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_2_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 34);
    // Body
    if (VL_UNLIKELY((vlSelf->__Vm_traceActivity[1U] 
                     | vlSelf->__Vm_traceActivity[2U]))) {
        bufp->chgIData(oldp+0,(vlSelf->tb_convBRAM__DOT__index),32);
        bufp->chgIData(oldp+1,(vlSelf->tb_convBRAM__DOT__row),32);
        bufp->chgIData(oldp+2,(vlSelf->tb_convBRAM__DOT__column),32);
    }
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[3U])) {
        bufp->chgSData(oldp+3,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__old_word),16);
        bufp->chgSData(oldp+4,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__new_word),16);
        bufp->chgSData(oldp+5,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__read_word),16);
    }
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[4U])) {
        bufp->chgSData(oldp+6,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__old_word),16);
        bufp->chgSData(oldp+7,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__new_word),16);
        bufp->chgSData(oldp+8,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__read_word),16);
    }
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[5U])) {
        bufp->chgBit(oldp+9,(vlSelf->tb_convBRAM__DOT__busy));
        bufp->chgBit(oldp+10,(vlSelf->tb_convBRAM__DOT__done));
        bufp->chgBit(oldp+11,(vlSelf->tb_convBRAM__DOT__dut__DOT__baddr));
        bufp->chgIData(oldp+12,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__lane),32);
    }
}

void Vtb_convBRAM___024root__trace_chg_3_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_convBRAM___024root__trace_chg_3(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_3\n"); );
    // Init
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb_convBRAM___024root__trace_chg_3_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_convBRAM___024root__trace_chg_3_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_3_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 47);
    // Body
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[5U])) {
        bufp->chgIData(oldp+0,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__channel),32);
        bufp->chgIData(oldp+1,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__row),32);
        bufp->chgIData(oldp+2,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__column),32);
        bufp->chgIData(oldp+3,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputChannel),32);
        bufp->chgIData(oldp+4,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__kernelRow),32);
        bufp->chgIData(oldp+5,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__kernelColumn),32);
        bufp->chgIData(oldp+6,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputRow),32);
        bufp->chgIData(oldp+7,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__inputValue),32);
        bufp->chgIData(oldp+8,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValue),32);
        bufp->chgQData(oldp+9,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__product),64);
    }
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[6U])) {
        bufp->chgIData(oldp+11,(vlSelf->tb_convBRAM__DOT__outData
                                [0U][0U][0U]),32);
        bufp->chgIData(oldp+12,(vlSelf->tb_convBRAM__DOT__outData
                                [0U][0U][1U]),32);
    }
}

void Vtb_convBRAM___024root__trace_chg_4_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_convBRAM___024root__trace_chg_4(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_4\n"); );
    // Init
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb_convBRAM___024root__trace_chg_4_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_convBRAM___024root__trace_chg_4_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_4_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 60);
    // Body
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[6U])) {
        bufp->chgIData(oldp+0,(vlSelf->tb_convBRAM__DOT__outData
                               [0U][0U][2U]),32);
        bufp->chgIData(oldp+1,(vlSelf->tb_convBRAM__DOT__outData
                               [0U][1U][0U]),32);
        bufp->chgIData(oldp+2,(vlSelf->tb_convBRAM__DOT__outData
                               [0U][1U][1U]),32);
        bufp->chgIData(oldp+3,(vlSelf->tb_convBRAM__DOT__outData
                               [0U][1U][2U]),32);
        bufp->chgIData(oldp+4,(vlSelf->tb_convBRAM__DOT__outData
                               [0U][2U][0U]),32);
        bufp->chgIData(oldp+5,(vlSelf->tb_convBRAM__DOT__outData
                               [0U][2U][1U]),32);
        bufp->chgIData(oldp+6,(vlSelf->tb_convBRAM__DOT__outData
                               [0U][2U][2U]),32);
        bufp->chgIData(oldp+7,(vlSelf->tb_convBRAM__DOT__outData
                               [1U][0U][0U]),32);
        bufp->chgIData(oldp+8,(vlSelf->tb_convBRAM__DOT__outData
                               [1U][0U][1U]),32);
        bufp->chgIData(oldp+9,(vlSelf->tb_convBRAM__DOT__outData
                               [1U][0U][2U]),32);
        bufp->chgIData(oldp+10,(vlSelf->tb_convBRAM__DOT__outData
                                [1U][1U][0U]),32);
        bufp->chgIData(oldp+11,(vlSelf->tb_convBRAM__DOT__outData
                                [1U][1U][1U]),32);
        bufp->chgIData(oldp+12,(vlSelf->tb_convBRAM__DOT__outData
                                [1U][1U][2U]),32);
    }
}

void Vtb_convBRAM___024root__trace_chg_5_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_convBRAM___024root__trace_chg_5(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_5\n"); );
    // Init
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb_convBRAM___024root__trace_chg_5_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_convBRAM___024root__trace_chg_5_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_5_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 73);
    // Body
    if (VL_UNLIKELY(vlSelf->__Vm_traceActivity[6U])) {
        bufp->chgIData(oldp+0,(vlSelf->tb_convBRAM__DOT__outData
                               [1U][2U][0U]),32);
        bufp->chgIData(oldp+1,(vlSelf->tb_convBRAM__DOT__outData
                               [1U][2U][1U]),32);
        bufp->chgIData(oldp+2,(vlSelf->tb_convBRAM__DOT__outData
                               [1U][2U][2U]),32);
    }
    bufp->chgBit(oldp+3,(vlSelf->tb_convBRAM__DOT__clk));
    bufp->chgCData(oldp+4,(vlSelf->tb_convBRAM__DOT__dut__DOT__waddr),4);
    bufp->chgCData(oldp+5,((0xffU & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightWord))),8);
    bufp->chgCData(oldp+6,((0xffU & ((IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightWord) 
                                     >> 8U))),8);
    bufp->chgCData(oldp+7,((0xffU & (IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasWord))),8);
    bufp->chgCData(oldp+8,((0xffU & ((IData)(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasWord) 
                                     >> 8U))),8);
    bufp->chgCData(oldp+9,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__state),4);
    bufp->chgBit(oldp+10,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__tileIndex));
    bufp->chgCData(oldp+11,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueTerm),4);
    bufp->chgCData(oldp+12,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__consumeTerm),4);
}

void Vtb_convBRAM___024root__trace_chg_6_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_convBRAM___024root__trace_chg_6(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_6\n"); );
    // Init
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb_convBRAM___024root__trace_chg_6_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_convBRAM___024root__trace_chg_6_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_6_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 86);
    // Body
    bufp->chgCData(oldp+0,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputRow),2);
    bufp->chgCData(oldp+1,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__outputColumn),2);
    bufp->chgCData(oldp+2,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightBaseAddress),4);
    bufp->chgCData(oldp+3,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__weightValid),2);
    bufp->chgBit(oldp+4,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__issueDone));
    bufp->chgIData(oldp+5,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue[0]),32);
    bufp->chgIData(oldp+6,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__biasValue[1]),32);
    bufp->chgIData(oldp+7,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator[0]),32);
    bufp->chgIData(oldp+8,(vlSelf->tb_convBRAM__DOT__dut__DOT__core__DOT__accumulator[1]),32);
    bufp->chgSData(oldp+9,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightWord),16);
    bufp->chgSData(oldp+10,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasWord),16);
    bufp->chgSData(oldp+11,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__rd_pipe[0]),16);
    bufp->chgIData(oldp+12,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__p),32);
}

void Vtb_convBRAM___024root__trace_chg_7_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb_convBRAM___024root__trace_chg_7(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_7\n"); );
    // Init
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb_convBRAM___024root__trace_chg_7_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb_convBRAM___024root__trace_chg_7_sub_0(Vtb_convBRAM___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_chg_7_sub_0\n"); );
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 99);
    // Body
    bufp->chgIData(oldp+0,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__biasMemory__DOT__lane),32);
    bufp->chgSData(oldp+1,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__rd_pipe[0]),16);
    bufp->chgIData(oldp+2,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__p),32);
    bufp->chgIData(oldp+3,(vlSelf->tb_convBRAM__DOT__dut__DOT__memory__DOT__weightMemory__DOT__lane),32);
}

void Vtb_convBRAM___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root__trace_cleanup\n"); );
    // Init
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    vlSymsp->__Vm_activity = false;
    vlSymsp->TOP.__Vm_traceActivity[0U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[1U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[2U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[3U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[4U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[5U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[6U] = 0U;
}
