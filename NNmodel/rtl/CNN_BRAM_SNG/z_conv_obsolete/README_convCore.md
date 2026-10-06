# convCore: Convolution, Requantization, and Channel Masking

`convCore` computes convolution outputs in groups of `tile` channels.
Each accumulator is requantized and then either stored or replaced with zero
according to a channel mask. The `convBRAM` wrapper in `convTOP.sv` connects
the weight/bias memory and forwards the external mask to the core.

## Channel Mask Interface

```systemverilog
input logic [outChannels-1:0] channelMask;
logic [outChannels-1:0] channelMaskLatched;
```

Each bit controls one output channel, including all spatial positions in that
channel. A bit value of 1 keeps the requantized result; 0 drops the channel.
For example, `channelMask=4'b1011` keeps channels 0, 1, and 3 and drops channel 2.
Connect `channelMask` to `'1` to keep every channel; do not leave it unconnected.

The wrapper passes the mask directly to the core:

```systemverilog
.channelMask(channelMask)
```

### Mask Capture and Lifetime

Reset initializes `channelMaskLatched` to all ones. In `IDLE`, an accepted
`start` captures the external mask:

```systemverilog
channelMaskLatched <=channelMask;
```

Present a complete, stable mask before the rising clock edge that accepts start.
The saved mask remains unchanged throughout that convolution run, so changes to
the external input while the core is busy do not affect the current result.
A new mask is captured on the next start accepted in `IDLE`.
Reset initialization does not replace the need to supply a valid mask at start.

### Applying the Mask

In `WRITE_OUTPUT`, the global output-channel index is `tileIndex*tile+lane`:

```systemverilog
for(lane=0; lane<tile; lane++)begin
    if(channelMaskLatched[tileIndex*tile+lane])
        outData[tileIndex*tile+lane][outputRow][outputColumn]
            <=quantizedData[lane];
    else
        outData[tileIndex*tile+lane][outputRow][outputColumn] <='0;
end
```

For `tile=8`, `tileIndex=1`, and `lane=2`, this selects mask bit 10.
The mask is indexed by global channel, not reused from bit zero for each tile.
The current implementation assumes `outChannels` is divisible by `tile`, since
`numTile=outChannels/tile` and partial tiles are not handled.

Masking occurs as each computed pixel is written. It does not wait until the
entire feature map has been computed. The same saved mask is used for every
pixel, making the completed dropped channel all zeros.
Multiplications, accumulations, and memory accesses still take place for dropped
channels, so masking does not reduce the convolution cycle count.
Kept channels are not rescaled by a probability-dependent factor.

## Requantization Data Path

Requantization uses unpacked lane arrays directly:

```systemverilog
logic signed[accWidth-1:0] accumulator[0:tile-1];
wire[actWidth-1:0] quantizedData[0:tile-1];

requantUsign#(
    .number(tile),.inWidth(accWidth),
    .outWidth(actWidth),.shift(requantShift))
u_requant(
    .inData(accumulator),.outData(quantizedData));
```

There is no intermediate flat-vector packing. Each array element is one lane
at the current output pixel. `requantUsign` applies nonnegative clipping,
rounding/right-shifting for the usual positive `requantShift`, and unsigned
saturation before the channel mask selects the stored value.
The requantizer is combinational and does not introduce an extra FSM state.

```mermaid
flowchart LR
    ACC["accumulator[lane]"] --> REQ["requantUsign"]
    REQ --> DATA["quantizedData[lane]"]
    DATA --> SELECT{"Saved mask bit for this channel?"}
    MASK["channelMaskLatched[tileIndex*tile+lane]"] --> SELECT
    SELECT -->|1| KEEP["Store quantizedData[lane]"]
    SELECT -->|0| DROP["Store zero"]
    KEEP --> OUT["outData[channel][outputRow][outputColumn]"]
    DROP --> OUT
```

## SNG Integration Boundary

The core receives a complete `channelMask`; it does not receive or sample
`random_bit` / `random_valid` directly. An external mask-generation controller
still needs to collect SNG samples into one bit per output channel and start
the convolution only after the complete mask is ready.

If an SNG bit of 1 means keep, store it directly in the mask. If it means drop,
invert it first. This distinction determines whether the SNG's probability of
outputting 1 is the keep probability or the drop probability.
Using a different sample for each channel allows different channel decisions;
replicating one bit across the mask makes all channels share one decision.

## Same input image, different filters

The example below uses `tile=8` and `outChannels=32`. Each group is subject to
its corresponding saved mask bits.

```mermaid
flowchart TD
    I["Input image held constant<br/>1 channel × 28 × 28"]
    T0["tileIndex = 0<br/>Apply filters 0–7"]
    T1["tileIndex = 1<br/>Apply filters 8–15"]
    T2["tileIndex = 2<br/>Apply filters 16–23"]
    T3["tileIndex = 3<br/>Apply filters 24–31"]
    O0["Output channels 0–7<br/>28 × 28 each"]
    O1["Output channels 8–15<br/>28 × 28 each"]
    O2["Output channels 16–23<br/>28 × 28 each"]
    O3["Output channels 24–31<br/>28 × 28 each"]

    I --> T0 --> O0
    I --> T1 --> O1
    I --> T2 --> O2
    I --> T3 --> O3
```

