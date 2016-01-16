module CoolGirl 
	(
	input	m2,
	input romsel,
	input cpu_rw_in,
	input [14:0] cpu_addr_in,
	input [7:0] cpu_data_in,
	output [26:13] cpu_addr_out,
	output flash_we,
	output flash_oe,
	output sram_ce,
	output sram_we,
	output sram_oe,
		
	input ppu_rd_in,
	input ppu_wr_in,
	input [13:0] ppu_addr_in,
	output [17:10] ppu_addr_out,
	output ppu_rd_out,
	output ppu_wr_out,
	output ppu_ciram_a10,
	output ppu_ciram_ce,
		
	output irq,
	
	input reset
);
	reg [26:14] cpu_base;
	reg [18:14] cpu_mask;
	reg [17:13] chr_mask;
	reg [1:2] sram_page;
	reg [3:0] mapper;
	reg sram_enabled;
	reg chr_write_enabled;
	reg prg_write_enabled;
	reg lockout;

	reg [7:0] cpu_bank;
	//reg [5:0] ppu_bank;
	reg game;

	//assign cpu_addr_out[26:13] = {8'b00000000, cpu_bank[3:0], cpu_addr_in[14:13]}; // для записи
	assign cpu_addr_out[26:13] = {8'b000000000, game, cpu_bank[2:0], cpu_addr_in[14:13]}; // AxROM x 2
	//assign cpu_addr_out[26:13] = {12'b0000000000000, cpu_addr_in[14:13]}; // NROM
	assign flash_we = (cpu_rw_in | romsel) & prg_write_enabled;
	assign flash_oe = ~cpu_rw_in | romsel;
	assign sram_ce = 1;//!(cpu_addr_in[14] && cpu_addr_in[13] && m2 && romsel);
	assign sram_we = 1;//cpu_rw_in;
	assign sram_oe = 1;//~cpu_rw_in;
	
	assign ppu_addr_out[17:10] = {5'b00000, ppu_addr_in[12:10]};
	assign ppu_rd_out = ppu_rd_in | ppu_addr_in[13];
	assign ppu_wr_out = (ppu_wr_in | ppu_addr_in[13]) & chr_write_enabled;
	//assign ppu_ciram_a10 = ppu_addr_in[10]; // vertical
	//assign ppu_ciram_a10 = ppu_addr_in[11]; // horizontal
	//assign ppu_ciram_a10 = 1;
	assign ppu_ciram_a10 = cpu_bank[4]; // AxROM
	assign ppu_ciram_ce = 1'bZ; // ~ppu_addr_in[13];
	
	assign irq = 1'bz;

	/*
	always @ (negedge m2)
	begin
		if (romsel == 1 && cpu_rw_in == 0)
		begin
			if (cpu_addr_in[14] == 0)
				cpu_bank <= cpu_data_in[7:0];
			//else
//				ppu_bank <= cpu_data_in[5:0];
		end
	end
	*/

	always @ (negedge m2)
	begin
		if (romsel == 0 && cpu_rw_in == 0)
			cpu_bank = cpu_data_in;		
	end
	
	// AxROM
	/*
	always @ (posedge romsel)
	begin
		if (cpu_rw_in == 0)
			cpu_bank = cpu_data_in;		
	end
	*/

	always @ (negedge reset)
	begin
		game = ~game;
	end
endmodule
