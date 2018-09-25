----------------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Author:  Jannik Springer
--		  jannik.springer@rwth-aachen.de
----------------------------------------------------------------------------
-- 
-- Create Date:	
-- Design Name: 
-- Module Name:	
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
-- Calculates: (Ai + jAq) * (Bi + jBq) = AiBi - AqBq + j * (AiBq + AqBi) = Pi + j *  Pq

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity axis_register is
		generic(
			D_WIDTH : integer := 8
		);
		port(
			ClkxCI	: in  std_logic;
			RstxRBI	: in  std_logic;
			-- control
			EnxSI	: in  std_logic;
			-- input
			DVldxSI	: in  std_logic;
			DRdyxSO	: out std_logic;
			DxDI	: in  std_logic_vector((D_WIDTH - 1) downto 0);
			-- output
			QVldxSO	: out std_logic;
			QRdyxSI	: in  std_logic;
			QxDO	: out std_logic_vector((D_WIDTH - 1) downto 0)
		);
end axis_register;


architecture rtl of axis_register is
	------------------------------------------------
	--	Signals
	------------------------------------------------
	
	-- input interface
	signal DRdxS		: std_logic;
	signal DRdyxSP		: std_logic;
	
	-- buffer register
	signal BEnxS		: std_logic;
	signal BVldxSP		: std_logic;
	signal BxDP			: std_logic_vector((D_WIDTH - 1) downto 0);
	
	-- output interface
	signal QRdxS		: std_logic;
	signal QVldxSP		: std_logic;
	signal QxDP			: std_logic_vector((D_WIDTH - 1) downto 0);
begin
	------------------------------------------------
	--	Synchronus processes (sequential logic and registers)
	------------------------------------------------
	DRdxS <= DVldxSI and DRdyxSP; -- D (input) is read
	QRdxS <= QVldxSP and QRdyxSI; -- Q (output) is read
	BEnxS <= DRdxS and (QVldxSP and not QRdyxSI); -- store input to temporary buffer B
	p_axis_ctl : process(ClkxCI, RstxRBI)
	begin
		if (RstxRBI = '0') then
			DRdyxSP <= '0';
			BVldxSP <= '0';
			QVldxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			DRdyxSP <= (QRdyxSI or not QVldxSP) or (DRdyxSP and (not DRdxS));
			BVldxSP <= BEnxS or (BVldxSP and (not QRdxS));
			QVldxSP <= (DRdxS or (QRdxS and BVldxSP)) or (QVldxSP and (not QRdyxSI)); -- **TODO** QRdxS instead of QRdyxSI?
		end if;
	end process;
	
	p_axis_data : process(ClkxCI, RstxRBI)
	begin
		if (RstxRBI = '0') then
			BxDP <= (others => '0');
			QxDP <= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			if (DRdxS= '1') then
				if (QVldxSP = '0' or QRdyxSI = '1') then
					QxDP <= DxDI; -- input to output
				else
					BxDP <= DxDI; -- input to temp
				end if;
			elsif (QRdxS = '1') and (BVldxSP= '1') then
				QxDP <= BxDP; -- output to temp
			end if;
		end if;
	end process;
	
	
	------------------------------------------------
	-- output assignment
	------------------------------------------------
	--input port
	DRdyxSO <= DRdyxSP;
	
	-- output port
	QVldxSO <= QVldxSP;
	QxDO	<= QxDP;
	
	
