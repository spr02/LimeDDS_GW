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

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity cplx_mul is
		generic(
			A_WIDTH		: integer := 12;
			B_WIDTH		: integer := 12;
			OUT_WIDTH	: integer := 24
		);
		port(
			ClkxCI		: in	std_logic;
			RstxRBI	 	: in	std_logic;

			EnablexSI	: in	std_logic;
			
			-- data
			ArealxDI	: in  std_logic_vector((A_WIDTH - 1) downto 0);
			AimagxDI	: in  std_logic_vector((A_WIDTH - 1) downto 0);
			BrealxDI	: in  std_logic_vector((B_WIDTH - 1) downto 0);
			BimagxDI	: in  std_logic_vector((B_WIDTH - 1) downto 0);

			-- output
			PrealxDO	: out	std_logic_vector((OUT_WIDTH - 1) downto 0)
			PimagxDO	: out	std_logic_vector((OUT_WIDTH - 1) downto 0)
		);
end cplx_mul;


architecture rtl of cplx_mul is
	------------------------------------------------
	--	Signals
	------------------------------------------------
	signal PrealxDP, PrealxDN		: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal PimagxDP, PimagxDN		: std_logic_vector((OUT_WIDTH - 1) downto 0);
begin

	------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------
	p_sync : process (ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			PrealxDP	<= (others => '0');
			PimagxDP	<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			PrealxDP	<= PrealxDN;
			PimagxDP	<= PrealxDN;
		end if;
	end process;

	------------------------------------------------
	--	Combinatorical process (feed back logic)
	------------------------------------------------
   	p_comb_MUL : process (ArealxDI, AimagxDI, BrealxDI, BimagxDI)
		variable a_real		: signed(ArealxDI'left downto 0);
		variable a_imag		: signed(AimagxDI'left downto 0);
		variable b_real		: signed(BrealxDI'left downto 0);
		variable b_imag		: signed(BimagxDI'left downto 0);
	begin
		a_real := signed(ArealxDI);
		a_imag := signed(AimagxDI);
		b_real := signed(BrealxDI);
		b_imag := signed(BimagxDI);
		
		tmp_real := a_real*b_real - a_imag*b_imag;
		tmp_imag := a_real*b_imag + a_imag*b_real;
		
		PrealxDN	<= (others => '0');
		PimagxDN	<= (others => '0');
	end process;


	------------------------------------------------
	--	Output Assignment
	------------------------------------------------
	PrealxDO	<= PrealxDP;
	PimagxDO	<= PimagxDP;

end rtl;
