// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb_convBRAM.h for the primary calling header

#include "Vtb_convBRAM__pch.h"
#include "Vtb_convBRAM__Syms.h"
#include "Vtb_convBRAM___024root.h"

VL_INLINE_OPT VlCoroutine Vtb_convBRAM___024root___eval_initial__TOP__Vtiming__0(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_initial__TOP__Vtiming__0\n"); );
    // Body
    vlSelf->tb_convBRAM__DOT__expected0[0U] = 0xdU;
    vlSelf->tb_convBRAM__DOT__expected0[1U] = 0x16U;
    vlSelf->tb_convBRAM__DOT__expected0[2U] = 0x11U;
    vlSelf->tb_convBRAM__DOT__expected0[3U] = 0x1cU;
    vlSelf->tb_convBRAM__DOT__expected0[4U] = 0x2eU;
    vlSelf->tb_convBRAM__DOT__expected0[5U] = 0x22U;
    vlSelf->tb_convBRAM__DOT__expected0[6U] = 0x19U;
    vlSelf->tb_convBRAM__DOT__expected0[7U] = 0x28U;
    vlSelf->tb_convBRAM__DOT__expected0[8U] = 0x1dU;
    vlSelf->tb_convBRAM__DOT__inData[0U][0U][0U] = 1U;
    vlSelf->tb_convBRAM__DOT__inData[0U][0U][1U] = 2U;
    vlSelf->tb_convBRAM__DOT__inData[0U][0U][2U] = 3U;
    vlSelf->tb_convBRAM__DOT__inData[0U][1U][0U] = 4U;
    vlSelf->tb_convBRAM__DOT__inData[0U][1U][1U] = 5U;
    vlSelf->tb_convBRAM__DOT__inData[0U][1U][2U] = 6U;
    vlSelf->tb_convBRAM__DOT__inData[0U][2U][0U] = 7U;
    vlSelf->tb_convBRAM__DOT__inData[0U][2U][1U] = 8U;
    vlSelf->tb_convBRAM__DOT__row = 2U;
    vlSelf->tb_convBRAM__DOT__column = 2U;
    vlSelf->tb_convBRAM__DOT__inData[0U][2U][2U] = 9U;
    vlSelf->tb_convBRAM__DOT__index = 9U;
    co_await vlSelf->__VtrigSched_h52bcd072__0.trigger(0U, 
                                                       nullptr, 
                                                       "@(posedge tb_convBRAM.clk)", 
                                                       "/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 
                                                       45);
    vlSelf->__Vm_traceActivity[2U] = 1U;
    co_await vlSelf->__VtrigSched_h52bcd072__0.trigger(0U, 
                                                       nullptr, 
                                                       "@(posedge tb_convBRAM.clk)", 
                                                       "/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 
                                                       45);
    vlSelf->__Vm_traceActivity[2U] = 1U;
    co_await vlSelf->__VtrigSched_h52bcd072__0.trigger(0U, 
                                                       nullptr, 
                                                       "@(posedge tb_convBRAM.clk)", 
                                                       "/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 
                                                       45);
    vlSelf->__Vm_traceActivity[2U] = 1U;
    vlSelf->tb_convBRAM__DOT__rst = 0U;
    co_await vlSelf->__VtrigSched_h52bcd072__0.trigger(0U, 
                                                       nullptr, 
                                                       "@(posedge tb_convBRAM.clk)", 
                                                       "/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 
                                                       47);
    vlSelf->__Vm_traceActivity[2U] = 1U;
    vlSelf->tb_convBRAM__DOT__start = 1U;
    co_await vlSelf->__VtrigSched_h52bcd072__0.trigger(0U, 
                                                       nullptr, 
                                                       "@(posedge tb_convBRAM.clk)", 
                                                       "/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 
                                                       48);
    vlSelf->__Vm_traceActivity[2U] = 1U;
    vlSelf->tb_convBRAM__DOT__start = 0U;
    while ((1U & (~ (IData)(vlSelf->tb_convBRAM__DOT__done)))) {
        co_await vlSelf->__VtrigSched_hba22dc0b__0.trigger(1U, 
                                                           nullptr, 
                                                           "@([changed] tb_convBRAM.done)", 
                                                           "/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 
                                                           49);
        vlSelf->__Vm_traceActivity[2U] = 1U;
    }
    co_await vlSelf->__VdlySched.delay(0x3e8ULL, nullptr, 
                                       "/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 
                                       50);
    vlSelf->__Vm_traceActivity[2U] = 1U;
    vlSelf->tb_convBRAM__DOT__row = 0U;
    vlSelf->tb_convBRAM__DOT__column = 0U;
    if (VL_UNLIKELY((((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U) != vlSelf->tb_convBRAM__DOT__expected0
                     [0U]))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:55: Assertion failed in %Ntb_convBRAM: ch0 [%0d][%0d] expected=%0d actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,vlSelf->tb_convBRAM__DOT__expected0
                  [0U],32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                            ? vlSelf->tb_convBRAM__DOT__outData
                           [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                  ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                  : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                            : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 55, "");
    }
    if (VL_UNLIKELY((1U != ((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                             ? vlSelf->tb_convBRAM__DOT__outData
                            [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                   ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                   : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                             : 0U)))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:58: Assertion failed in %Ntb_convBRAM: ch1 [%0d][%0d] expected=1 actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 58, "");
    }
    vlSelf->tb_convBRAM__DOT__index = 1U;
    vlSelf->tb_convBRAM__DOT__row = 0U;
    vlSelf->tb_convBRAM__DOT__column = 1U;
    if (VL_UNLIKELY((((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U) != vlSelf->tb_convBRAM__DOT__expected0
                     [1U]))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:55: Assertion failed in %Ntb_convBRAM: ch0 [%0d][%0d] expected=%0d actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,vlSelf->tb_convBRAM__DOT__expected0
                  [1U],32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                            ? vlSelf->tb_convBRAM__DOT__outData
                           [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                  ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                  : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                            : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 55, "");
    }
    if (VL_UNLIKELY((3U != ((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                             ? vlSelf->tb_convBRAM__DOT__outData
                            [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                   ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                   : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                             : 0U)))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:58: Assertion failed in %Ntb_convBRAM: ch1 [%0d][%0d] expected=3 actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 58, "");
    }
    vlSelf->tb_convBRAM__DOT__index = 2U;
    vlSelf->tb_convBRAM__DOT__row = 0U;
    vlSelf->tb_convBRAM__DOT__column = 2U;
    if (VL_UNLIKELY((((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U) != vlSelf->tb_convBRAM__DOT__expected0
                     [2U]))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:55: Assertion failed in %Ntb_convBRAM: ch0 [%0d][%0d] expected=%0d actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,vlSelf->tb_convBRAM__DOT__expected0
                  [2U],32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                            ? vlSelf->tb_convBRAM__DOT__outData
                           [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                  ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                  : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                            : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 55, "");
    }
    if (VL_UNLIKELY((5U != ((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                             ? vlSelf->tb_convBRAM__DOT__outData
                            [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                   ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                   : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                             : 0U)))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:58: Assertion failed in %Ntb_convBRAM: ch1 [%0d][%0d] expected=5 actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 58, "");
    }
    vlSelf->tb_convBRAM__DOT__index = 3U;
    vlSelf->tb_convBRAM__DOT__row = 1U;
    vlSelf->tb_convBRAM__DOT__column = 0U;
    if (VL_UNLIKELY((((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U) != vlSelf->tb_convBRAM__DOT__expected0
                     [3U]))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:55: Assertion failed in %Ntb_convBRAM: ch0 [%0d][%0d] expected=%0d actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,vlSelf->tb_convBRAM__DOT__expected0
                  [3U],32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                            ? vlSelf->tb_convBRAM__DOT__outData
                           [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                  ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                  : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                            : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 55, "");
    }
    if (VL_UNLIKELY((7U != ((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                             ? vlSelf->tb_convBRAM__DOT__outData
                            [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                   ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                   : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                             : 0U)))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:58: Assertion failed in %Ntb_convBRAM: ch1 [%0d][%0d] expected=7 actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 58, "");
    }
    vlSelf->tb_convBRAM__DOT__index = 4U;
    vlSelf->tb_convBRAM__DOT__row = 1U;
    vlSelf->tb_convBRAM__DOT__column = 1U;
    if (VL_UNLIKELY((((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U) != vlSelf->tb_convBRAM__DOT__expected0
                     [4U]))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:55: Assertion failed in %Ntb_convBRAM: ch0 [%0d][%0d] expected=%0d actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,vlSelf->tb_convBRAM__DOT__expected0
                  [4U],32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                            ? vlSelf->tb_convBRAM__DOT__outData
                           [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                  ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                  : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                            : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 55, "");
    }
    if (VL_UNLIKELY((9U != ((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                             ? vlSelf->tb_convBRAM__DOT__outData
                            [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                   ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                   : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                             : 0U)))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:58: Assertion failed in %Ntb_convBRAM: ch1 [%0d][%0d] expected=9 actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 58, "");
    }
    vlSelf->tb_convBRAM__DOT__index = 5U;
    vlSelf->tb_convBRAM__DOT__row = 1U;
    vlSelf->tb_convBRAM__DOT__column = 2U;
    if (VL_UNLIKELY((((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U) != vlSelf->tb_convBRAM__DOT__expected0
                     [5U]))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:55: Assertion failed in %Ntb_convBRAM: ch0 [%0d][%0d] expected=%0d actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,vlSelf->tb_convBRAM__DOT__expected0
                  [5U],32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                            ? vlSelf->tb_convBRAM__DOT__outData
                           [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                  ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                  : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                            : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 55, "");
    }
    if (VL_UNLIKELY((0xbU != ((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                               ? vlSelf->tb_convBRAM__DOT__outData
                              [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                     ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                     : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                               : 0U)))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:58: Assertion failed in %Ntb_convBRAM: ch1 [%0d][%0d] expected=11 actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 58, "");
    }
    vlSelf->tb_convBRAM__DOT__index = 6U;
    vlSelf->tb_convBRAM__DOT__row = 2U;
    vlSelf->tb_convBRAM__DOT__column = 0U;
    if (VL_UNLIKELY((((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U) != vlSelf->tb_convBRAM__DOT__expected0
                     [6U]))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:55: Assertion failed in %Ntb_convBRAM: ch0 [%0d][%0d] expected=%0d actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,vlSelf->tb_convBRAM__DOT__expected0
                  [6U],32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                            ? vlSelf->tb_convBRAM__DOT__outData
                           [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                  ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                  : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                            : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 55, "");
    }
    if (VL_UNLIKELY((0xdU != ((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                               ? vlSelf->tb_convBRAM__DOT__outData
                              [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                     ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                     : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                               : 0U)))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:58: Assertion failed in %Ntb_convBRAM: ch1 [%0d][%0d] expected=13 actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 58, "");
    }
    vlSelf->tb_convBRAM__DOT__index = 7U;
    vlSelf->tb_convBRAM__DOT__row = 2U;
    vlSelf->tb_convBRAM__DOT__column = 1U;
    if (VL_UNLIKELY((((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U) != vlSelf->tb_convBRAM__DOT__expected0
                     [7U]))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:55: Assertion failed in %Ntb_convBRAM: ch0 [%0d][%0d] expected=%0d actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,vlSelf->tb_convBRAM__DOT__expected0
                  [7U],32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                            ? vlSelf->tb_convBRAM__DOT__outData
                           [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                  ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                  : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                            : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 55, "");
    }
    if (VL_UNLIKELY((0xfU != ((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                               ? vlSelf->tb_convBRAM__DOT__outData
                              [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                     ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                     : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                               : 0U)))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:58: Assertion failed in %Ntb_convBRAM: ch1 [%0d][%0d] expected=15 actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 58, "");
    }
    vlSelf->tb_convBRAM__DOT__index = 8U;
    vlSelf->tb_convBRAM__DOT__row = 2U;
    vlSelf->tb_convBRAM__DOT__column = 2U;
    if (VL_UNLIKELY((((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U) != vlSelf->tb_convBRAM__DOT__expected0
                     [8U]))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:55: Assertion failed in %Ntb_convBRAM: ch0 [%0d][%0d] expected=%0d actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,vlSelf->tb_convBRAM__DOT__expected0
                  [8U],32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                            ? vlSelf->tb_convBRAM__DOT__outData
                           [0U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                  ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                  : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                            : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 55, "");
    }
    if (VL_UNLIKELY((0x11U != ((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                                ? vlSelf->tb_convBRAM__DOT__outData
                               [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                                      ? (3U & vlSelf->tb_convBRAM__DOT__row)
                                      : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                                : 0U)))) {
        VL_WRITEF("[%0t] %%Fatal: tb_convBRAM.sv:58: Assertion failed in %Ntb_convBRAM: ch1 [%0d][%0d] expected=17 actual=%0d\n",
                  64,VL_TIME_UNITED_Q(1000),-9,vlSymsp->name(),
                  32,vlSelf->tb_convBRAM__DOT__row,
                  32,vlSelf->tb_convBRAM__DOT__column,
                  32,((2U >= (3U & vlSelf->tb_convBRAM__DOT__column))
                       ? vlSelf->tb_convBRAM__DOT__outData
                      [1U][((2U >= (3U & vlSelf->tb_convBRAM__DOT__row))
                             ? (3U & vlSelf->tb_convBRAM__DOT__row)
                             : 0U)][(3U & vlSelf->tb_convBRAM__DOT__column)]
                       : 0U));
        VL_STOP_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 58, "");
    }
    vlSelf->tb_convBRAM__DOT__index = 9U;
    VL_WRITEF("PASS: XPM BRAM initialization, lane packing, latency and convolution\n");
    VL_FINISH_MT("/home/okryunkage/okryun0/NNmodel/testbench/CNN/tb_convBRAM.sv", 62, "");
    vlSelf->__Vm_traceActivity[2U] = 1U;
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb_convBRAM___024root___dump_triggers__act(Vtb_convBRAM___024root* vlSelf);
#endif  // VL_DEBUG

void Vtb_convBRAM___024root___eval_triggers__act(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_triggers__act\n"); );
    // Body
    vlSelf->__VactTriggered.set(0U, ((IData)(vlSelf->tb_convBRAM__DOT__clk) 
                                     & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__clk__0))));
    vlSelf->__VactTriggered.set(1U, (((IData)(vlSelf->tb_convBRAM__DOT__clk) 
                                      & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__clk__0))) 
                                     | ((IData)(vlSelf->tb_convBRAM__DOT__rst) 
                                        & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__rst__0)))));
    vlSelf->__VactTriggered.set(2U, ((IData)(vlSelf->tb_convBRAM__DOT__done) 
                                     != (IData)(vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__done__0)));
    vlSelf->__VactTriggered.set(3U, vlSelf->__VdlySched.awaitingCurrentTime());
    vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__clk__0 
        = vlSelf->tb_convBRAM__DOT__clk;
    vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__rst__0 
        = vlSelf->tb_convBRAM__DOT__rst;
    vlSelf->__Vtrigprevexpr___TOP__tb_convBRAM__DOT__done__0 
        = vlSelf->tb_convBRAM__DOT__done;
    if (VL_UNLIKELY((1U & (~ (IData)(vlSelf->__VactDidInit))))) {
        vlSelf->__VactDidInit = 1U;
        vlSelf->__VactTriggered.set(2U, 1U);
    }
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb_convBRAM___024root___dump_triggers__act(vlSelf);
    }
#endif
}

void Vtb_convBRAM___024root____Vthread__nba__0(void* voidSelf, bool even_cycle);
void Vtb_convBRAM___024root____Vthread__nba__1(void* voidSelf, bool even_cycle);
void Vtb_convBRAM___024root____Vthread__nba__2(void* voidSelf, bool even_cycle);
void Vtb_convBRAM___024root____Vthread__nba__3(void* voidSelf, bool even_cycle);
void Vtb_convBRAM___024root____Vthread__nba__4(void* voidSelf, bool even_cycle);
void Vtb_convBRAM___024root____Vthread__nba__5(void* voidSelf, bool even_cycle);
void Vtb_convBRAM___024root____Vthread__nba__6(void* voidSelf, bool even_cycle);
void Vtb_convBRAM___024root____Vthread__nba__7(void* voidSelf, bool even_cycle);

void Vtb_convBRAM___024root___eval_nba(Vtb_convBRAM___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root___eval_nba\n"); );
    // Body
    vlSymsp->__Vm_even_cycle__nba = !vlSymsp->__Vm_even_cycle__nba;
    vlSymsp->__Vm_threadPoolp->workerp(0)->addTask(&Vtb_convBRAM___024root____Vthread__nba__0, vlSelf, vlSymsp->__Vm_even_cycle__nba);
    vlSymsp->__Vm_threadPoolp->workerp(1)->addTask(&Vtb_convBRAM___024root____Vthread__nba__1, vlSelf, vlSymsp->__Vm_even_cycle__nba);
    vlSymsp->__Vm_threadPoolp->workerp(2)->addTask(&Vtb_convBRAM___024root____Vthread__nba__2, vlSelf, vlSymsp->__Vm_even_cycle__nba);
    vlSymsp->__Vm_threadPoolp->workerp(3)->addTask(&Vtb_convBRAM___024root____Vthread__nba__3, vlSelf, vlSymsp->__Vm_even_cycle__nba);
    vlSymsp->__Vm_threadPoolp->workerp(4)->addTask(&Vtb_convBRAM___024root____Vthread__nba__4, vlSelf, vlSymsp->__Vm_even_cycle__nba);
    vlSymsp->__Vm_threadPoolp->workerp(5)->addTask(&Vtb_convBRAM___024root____Vthread__nba__5, vlSelf, vlSymsp->__Vm_even_cycle__nba);
    vlSymsp->__Vm_threadPoolp->workerp(6)->addTask(&Vtb_convBRAM___024root____Vthread__nba__6, vlSelf, vlSymsp->__Vm_even_cycle__nba);
    Vtb_convBRAM___024root____Vthread__nba__7(vlSelf, vlSymsp->__Vm_even_cycle__nba);
    Verilated::mtaskId(0);
    vlSelf->__Vm_mtaskstate_final__nba.waitUntilUpstreamDone(vlSymsp->__Vm_even_cycle__nba);
}

void Vtb_convBRAM___024root___nba_sequent__TOP__18(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__25(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__19(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__50(Vtb_convBRAM___024root* vlSelf);

void Vtb_convBRAM___024root____Vthread__nba__0(void* voidSelf, bool even_cycle) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root____Vthread__nba__0\n"); );
    // Body
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Verilated::mtaskId(20);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__18(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    Verilated::mtaskId(27);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__25(vlSelf);
        vlSelf->__Vm_traceActivity[4U] = 1U;
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(21);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__19(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_43.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(43);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__50(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_final__nba.signalUpstreamDone(even_cycle);
}

void Vtb_convBRAM___024root___nba_sequent__TOP__0(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__9(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__21(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__38(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__30(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__33(Vtb_convBRAM___024root* vlSelf);

void Vtb_convBRAM___024root____Vthread__nba__1(void* voidSelf, bool even_cycle) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root____Vthread__nba__1\n"); );
    // Body
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Verilated::mtaskId(2);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__0(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(11);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__9(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(23);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__21(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_47.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_41.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(41);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__38(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_47.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_32.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(32);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__30(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_35.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(35);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__33(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_final__nba.signalUpstreamDone(even_cycle);
}

void Vtb_convBRAM___024root___nba_sequent__TOP__1(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__10(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__20(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__27(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__51(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__29(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__42(Vtb_convBRAM___024root* vlSelf);

void Vtb_convBRAM___024root____Vthread__nba__2(void* voidSelf, bool even_cycle) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root____Vthread__nba__2\n"); );
    // Body
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Verilated::mtaskId(3);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__1(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    Verilated::mtaskId(12);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__10(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    Verilated::mtaskId(22);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__20(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(29);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__27(vlSelf);
        vlSelf->__Vm_traceActivity[5U] = 1U;
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_30.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_32.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_33.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_34.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_35.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_39.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_41.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_42.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_49.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_48.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_40.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_43.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(44);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__51(vlSelf);
        vlSelf->__Vm_traceActivity[6U] = 1U;
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    Verilated::mtaskId(31);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__29(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_47.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(47);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__42(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_final__nba.signalUpstreamDone(even_cycle);
}

void Vtb_convBRAM___024root___nba_sequent__TOP__2(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__7(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__14(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__39(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__31(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__37(Vtb_convBRAM___024root* vlSelf);

void Vtb_convBRAM___024root____Vthread__nba__3(void* voidSelf, bool even_cycle) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root____Vthread__nba__3\n"); );
    // Body
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Verilated::mtaskId(4);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__2(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(9);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__7(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(16);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__14(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_42.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(42);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__39(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_47.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_33.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(33);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__31(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_39.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(39);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__37(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_final__nba.signalUpstreamDone(even_cycle);
}

void Vtb_convBRAM___024root___nba_sequent__TOP__3(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__8(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__15(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__43(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__48(Vtb_convBRAM___024root* vlSelf);

void Vtb_convBRAM___024root____Vthread__nba__4(void* voidSelf, bool even_cycle) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root____Vthread__nba__4\n"); );
    // Body
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Verilated::mtaskId(5);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__3(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(10);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__8(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(17);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__15(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_48.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(48);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__43(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_53.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(53);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__48(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_final__nba.signalUpstreamDone(even_cycle);
}

void Vtb_convBRAM___024root___nba_sequent__TOP__4(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__11(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__16(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__44(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__47(Vtb_convBRAM___024root* vlSelf);

void Vtb_convBRAM___024root____Vthread__nba__5(void* voidSelf, bool even_cycle) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root____Vthread__nba__5\n"); );
    // Body
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Verilated::mtaskId(6);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__4(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(13);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__11(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(18);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__16(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_49.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(49);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__44(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    Verilated::mtaskId(52);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__47(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_final__nba.signalUpstreamDone(even_cycle);
}

void Vtb_convBRAM___024root___nba_sequent__TOP__5(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__12(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__17(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__49(Vtb_convBRAM___024root* vlSelf);

void Vtb_convBRAM___024root____Vthread__nba__6(void* voidSelf, bool even_cycle) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root____Vthread__nba__6\n"); );
    // Body
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Verilated::mtaskId(7);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__5(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(14);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__12(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(19);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__17(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_40.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(40);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__49(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_final__nba.signalUpstreamDone(even_cycle);
}

void Vtb_convBRAM___024root___nba_sequent__TOP__6(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__13(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__24(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__28(Vtb_convBRAM___024root* vlSelf);
void Vtb_convBRAM___024root___nba_sequent__TOP__32(Vtb_convBRAM___024root* vlSelf);

void Vtb_convBRAM___024root____Vthread__nba__7(void* voidSelf, bool even_cycle) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb_convBRAM___024root____Vthread__nba__7\n"); );
    // Body
    Vtb_convBRAM___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb_convBRAM___024root*>(voidSelf);
    Vtb_convBRAM__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    Verilated::mtaskId(8);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__6(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(15);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__13(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_29.signalUpstreamDone(even_cycle);
    Verilated::mtaskId(26);
    if ((1ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__24(vlSelf);
        vlSelf->__Vm_traceActivity[3U] = 1U;
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_47.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_53.signalUpstreamDone(even_cycle);
    vlSelf->__Vm_mtaskstate_30.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(30);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__28(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_34.waitUntilUpstreamDone(even_cycle);
    Verilated::mtaskId(34);
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vtb_convBRAM___024root___nba_sequent__TOP__32(vlSelf);
    }
    Verilated::endOfThreadMTask(vlSymsp->__Vm_evalMsgQp);
    vlSelf->__Vm_mtaskstate_final__nba.signalUpstreamDone(even_cycle);
}
