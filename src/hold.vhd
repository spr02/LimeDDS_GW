----------------------------------------------------------------------------------
----------------------------------------------------------------------------
-- Author:  Jannik Springer
--          jannik.springer@rwth-aachen.de
----------------------------------------------------------------------------
-- 
-- Create Date:    
-- Design Name: 
-- Module Name:    
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--      
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity hold is
	generic(
		HOLD_CC		: integer := 3
	);
	port(
		ClkxCI      : in  std_logic;
		RstxRBI     : in  std_logic;

		TrigxSI		: in  std_logic;
		HoldxSO		: out std_logic
	);
end hold;


architecture rtl of hold is
	------------------------------------------------
	--	Signals and Types
	------------------------------------------------
	signal DelayLinexSP		: std_logic_vector((HOLD_CC - 1) downto 0);
	signal HoldxSP			: std_logic;
begin
	p_sync_reg : process (ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			DelayLinexSP	<= (others => '0');
			HoldxSP			<= '0';
		elsif rising_edge(ClkxCI) then
			DelayLinexSP	<= DelayLinexSP(DelayLinexSP'high - 1 downto 0) & TrigxSI;
			HoldxSP			<= TrigxSI or (HoldxSP and not DelayLinexSP(DelayLinexSP'high));
		end if;
	end process;
	
	HoldxSO <= HoldxSP;
end rtl;
