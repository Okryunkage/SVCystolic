`timescale 1ns/1ps

module tb_convBRAM;

    localparam int TIMEOUT_CYCLES = 1000;

    logic clk   = 1'b0;
    logic rst   = 1'b1;
    logic start = 1'b0;

    logic [7:0] inData [0:0][0:2][0:2];
    logic signed [31:0] outData [0:1][0:2][0:2];

    logic busy;
    logic done;

    int signed expected0 [0:8];
    int signed expected1 [0:8];

    integer index;
    integer row;
    integer column;
    integer cycles;
    integer errors;
    logic busySeen;

    // Written only by the debug monitor.
    integer centerMacCount = 0;
    integer dbgTerm;
    integer dbgInputExpected;

    logic signed [7:0]  dbgW0;
    logic signed [7:0]  dbgW1;
    logic signed [31:0] dbgAcc0;
    logic signed [31:0] dbgAcc1;

    // 100 MHz clock.
    always #5 clk = ~clk;

    convBRAM #(
        .tile        (2),
        .inChannels  (1),
        .outChannels (2),
        .inHeight    (3),
        .inWidth     (3),
        .kernelH     (3),
        .kernelW     (3),
        .strideH     (1),
        .strideW     (1),
        .padH        (1),
        .padW        (1),
        .dataWidth   (8),
        .wWidth      (8),
        .bWidth      (8),
        .accWidth    (32),
        .inSigned    (1'b0),
        .wInitFile   ("tb_conv_w_tile.mem"),
        .bInitFile   ("tb_conv_b_tile.mem")
    ) dut (
        .clk     (clk),
        .rst     (rst),
        .start   (start),
        .inData  (inData),
        .busy    (busy),
        .done    (done),
        .outData (outData)
    );

    // ------------------------------------------------------------
    // Debug monitor for output position [1][1].
    //
    // No hierarchical enum references.
    // No access to the core's blocking-assignment temporary values.
    //
    // At posedge:
    //   Capture weight and accumulator values before NBA updates.
    // After #1:
    //   Observe the updated accumulator.
    // ------------------------------------------------------------
    initial begin
        forever begin
            @(posedge clk);

            if ((rst === 1'b0) &&
                (busy === 1'b1) &&
                (dut.core.weightValid[1] === 1'b1) &&
                (dut.core.outputRow == 1) &&
                (dut.core.outputColumn == 1)) begin

                dbgTerm          = int'(dut.core.consumeTerm);
                dbgInputExpected = dbgTerm + 1;
                dbgW0            = $signed(dut.core.wdata[0]);
                dbgW1            = $signed(dut.core.wdata[1]);
                dbgAcc0          = dut.core.accumulator[0];
                dbgAcc1          = dut.core.accumulator[1];

                centerMacCount = centerMacCount + 1;

                $display(
                    "MAC BEFORE term=%0d expected_input=%0d w0=%0d w1=%0d acc0=%0d acc1=%0d",
                    dbgTerm,
                    dbgInputExpected,
                    dbgW0,
                    dbgW1,
                    dbgAcc0,
                    dbgAcc1
                );

                // Allow nonblocking assignments to settle.
                #1;

                $display(
                    "MAC AFTER  term=%0d acc0=%0d acc1=%0d",
                    dbgTerm,
                    $signed(dut.core.accumulator[0]),
                    $signed(dut.core.accumulator[1])
                );

                if (dbgTerm == 8) begin
                    $display(
                        "FINAL ACC expected0=46 actual0=%0d expected1=9 actual1=%0d",
                        $signed(dut.core.accumulator[0]),
                        $signed(dut.core.accumulator[1])
                    );

                    // The next rising edge should execute
                    // WRITE_OUTPUT in the current core design.
                    @(posedge clk);
                    #1;

                    $display(
                        "CENTER OUTPUT expected0=46 actual0=%0d expected1=9 actual1=%0d",
                        $signed(outData[0][1][1]),
                        $signed(outData[1][1][1])
                    );
                end
            end
        end
    end

    // ------------------------------------------------------------
    // Main test.
    // ------------------------------------------------------------
    initial begin
        errors   = 0;
        cycles   = 0;
        busySeen = 1'b0;

        // Optional waveform recording.
        // Enable by passing +waves to the simulation executable.
        if ($test$plusargs("waves")) begin
            $dumpfile("tb_convBRAM.vcd");
            $dumpvars(0, tb_convBRAM);
        end

        // Input:
        // 1 2 3
        // 4 5 6
        // 7 8 9
        for (index = 0; index < 9; index = index + 1) begin
            row    = index / 3;
            column = index % 3;
            inData[0][row][column] = 8'(index + 1);
        end

        // Channel 0:
        // All nine weights are 1; bias is +1.
        expected0[0] = 13;
        expected0[1] = 22;
        expected0[2] = 17;
        expected0[3] = 28;
        expected0[4] = 46;
        expected0[5] = 34;
        expected0[6] = 25;
        expected0[7] = 40;
        expected0[8] = 29;

        // Channel 1:
        // Center weight is 2; all others are 0; bias is -1.
        for (index = 0; index < 9; index = index + 1)
            expected1[index] = 2 * (index + 1) - 1;

        $display("=== Convolution test started ===");
        $display("Input: 1 2 3 / 4 5 6 / 7 8 9");
        $display("Expected weights: ch0 all ones, ch1 center=2");
        $display("Expected biases: ch0=+1, ch1=-1");
        $display("Debug monitor: output position [1][1]");

        // Drive reset and start away from the DUT's sampling edge.
        repeat (3) @(negedge clk);
        rst = 1'b0;

        @(negedge clk);
        start = 1'b1;

        @(negedge clk);
        start = 1'b0;

        if (busy === 1'b1)
            busySeen = 1'b1;

        // Bounded completion wait.
        while ((done !== 1'b1) &&
               (cycles < TIMEOUT_CYCLES)) begin

            @(negedge clk);
            cycles = cycles + 1;

            if (busy === 1'b1)
                busySeen = 1'b1;
        end

        if (done !== 1'b1) begin
            $display(
                "TIMEOUT cycles=%0d busy=%b done=%b",
                cycles, busy, done
            );

            $display(
                "CORE tile=%0d row=%0d col=%0d issueTerm=%0d consumeTerm=%0d",
                dut.core.tileIndex,
                dut.core.outputRow,
                dut.core.outputColumn,
                dut.core.issueTerm,
                dut.core.consumeTerm
            );

            $display(
                "CORE issueDone=%b weightValid=%b",
                dut.core.issueDone,
                dut.core.weightValid
            );

            $fatal(1, "Timeout waiting for done.");
        end

        $display(
            "DONE cycles=%0d time=%0t",
            cycles, $time
        );

        if (busySeen !== 1'b1) begin
            $display("FAIL: busy was never observed high.");
            errors = errors + 1;
        end

        if (busy !== 1'b0) begin
            $display("FAIL: busy is not low at completion.");
            errors = errors + 1;
        end

        if (centerMacCount != 9) begin
            $display(
                "FAIL: center MAC count expected=9 actual=%0d",
                centerMacCount
            );
            errors = errors + 1;
        end

        // Print and check all 18 output values.
        for (index = 0; index < 9; index = index + 1) begin
            row    = index / 3;
            column = index % 3;

            if (outData[0][row][column] !== expected0[index]) begin
                $display(
                    "FAIL ch0 [%0d][%0d] expected=%0d actual=%0d hex=%h",
                    row,
                    column,
                    expected0[index],
                    $signed(outData[0][row][column]),
                    outData[0][row][column]
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "OK   ch0 [%0d][%0d] expected=%0d actual=%0d",
                    row,
                    column,
                    expected0[index],
                    $signed(outData[0][row][column])
                );
            end

            if (outData[1][row][column] !== expected1[index]) begin
                $display(
                    "FAIL ch1 [%0d][%0d] expected=%0d actual=%0d hex=%h",
                    row,
                    column,
                    expected1[index],
                    $signed(outData[1][row][column]),
                    outData[1][row][column]
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "OK   ch1 [%0d][%0d] expected=%0d actual=%0d",
                    row,
                    column,
                    expected1[index],
                    $signed(outData[1][row][column])
                );
            end
        end

        // Verify that done is a one-cycle pulse.
        @(negedge clk);

        if (done !== 1'b0) begin
            $display("FAIL: done did not return low.");
            errors = errors + 1;
        end

        if (busy !== 1'b0) begin
            $display("FAIL: busy did not remain low.");
            errors = errors + 1;
        end

        if (errors != 0) begin
            $display(
                "=== TEST FAILED: %0d error(s) ===",
                errors
            );
            $fatal(1, "See MAC and FAIL messages above.");
        end

        $display("=== PASS: all outputs and completion checks matched ===");
        $finish;
    end

endmodule