## Complete FSM

```mermaid
flowchart TD
    RESET["rst = 1<br/>Asynchronous reset from any state<br/>state ← IDLE, busy ← 0, done ← 0<br/>channelMaskLatched ← all ones"]

    IDLE["IDLE<br/>busy ← 0"]
    START{"start == 1?"}

    RESET --> IDLE
    IDLE --> START
    START -->|"No: start == 0"| IDLE
    START -->|"Yes<br/>busy ← 1<br/>channelMaskLatched ← channelMask<br/>tileIndex ← 0<br/>outputRow ← 0, outputColumn ← 0<br/>weightBaseAddress ← 0, baddr ← 0"| BREQ

    BREQ["BIAS_REQ<br/>baddr ← tileIndex"]
    BW0["BIAS_WAIT0"]
    BW1["BIAS_WAIT1"]
    BLOAD["BIAS_LOAD<br/>Load sign-extended bias<br/>into biasValue for each lane"]
    PINIT["PIXEL_INIT<br/>Each accumulator ← biasValue<br/>issueTerm ← 0, consumeTerm ← 0<br/>weightValid ← 00, issueDone ← 0"]

    BREQ -->|"Unconditional · next cycle"| BW0
    BW0 -->|"Unconditional · next cycle"| BW1
    BW1 -->|"Unconditional · next cycle"| BLOAD
    BLOAD -->|"Unconditional · next cycle"| PINIT
    PINIT -->|"Unconditional · next cycle"| WRUN

    WRUN["WEIGHT_RUN<br/>Advance the weight-request pipeline<br/>Accumulate when weightValid bit 1 is set"]

    LASTTERM{"weightValid[1] == 1<br/>AND<br/>consumeTerm == kernelTerms - 1?"}

    WRUN --> LASTTERM
    LASTTERM -->|"No<br/>Final valid term has not been consumed"| WRUN
    LASTTERM -->|"Yes<br/>Accumulate the final term<br/>weightValid ← 00"| WRITE

    WRITE["WRITE_OUTPUT<br/>For each lane, use its global channel mask bit<br/>1: store quantizedData[lane]<br/>0: store zero<br/>at the current tile, row, and column"]

    COL{"outputColumn != outWidth - 1?"}
    ROW{"outputRow != outHeight - 1?"}
    TILE{"tileIndex != numTile - 1?"}

    WRITE --> COL
    COL -->|"True: another column remains<br/>outputColumn ← outputColumn + 1"| PINIT
    COL -->|"False: last column"| ROW

    ROW -->|"True: another row remains<br/>outputColumn ← 0<br/>outputRow ← outputRow + 1"| PINIT
    ROW -->|"False: last row"| TILE

    TILE -->|"True: another tile remains<br/>tileIndex ← tileIndex + 1<br/>outputRow ← 0, outputColumn ← 0<br/>weightBaseAddress ← weightBaseAddress + kernelTerms<br/>baddr ← tileIndex + 1"| BREQ

    TILE -->|"False: final tile completed<br/>busy ← 0, done ← 1"| IDLE
```

## The pipeline runs inside <WEIGHT_RUN>

```mermaid
flowchart TD
    RUN["Every clock in WEIGHT_RUN<br/>Shift weightValid:<br/>bit 1 ← previous bit 0<br/>bit 0 ← !issueDone"]

    RUN --> ISSUE{"issueDone == 0?"}
    ISSUE -->|"No"| NOREQ["No new valid request<br/>Outstanding results can still be consumed"]
    ISSUE -->|"Yes"| REQ["Issue a valid weight read<br/>waddr = weightBaseAddress + issueTerm"]

    REQ --> ILAST{"issueTerm == kernelTerms - 1?"}
    ILAST -->|"No"| INEXT["issueTerm ← issueTerm + 1"]
    ILAST -->|"Yes"| IDONE["issueDone ← 1<br/>Stop issuing valid requests<br/>starting next cycle"]

    RUN --> VALID{"Previous weightValid[1] == 1?"}
    VALID -->|"No"| WAIT["No accumulation<br/>Remain in WEIGHT_RUN"]
    VALID -->|"Yes"| MAC["Select input pixel using consumeTerm<br/>Multiply and accumulate in tile lanes"]

    MAC --> CLAST{"consumeTerm == kernelTerms - 1?"}
    CLAST -->|"No"| CNEXT["consumeTerm ← consumeTerm + 1<br/>Remain in WEIGHT_RUN"]
    CLAST -->|"Yes"| FINISH["weightValid ← 00<br/>Next state ← WRITE_OUTPUT"]
```
