`timescale 1ns / 1ps

module uartPacketDec#(
	parameter [7:0] SOF0              =8'hAA,
	parameter [7:0] SOF1              =8'h55,
	parameter [7:0] EXPECTED_VERSION  =8'd1,
	parameter [7:0] FLAG_INCLUDE_LABEL =8'h01,
	parameter       CHECK_PAYLOAD_LEN =1)(
	
	input  wire        clk,
	input  wire        rst_n,
	input  wire        rx_valid,
	input  wire [7:0]  rx_data,

	output reg         header_valid,
	output reg  [7:0]  version,
	output reg  [7:0]  flags,
	output reg  [31:0] batch_id,
	output reg  [15:0] batch_size,
	output reg  [15:0] vector_len,
	output reg  [31:0] payload_len,

	output reg         payload_valid,
	output reg  [7:0]  payload_data,
	output reg  [31:0] payload_index,
	output reg         payload_is_label,

	output reg         packet_done,
	output reg         packet_error,
	output reg         checksum_error,
	output reg         header_error,

	output reg  [7:0]  received_checksum,
	output reg  [7:0]  computed_checksum,

	output wire        busy);

	localparam [2:0] ST_WAIT_SOF0  =3'd0;
	localparam [2:0] ST_WAIT_SOF1  =3'd1;
	localparam [2:0] ST_HEADER     =3'd2;
	localparam [2:0] ST_PAYLOAD    =3'd3;
	localparam [2:0] ST_CHECKSUM   =3'd4;

	localparam [3:0] HEADER_BYTES  =4'd14;

	reg [2:0]  state;
	reg [3:0]  header_count;
	reg [31:0] payload_count;

	reg [7:0]  checksum_acc;

	reg [31:0] image_byte_count;
	reg [31:0] expected_payload_len;

	wire [31:0] image_byte_count_calc;
	wire [31:0] expected_payload_len_calc;
	wire [31:0] payload_len_with_current;

	assign busy =(state !=ST_WAIT_SOF0);

	// batch_size * vector_len
	// For MNIST, this is usually batch_size * 784.
	assign image_byte_count_calc =
		{16'd0, batch_size} * {16'd0, vector_len};

	assign expected_payload_len_calc =
		image_byte_count_calc +
		((flags & FLAG_INCLUDE_LABEL) ? {16'd0, batch_size} : 32'd0);

	// Used when receiving the last byte of payload_len.
	// payload_len is little-endian:
	// byte 10 -> payload_len[7:0]
	// byte 11 -> payload_len[15:8]
	// byte 12 -> payload_len[23:16]
	// byte 13 -> payload_len[31:24]
	assign payload_len_with_current ={rx_data, payload_len[23:0]};

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			state             <=ST_WAIT_SOF0;
			header_count      <=4'd0;
			payload_count     <=32'd0;

			checksum_acc      <=8'd0;

			header_valid      <=1'b0;
			version           <=8'd0;
			flags             <=8'd0;
			batch_id          <=32'd0;
			batch_size        <=16'd0;
			vector_len        <=16'd0;
			payload_len       <=32'd0;

			payload_valid     <=1'b0;
			payload_data      <=8'd0;
			payload_index     <=32'd0;
			payload_is_label  <=1'b0;

			packet_done       <=1'b0;
			packet_error      <=1'b0;
			checksum_error    <=1'b0;
			header_error      <=1'b0;

			received_checksum <=8'd0;
			computed_checksum <=8'd0;

			image_byte_count  <=32'd0;
			expected_payload_len <=32'd0;
		end else begin
			// Default pulse outputs
			header_valid     <=1'b0;
			payload_valid    <=1'b0;
			packet_done      <=1'b0;
			packet_error     <=1'b0;
			checksum_error   <=1'b0;
			header_error     <=1'b0;

			if (rx_valid) begin
				case (state)

					// Wait for first SOF byte: 0xAA
					ST_WAIT_SOF0: begin
						if (rx_data ==SOF0) begin
							state <=ST_WAIT_SOF1;
						end
					end

					// Wait for second SOF byte: 0x55
					ST_WAIT_SOF1: begin
						if (rx_data ==SOF1) begin
							state             <=ST_HEADER;
							header_count      <=4'd0;
							payload_count     <=32'd0;
							checksum_acc      <=8'd0;

							version           <=8'd0;
							flags             <=8'd0;
							batch_id          <=32'd0;
							batch_size        <=16'd0;
							vector_len        <=16'd0;
							payload_len       <=32'd0;
							image_byte_count  <=32'd0;
							expected_payload_len <=32'd0;
						end else if (rx_data ==SOF0) begin
							// If another 0xAA arrives, stay here.
							// This helps detect sequences like AA AA 55.
							state <=ST_WAIT_SOF1;
						end else begin
							state <=ST_WAIT_SOF0;
						end
					end

					// Read 14-byte header
					ST_HEADER: begin
						checksum_acc <=checksum_acc + rx_data;

						case (header_count)
							4'd0:  version          <=rx_data;
							4'd1:  flags            <=rx_data;

							4'd2:  batch_id[7:0]    <=rx_data;
							4'd3:  batch_id[15:8]   <=rx_data;
							4'd4:  batch_id[23:16]  <=rx_data;
							4'd5:  batch_id[31:24]  <=rx_data;

							4'd6:  batch_size[7:0]  <=rx_data;
							4'd7:  batch_size[15:8] <=rx_data;

							4'd8:  vector_len[7:0]  <=rx_data;
							4'd9:  vector_len[15:8] <=rx_data;

							4'd10: payload_len[7:0]   <=rx_data;
							4'd11: payload_len[15:8]  <=rx_data;
							4'd12: payload_len[23:16] <=rx_data;
							4'd13: payload_len[31:24] <=rx_data;

							default: ;
						endcase

						if (header_count ==HEADER_BYTES - 1) begin
							header_valid <=1'b1;

							image_byte_count     <=image_byte_count_calc;
							expected_payload_len <=expected_payload_len_calc;

							// Header checks
							if (version !=EXPECTED_VERSION) begin
								header_error <=1'b1;
								packet_error <=1'b1;
								state        <=ST_WAIT_SOF0;
							end else if ((flags & ~FLAG_INCLUDE_LABEL) !=8'd0) begin
								// Only bit0 is currently defined.
								header_error <=1'b1;
								packet_error <=1'b1;
								state        <=ST_WAIT_SOF0;
							end else if (
								CHECK_PAYLOAD_LEN &&
								(payload_len_with_current !=expected_payload_len_calc)
							) begin
								header_error <=1'b1;
								packet_error <=1'b1;
								state        <=ST_WAIT_SOF0;
							end else begin
								payload_count <=32'd0;

								if (payload_len_with_current ==32'd0) begin
									state <=ST_CHECKSUM;
								end else begin
									state <=ST_PAYLOAD;
								end
							end

							header_count <=4'd0;
						end else begin
							header_count <=header_count + 4'd1;
						end
					end

					// Stream payload bytes
					ST_PAYLOAD: begin
						payload_valid <=1'b1;
						payload_data  <=rx_data;
						payload_index <=payload_count;

						// If labels are included, label bytes come after image bytes.
						payload_is_label <=
							((flags & FLAG_INCLUDE_LABEL) !=8'd0) &&
							(payload_count >=image_byte_count);

						checksum_acc <=checksum_acc + rx_data;

						if (payload_count ==payload_len - 1) begin
							state <=ST_CHECKSUM;
						end else begin
							payload_count <=payload_count + 32'd1;
						end
					end

					// Read and check checksum byte
					ST_CHECKSUM: begin
						received_checksum <=rx_data;
						computed_checksum <=checksum_acc;

						if (rx_data ==checksum_acc) begin
							packet_done <=1'b1;
						end else begin
							checksum_error <=1'b1;
							packet_error   <=1'b1;
						end

						state <=ST_WAIT_SOF0;
					end

					default: begin
						state <=ST_WAIT_SOF0;
					end

				endcase
			end
		end
	end

endmodule