end rtl;

	
-- architecture rtl2 of axis_register is
-- 	------------------------------------------------
-- 	--	Signals
-- 	------------------------------------------------
-- 	
-- 	-- input interface
-- 	signal DEnxS				: std_logic;
-- 	signal DRdyxSP				: std_logic;
-- 	
-- 	-- buffer registers
-- 	signal BEnxS				: std_logic;
-- 	signal BRdyxSP, BVldxSP		: std_logic;
-- 	signal BxDP					: std_logic_vector((D_WIDTH - 1) downto 0);
-- 	
-- 	-- output interface
-- 	signal QEnxS, QRdxS			: std_logic;
-- 	signal QVldxSP				: std_logic;
-- 	signal QxDP					: std_logic_vector((D_WIDTH - 1) downto 0);
-- begin
-- 	------------------------------------------------
-- 	--	Synchronus process (sequential logic and registers)
-- 	------------------------------------------------
-- 	
-- 	
-- 	DEnxS <= DRdyxSP and DVldxSI; -- D input is read
-- -- 	QEnxS <= QVldxSP and QRdyxSI; -- Q reg is read
-- -- 	QEnxS <= DRdyxSP and DVldxSI; -- enable Q reg (i.e. D is read)
-- 	QRdxS <= QVldxSP and QRdyxSI; -- Q reg is read
-- 	BEnxS <= DEnxS and (QVldxSP and not QRdyxSI); -- store input to temporary buffer B
-- -- 	QEnxS <= (DVldxSI or BVldxSP) and QRdyxSI;
-- 	QEnxS <= DEnxS or (BVldxSP and QRdyxSI);
-- 	p_axis_ctl : process(ClkxCI, RstxRBI)
-- 	begin
-- 		if (RstxRBI = '0') then
-- 			DRdyxSP <= '0';
-- 			BVldxSP <= '0';
-- 			QVldxSP <= '0';
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			DRdyxSP <= (QRdyxSI or not QVldxSP) or (DRdyxSP and (not QEnxS));
-- 			BVldxSP <= BEnxS or (BVldxSP and (not QRdxS));
-- 			QVldxSP <= (QEnxS or (QRdxS and BVldxSP)) or (QVldxSP and (not QRdyxSI));
-- 		end if;
-- 	end process;
-- 	
-- 	p_axis_data : process(ClkxCI, RstxRBI)
-- 	begin
-- 		if (RstxRBI = '0') then
-- 			BxDP <= (others => '0');
-- 			QxDP <= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			if (QEnxS= '1') then
-- 				if (BVldxSP = '1') then
-- 					QxDP <= BxDP; -- temp to output
-- 				else
-- 					QxDP <= DxDI; -- input to output
-- 				end if;
-- 			end if;
-- 			if (BEnxS = '1') then
-- 				BxDP <= DxDI; -- input to temp
-- 			end if;
-- 		end if;
-- 	end process;
-- 	
-- 	
-- 	-- output assignment
-- 	
-- 	--input port
-- 	DRdyxSO <= DRdyxSP;
-- 	
-- 	-- output port
-- 	QVldxSO <= QVldxSP;
-- 	QxDO	<= QxDP;
-- 	
-- 	
-- end rtl2;
	
	
	
-- 	
-- assign input_axis_tready = input_axis_tready_reg;
-- 
-- assign output_axis_tdata  = output_axis_tdata_reg;
-- assign output_axis_tkeep  = KEEP_ENABLE ? output_axis_tkeep_reg : {KEEP_WIDTH{1'b1}};
-- assign output_axis_tvalid = output_axis_tvalid_reg;
-- assign output_axis_tlast  = LAST_ENABLE ? output_axis_tlast_reg : 1'b1;
-- assign output_axis_tid    = ID_ENABLE   ? output_axis_tid_reg   : {ID_WIDTH{1'b0}};
-- assign output_axis_tdest  = DEST_ENABLE ? output_axis_tdest_reg : {DEST_WIDTH{1'b0}};
-- assign output_axis_tuser = USER_ENABLE ? output_axis_tuser_reg : {USER_WIDTH{1'b0}};
-- 	
-- 	// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
-- wire input_axis_tready_early = output_axis_tready | (~temp_axis_tvalid_reg & (~output_axis_tvalid_reg | ~input_axis_tvalid));
-- 
-- always @* begin
--     // transfer sink ready state to source
--     output_axis_tvalid_next = output_axis_tvalid_reg;
--     temp_axis_tvalid_next = temp_axis_tvalid_reg;
-- 
--     store_axis_input_to_output = 1'b0;
--     store_axis_input_to_temp = 1'b0;
--     store_axis_temp_to_output = 1'b0;
-- 
--     if (input_axis_tready_reg) begin
--         // input is ready
--         if (output_axis_tready | ~output_axis_tvalid_reg) begin
--             // output is ready or currently not valid, transfer data to output
--             output_axis_tvalid_next = input_axis_tvalid;
--             store_axis_input_to_output = 1'b1;
--         end else begin
--             // output is not ready, store input in temp
--             temp_axis_tvalid_next = input_axis_tvalid;
--             store_axis_input_to_temp = 1'b1;
--         end
--     end else if (output_axis_tready) begin
--         // input is not ready, but output is ready
--         output_axis_tvalid_next = temp_axis_tvalid_reg;
--         temp_axis_tvalid_next = 1'b0;
--         store_axis_temp_to_output = 1'b1;
--     end
-- end
-- 
-- always @(posedge clk) begin
-- 
--     if (rst) begin
--         input_axis_tready_reg <= 1'b0;
--         output_axis_tvalid_reg <= 1'b0;
--         temp_axis_tvalid_reg <= 1'b0;
--     end else begin
--         input_axis_tready_reg <= input_axis_tready_early;
--         output_axis_tvalid_reg <= output_axis_tvalid_next;
--         temp_axis_tvalid_reg <= temp_axis_tvalid_next;
--     end
-- 
--     // datapath
--     if (store_axis_input_to_output) begin
--         output_axis_tdata_reg <= input_axis_tdata;
--     end else if (store_axis_temp_to_output) begin
--         output_axis_tdata_reg <= temp_axis_tdata_reg;
--     end
-- 
--     if (store_axis_input_to_temp) begin
--         temp_axis_tdata_reg <= input_axis_tdata;
--     end
-- end

