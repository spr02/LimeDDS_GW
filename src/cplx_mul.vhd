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
use IEEE.NUMERIC_STD.ALL;


entity cplx_mul is
		generic(
			A_WIDTH		: integer := 12;
			B_WIDTH		: integer := 12;
			P_WIDTH		: integer := 16
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
			PrealxDO	: out	std_logic_vector((P_WIDTH - 1) downto 0);
			PimagxDO	: out	std_logic_vector((P_WIDTH - 1) downto 0)
		);
end cplx_mul;


architecture rtl of cplx_mul is
	------------------------------------------------
	--	Signals
	------------------------------------------------
	signal ArealxDP, AimagxDP		: std_logic_vector((A_WIDTH - 1) downto 0);
	signal BrealxDP, BimagxDP		: std_logic_vector((A_WIDTH - 1) downto 0);
	signal PrealxDP, PrealxDN		: std_logic_vector((P_WIDTH - 1) downto 0);
	signal PimagxDP, PimagxDN		: std_logic_vector((P_WIDTH - 1) downto 0);
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
			ArealxDP <= ArealxDI;
			AimagxDP <= AimagxDI;
			BrealxDP <= BrealxDI;
			BimagxDP <= BimagxDI;
			PrealxDP	<= PrealxDN;
			PimagxDP	<= PrealxDN;
		end if;
	end process;

	------------------------------------------------
	--	Combinatorical process (feed back logic)
	------------------------------------------------
   	p_comb_MUL : process (ArealxDP, AimagxDP, BrealxDP, BimagxDP)
		variable a_real		: signed(ArealxDP'left downto 0);
		variable a_imag		: signed(AimagxDP'left downto 0);
		variable b_real		: signed(BrealxDP'left downto 0);
		variable b_imag		: signed(BimagxDP'left downto 0);
		variable p_real		: signed(A_WIDTH+B_WIDTH-1 downto 0);
		variable p_imag		: signed(A_WIDTH+B_WIDTH-1 downto 0);
	begin
		a_real := signed(ArealxDP);
		a_imag := signed(AimagxDP);
		b_real := signed(BrealxDP);
		b_imag := signed(BimagxDP);
		
		p_real := a_real*b_real - a_imag*b_imag;
		p_imag := a_real*b_imag + a_imag*b_real;
		
		PrealxDN	<= std_logic_vector(p_real(p_real'left downto (p_real'left - P_WIDTH + 1)));
		PimagxDN	<= std_logic_vector(p_imag(p_imag'left downto (p_imag'left - P_WIDTH + 1)));
	end process;


	------------------------------------------------
	--	Output Assignment
	------------------------------------------------
	PrealxDO	<= PrealxDP;
	PimagxDO	<= PimagxDP;

end rtl;
