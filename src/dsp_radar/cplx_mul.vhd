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
			AVldxSI		: in  std_logic;
			ARdyxSO		: out std_logic;
			ArealxDI	: in  std_logic_vector((A_WIDTH - 1) downto 0);
			AimagxDI	: in  std_logic_vector((A_WIDTH - 1) downto 0);
			
			BVldxSI		: in  std_logic;
			BRdyxSO		: out std_logic;
			BrealxDI	: in  std_logic_vector((B_WIDTH - 1) downto 0);
			BimagxDI	: in  std_logic_vector((B_WIDTH - 1) downto 0);

			-- output
			PVldxSO		: out std_logic;
			PRdyxSI		: in  std_logic;
			PrealxDO	: out std_logic_vector((P_WIDTH - 1) downto 0);
			PimagxDO	: out std_logic_vector((P_WIDTH - 1) downto 0)
		);
end cplx_mul;


architecture rtl of cplx_mul is
	------------------------------------------------
	--	Signals
	------------------------------------------------
	
	-- ready, valid and enable signal for port A
	signal IQEnAxS, IQVldAxSP, IQRdyAxSP	: std_logic;
	signal ArealxDP, AimagxDP				: signed((A_WIDTH - 1) downto 0);
	signal BufAEnxS, BufAVldxSP				: std_logic;
	signal BufAIxDP, BufAQxDP				: signed((A_WIDTH - 1) downto 0);
	
	-- ready, valid and enable signal for port B
	signal IQEnBxS, IQVldBxSP, IQRdyBxSP	: std_logic;
	signal BrealxDP, BimagxDP				: signed((B_WIDTH - 1) downto 0);
	signal BufBEnxS, BufBVldxSP				: std_logic;
	signal BufBIxDP, BufBQxDP				: signed((B_WIDTH - 1) downto 0);
	
	
	
	signal IQRdyAxS, IQRdyBxS				: std_logic;
	
	
	-- enable signal for datapath
	signal IQSyncABxS						: std_logic;
	signal IQVldABxS, IQRdyABxS				: std_logic;
	signal IQRdABxS							: std_logic;
	signal EnxS								: std_logic;
	signal VldxSP							: std_logic_vector(2 downto 0);
	
	-- multiplier
	signal IQRdyMulxS						: std_logic;
	signal IQVldMulxSP, IQRdyMulxSP			: std_logic;
	signal IQEnMulxS						: std_logic;
	signal IQRdMulxS						: std_logic;
	signal AiBixDP, AqBqxDP					: signed((A_WIDTH + B_WIDTH - 1) downto 0);
	signal AiBqxDP, AqBixDP					: signed((A_WIDTH + B_WIDTH - 1) downto 0);
	
	-- adder (result)
	signal IQRdyAddxS						: std_logic;
	signal IQVldAddxSP, IQRdyAddxSP			: std_logic;
	signal IQEnAddxS						: std_logic;
	signal IQRdAddxS						: std_logic;
	signal ResIxDP, ResQxDP					: std_logic_vector((P_WIDTH - 1) downto 0);
	
	-- IQ buffer for port P
	signal BufPEnxS, BufPVldxSP				: std_logic;
	signal BufPIxDP, BufPQxDP				: std_logic_vector((P_WIDTH - 1) downto 0);
	
	-- ready and valid for output port P
	signal IQEnPxS, IQRdPxS					: std_logic;
	signal IQRdyPxS							: std_logic;
	signal PRdyxSP							: std_logic;
	signal IQVldPxSP, IQRdyPxSP				: std_logic;
	signal PrealxDP, PimagxDP				: std_logic_vector((P_WIDTH - 1) downto 0);
	signal a_set, a_reset			: std_logic;
	signal b_set, b_reset			: std_logic;	
	signal tmp, tmp2, tmp1, tmp3, tmp4, tmp5, tmp6, tmp7							: std_logic;
begin
	------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------
	
-- 	DRdxS <= DVldxSI and DRdyxSP; -- D (input) is read
-- 	QRdxS <= QVldxSP and QRdyxSI; -- Q (output) is read
-- 	BEnxS <= DRdxS and (QVldxSP and not QRdyxSI); -- store input to temporary buffer B
-- 	p_axis_ctl : process(ClkxCI, RstxRBI)
-- 	begin
-- 		if (RstxRBI = '0') then
-- 			DRdyxSP <= '0';
-- 			BVldxSP <= '0';
-- 			QVldxSP <= '0';
-- 			BxDP <= (others => '0');
-- 			QxDP <= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			DRdyxSP <= (QRdyxSI or not QVldxSP) or (DRdyxSP and (not DRdxS));
-- 			BVldxSP <= BEnxS or (BVldxSP and (not QRdxS));
-- 			QVldxSP <= (DRdxS or (QRdxS and BVldxSP)) or (QVldxSP and (not QRdyxSI));
-- 			if (DRdxS= '1') then
-- 				if (QVldxSP = '0' or QRdyxSI = '1') then
-- 					QxDP <= DxDI; -- input to output
-- 				else
-- 					BxDP <= DxDI; -- input to temp
-- 				end if;
-- 			elsif (QRdxS = '1') and (BVldxSP= '1') then
-- 				QxDP <= BxDP; -- output to temp
-- 			end if;
-- 		end if;
-- 	end process;
	

	-- input register + AXIS control port A
	IQEnAxS  <= IQRdyAxSP and AVldxSI;
	BufAEnxS <= IQEnAxS and (IQVldAxSP and not IQRdyMulxS);
	p_sync_reg_a : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQVldAxSP	<= '0';
			IQRdyAxSP	<= '1';
			BufAVldxSP	<= '0';
			ArealxDP	<= (others => '0');
			AimagxDP	<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			-- ctl
			IQVldAxSP	<= (IQEnAxS or (IQEnMulxS and BufAVldxSP)) or (IQVldAxSP and not IQEnMulxS);
-- 			IQRdyAxSP	<= ((IQSyncABxS and IQRdyMulxS) or (IQSyncABxS and not IQVldAxSP)) or (IQRdyAxSP and not IQEnAxS);
			IQRdyAxSP	<= ((IQSyncABxS and IQRdyMulxS and not BufAVldxSP) or IQEnMulxS or (IQSyncABxS and not IQVldAxSP)) or (IQRdyAxSP and not IQEnAxS);
-- 			IQRdyAxSP	<= ((IQSyncABxS and IQRdyMulxS) or (not IQVldAxSP)) or (IQRdyAxSP and not IQEnAxS);
			BufAVldxSP	<= (IQEnAxS and IQVldAxSP and not IQEnMulxS) or (BufAVldxSP and not IQEnMulxS);
			-- data
			if (IQEnAxS = '1') then
				if ((IQVldAxSP = '0') or (IQEnMulxS = '1')) then
					ArealxDP <= signed(ArealxDI);
					AimagxDP <= signed(AimagxDI);
				else
					BufAIxDP <= signed(ArealxDI);
					BufAQxDP <= signed(AimagxDI);
				end if;
			elsif ((IQEnMulxS = '1') and (BufAVldxSP = '1')) then
				ArealxDP <= BufAIxDP;
				AimagxDP <= BufAQxDP;
			end if;
		end if;
	end process;
	
	
	-- input register + AXIS control port B
	IQEnBxS  <= IQRdyBxSP and BVldxSI;
	BufBEnxS <= IQEnBxS and (IQVldBxSP and not IQRdyMulxS);
	p_sync_reg_b : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQVldBxSP	<= '0';
			IQRdyBxSP	<= '1';
			BufBVldxSP	<= '0';
			BrealxDP	<= (others => '0');
			BimagxDP	<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			-- ctl
			IQVldBxSP	<= (IQEnBxS or (IQEnMulxS and BufBVldxSP)) or (IQVldBxSP and not IQEnMulxS);
-- 			IQRdyBxSP	<= ((IQSyncABxS and IQRdyMulxS) or (IQSyncABxS and not IQVldBxSP)) or (IQRdyBxSP and not IQEnBxS);
			IQRdyBxSP	<= ((IQSyncABxS and IQRdyMulxS and not BufBVldxSP) or IQEnMulxS or (IQSyncABxS and not IQVldBxSP)) or (IQRdyBxSP and not IQEnBxS);
-- 			IQRdyBxSP	<= ((IQSyncABxS and IQRdyMulxS) or (not IQVldBxSP)) or (IQRdyBxSP and not IQEnBxS);
			BufBVldxSP	<= (IQEnBxS and IQVldBxSP and not IQEnMulxS) or (BufBVldxSP and not IQEnMulxS);
			-- data
			if (IQEnBxS = '1') then
				if ((IQVldBxSP = '0') or (IQEnMulxS = '1')) then
					BrealxDP <= signed(BrealxDI);
					BimagxDP <= signed(BimagxDI);
				else
					BufBIxDP <= signed(BrealxDI);
					BufBQxDP <= signed(BimagxDI);
				end if;
			elsif ((IQEnMulxS = '1') and (BufBVldxSP = '1')) then
				BrealxDP <= BufBIxDP;
				BimagxDP <= BufBQxDP;
			end if;
		end if;
	end process;
	
	
	-- input register + AXIS control port A
-- 	IQRdyAxS <= IQRdABxS or not IQVldAxSP;
-- 	IQEnAxS <= IQRdyAxS and AVldxSI;
-- 	p_sync_reg_a : process(RstxRBI, ClkxCI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			IQVldAxSP	<= '0';
-- 			IQRdyAxSP	<= '1';
-- 			ArealxDP	<= (others => '0');
-- 			AimagxDP	<= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			IQVldAxSP <= IQEnAxS or (IQVldAxSP and not IQEnMulxS);
-- 			IQRdyAxSP <= (not IQVldAxSP and not IQEnAxS) or (IQSyncABxS and IQRdyMulxSP) or (IQRdyAxSP and not IQEnAxS);
-- 			if (IQEnAxS = '1') then
-- 				ArealxDP <= signed(ArealxDI);
-- 				AimagxDP <= signed(AimagxDI);
-- 			end if;
-- 		end if;
-- 	end process;
	
	

	-- input register + AXIS control port B
-- 	IQRdyBxS <= IQRdABxS or not IQVldBxSP;
-- 	IQEnBxS <= IQRdyBxS and BVldxSI;
-- 	p_sync_reg_b : process(RstxRBI, ClkxCI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			IQVldBxSP	<= '0';
-- 			IQRdyBxSP	<= '1';
-- 			BrealxDP	<= (others => '0');
-- 			BimagxDP	<= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			IQVldBxSP <= IQEnBxS or (IQVldBxSP and not IQEnMulxS);
-- 			IQRdyBxSP <= (not IQVldBxSP and not IQEnBxS) or (IQSyncABxS and IQRdyMulxSP) or (IQRdyBxSP and not IQEnBxS);
-- 			if (IQEnBxS = '1') then
-- 				BrealxDP <= signed(BrealxDI);
-- 				BimagxDP <= signed(BimagxDI);
-- 			end if;
-- 		end if;
-- 	end process;
	
	IQSyncABxS	<= (IQVldAxSP or IQEnAxS) and (IQVldBxSP or IQEnBxS); -- set, when port a and b are in sync
	IQVldABxS	<= IQVldAxSP and IQVldBxSP; --both inputs valid
	IQRdABxS	<= IQVldABxS and IQRdyMulxS;
	
	-- multiplier
	IQRdyMulxS	<= IQRdMulxS or not IQVldMulxSP;
	IQEnMulxS	<= IQVldABxS and IQRdyMulxS;
	IQRdMulxS	<= IQVldMulxSP and IQRdyAddxS;
	p_sync_mul : process (RstxRBI, ClkxCI)
	begin
		if (RstxRBI = '0') then
			IQVldMulxSP <= '0';
			IQRdyMulxSP <= '1';
		elsif ClkxCI'event and ClkxCI = '1' then
			IQVldMulxSP	<= IQEnMulxS or (IQVldMulxSP and not IQEnAddxS);
-- 			IQRdyMulxSP <= ((not IQVldMulxSP and not IQEnMulxS) or (not IQVldPxSP and not IQEnPxS)) or (IQRdyMulxSP and not IQEnMulxS);
			if (IQEnMulxS = '1') then
				AiBixDP <= ArealxDP * BrealxDP;
				AqBqxDP <= AimagxDP * BimagxDP;
				AiBqxDP <= ArealxDP * BimagxDP;
				AqBixDP <= AimagxDP * BrealxDP;
			end if;
		end if;
	end process;

	-- adder 
	IQRdyAddxS <= IQRdAddxS or not IQVldAddxSP;
	IQEnAddxS <= IQVldMulxSP and IQRdyAddxS;
	IQRdAddxS <= IQVldAddxSP and IQRdyPxSP;
	p_sync_add : process(RstxRBI, ClkxCI)
		variable v_p_real : signed(A_WIDTH + B_WIDTH downto 0);
		variable v_p_imag : signed(A_WIDTH + B_WIDTH downto 0);
-- 		variable v_p_real : signed(PrealxDP'high downto 0);
-- 		variable v_p_imag : signed(PimagxDP'high downto 0);
	begin
		if (RstxRBI = '0') then
			IQVldAddxSP <= '0';
			IQRdyAddxSP <= '1';
		elsif ClkxCI'event and ClkxCI = '1' then
			IQVldAddxSP <= IQEnAddxS or (IQVldAddxSP and not IQEnPxS);
-- 			IQRdyAddxSP <= ((not IQVldAddxSP and not IQEnAddxS) or (IQRdyPxSP and not IQEnPxS)) or (IQRdyAddxSP and not IQEnAddxS);
			if (IQEnAddxS = '1') then
				-- real part
				v_p_real := resize(AiBixDP, v_p_real'length) - resize(AqBqxDP, v_p_real'length);
				ResIxDP <= std_logic_vector(v_p_real(v_p_real'high downto v_p_real'high - PrealxDP'length + 1));
-- 				PrealxDP <= std_logic_vector(v_p_real(v_p_real'high downto v_p_real'high - PrealxDP'length + 1));
				--imaginary part
				v_p_imag := resize(AiBqxDP, v_p_imag'length) + resize(AqBixDP, v_p_imag'length);
				ResQxDP <= std_logic_vector(v_p_imag(v_p_imag'high downto v_p_imag'high - PrealxDP'length + 1));
-- 				PimagxDP <= std_logic_vector(v_p_imag(v_p_imag'high downto v_p_imag'high - PrealxDP'length + 1));
			end if;
		end if;
	end process;
	
	-- AXIS control for output port P
	IQRdPxS <= IQVldPxSP and PRdyxSI; -- P reg is read
	IQEnPxS <= IQVldAddxSP and IQRdyPxSP; -- enable P reg
	
	p_sync_reg_p : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQVldPxSP	<= '0';
			IQRdyPxSP	<= '1';
			BufPVldxSP 	<= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			-- ctl
			IQVldPxSP	<= (IQEnPxS or (IQRdPxS and BufPVldxSP)) or (IQVldPxSP and not PRdyxSI);
			IQRdyPxSP	<= (PRdyxSI or not IQVldPxSP) or (IQRdyPxSP and (not IQEnPxS));
			BufPVldxSP	<= (IQEnPxS and IQVldPxSP and not PRdyxSI) or (BufPVldxSP and not IQRdPxS);
			-- data
			if (IQEnPxS = '1') then
				if (IQVldPxSP = '0' or PRdyxSI = '1') then
					PrealxDP		<= ResIxDP;
					PimagxDP		<= ResQxDP;
				else
					BufPIxDP	<= ResIxDP;
					BufPQxDP	<= ResQxDP;
				end if;
			elsif (IQRdPxS = '1') and (BufPVldxSP = '1') then
					PrealxDP <= BufPIxDP;
					PimagxDP <= BufPQxDP;
			end if;
		end if;
	end process;
	

	------------------------------------------------
	--	Output Assignment
	------------------------------------------------
	-- input ports
	ARdyxSO		<= IQRdyAxSP;
	BRdyxSO		<= IQRdyBxSP;
	
	-- output port
	PVldxSO		<= IQVldPxSP;
	PrealxDO	<= PrealxDP;
	PimagxDO	<= PimagxDP;

end rtl;



-- 			IQRdyAxSP <= (not IQVldAxSP and not IQEnAxS) or (IQRdyAxSP and (tmp or not IQEnAxS));
-- 			IQRdyAxSP <= (not VldxSP(2)) or (IQRdyAxSP and not IQEnAxS);
-- 			IQRdyAxSP <= (((IQRdPxS or not VldxSP(2)) and '1') or (not IQVldAxSP and not IQEnAxS)) or (IQRdyAxSP and not IQEnAxS);
-- 			IQRdyAxSP <= (((IQRdPxS or (EnxS and not VldxSP(2))) and (IQEnBxS or (not IQVldAxSP and not IQRdyAxSP))) or (not IQVldAxSP and not IQEnAxS)) or (IQRdyAxSP and not IQEnAxS);
-- 			IQRdyBxSP <= (((IQRdPxS or not VldxSP(2)) and (IQEnAxS or (not IQVldBxSP and not IQRdyBxSP))) or (not IQVldBxSP and not IQEnBxS)) or (IQRdyBxSP and not IQEnBxS);


-- 			IQRdyBxSP <= (not IQVldBxSP and not IQEnBxS) or (IQRdyBxSP and (tmp or not IQEnBxS));
-- 			IQRdyBxSP <= (not VldxSP(2) and not tmp1) or (IQRdyBxSP and not IQEnBxS);
-- 			IQRdyBxSP <= (((IQRdPxS or not VldxSP(2)) and '1') or (not IQVldBxSP and not IQEnBxS)) or (IQRdyBxSP and not IQEnBxS);
-- 			IQRdyBxSP <= (((IQRdPxS or (EnxS and not VldxSP(2))) and (IQEnAxS or (not IQVldBxSP and not IQRdyBxSP))) or (not IQVldBxSP and not IQEnBxS)) or (IQRdyBxSP and not IQEnBxS);




-- 	------------------------------------------------
-- 	--	Synchronus process (sequential logic and registers)
-- 	------------------------------------------------
-- 	
-- 	-- input register + AXIS control port A
-- 	IQEnAxS <= IQRdyAxSP and AVldxSI;
-- 	p_sync_reg_a : process(RstxRBI, ClkxCI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			IQVldAxSP	<= '0';
-- 			IQRdyAxSP	<= '1';
-- 			ArealxDP	<= (others => '0');
-- 			AimagxDP	<= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			IQVldAxSP <= IQEnAxS or (IQVldAxSP and not (EnxS and IQVldABxS));
-- 			IQRdyAxSP <= a_set or (IQRdyAxSP and not a_reset);
-- 			if (IQEnAxS = '1') then
-- 				ArealxDP <= signed(ArealxDI);
-- 				AimagxDP <= signed(AimagxDI);
-- 			end if;
-- 		end if;
-- 	end process;
-- 	
-- 	a_set <= (not IQVldAxSP and not IQEnAxS) or IQEnMulxS;
-- 	b_set <= (not IQVldBxSP and not IQEnBxS) or IQEnMulxS;
-- 	a_reset <= IQEnAxS;
-- 	b_reset <= IQEnBxS;
-- 	-- input register + AXIS control port B
-- 	IQEnBxS <= IQRdyBxSP and BVldxSI;
-- 	p_sync_reg_b : process(RstxRBI, ClkxCI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			IQVldBxSP	<= '0';
-- 			IQRdyBxSP	<= '1';
-- 			BrealxDP	<= (others => '0');
-- 			BimagxDP	<= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			IQVldBxSP <= IQEnBxS or (IQVldBxSP and not (EnxS and IQVldABxS));
-- 			IQRdyBxSP <= b_set or (IQRdyBxSP and not b_reset);
-- 			if (IQEnBxS = '1') then
-- 				BrealxDP <= signed(BrealxDI);
-- 				BimagxDP <= signed(BimagxDI);
-- 			end if;
-- 		end if;
-- 	end process;
-- 	tmp <= IQVldABxS and EnxS;
-- 	tmp1 <= IQEnBxS and not IQEnAxS;
-- 	tmp2 <= IQEnAxS and not IQEnBxS;
-- 	tmp3 <= ((IQVldABxS and EnxS) or not IQVldBxSP) and not tmp5;
-- 	tmp4 <= ((IQVldABxS and EnxS) or not IQVldAxSP) and not tmp5;
-- 	tmp5 <= VldxSP(2) or (IQVldPxSP and not PRdyxSI);
-- 	tmp6 <= (IQVldPxSP and not PRdyxSI);
-- 	tmp7 <= not IQEnPxS;
-- -- 	tmp1 <= PRdyxSI and  IQVldABxS and VldxSP(1);
-- -- 	tmp2 <= IQVldABxS and not VldxSP(1);
-- -- 	tmp3 <= (tmp1 or tmp2 or (not IQVldBxSP and not IQEnBxS)) or (tmp3 and not IQEnBxS) when rising_edge(ClkxCI);
-- 	
-- 	-- enable signal for mul,add and output register
-- 	IQVldABxS	<= IQVldAxSP and IQVldBxSP; --both inputs valid
-- 	IQRdyABxS	<= not VldxSP(2);
-- -- 	VldxSP(0)	<= (IQVldABxS and (not IQVldPxSP)) or (IQVldABxS and IQEnPxS);
-- 	VldxSP(0)	<= IQVldABxS;
-- 	p_sync_en : process(RstxRBI, ClkxCI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			VldxSP(VldxSP'high downto 1) <= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			if (EnxS = '1') then
-- 				VldxSP(VldxSP'high downto 1) <= VldxSP((VldxSP'high - 1) downto 0);
-- 			end if;
-- 		end if;
-- 	end process;
-- 	
-- 	-- (Ai + jAq) * (Bi + jBq) = AiBi - AqBq + j * (AiBq + AqBi)
-- 	-- multiplier
-- 	IQEnMulxS <= IQVldABxS and IQRdyMulxSP;
-- 	p_sync_mul : process (ClkxCI)
-- 	begin
-- 		if ClkxCI'event and ClkxCI = '1' then
-- 			IQRdyMulxSP
-- 			if (VldxSP(0) = '1') and (EnxS = '1') then
-- 				AiBixDP <= ArealxDP * BrealxDP;
-- 				AqBqxDP <= AimagxDP * BimagxDP;
-- 				AiBqxDP <= ArealxDP * BimagxDP;
-- 				AqBixDP <= AimagxDP * BrealxDP;
-- 			end if;
-- 		end if;
-- 	end process;
-- 
-- 	-- adder
-- 	IQEnAddxS <= 
-- 	p_sync_add : process(ClkxCI)
-- 		variable v_p_real : signed(PrealxDP'high downto 0);
-- 		variable v_p_imag : signed(PimagxDP'high downto 0);
-- 	begin
-- 		if ClkxCI'event and ClkxCI = '1' then
-- 			if (VldxSP(1) = '1') and (EnxS = '1') then
-- 				-- real part
-- 				v_p_real := resize(AiBixDP, v_p_real'length) - resize(AqBqxDP, v_p_real'length);
-- 				ResIxDP <= std_logic_vector(v_p_real(v_p_real'high downto v_p_real'high - PrealxDP'length + 1));
-- -- 				PrealxDP <= std_logic_vector(v_p_real(v_p_real'high downto v_p_real'high - PrealxDP'length + 1));
-- 				--imaginary part
-- 				v_p_imag := resize(AiBqxDP, v_p_imag'length) + resize(AqBixDP, v_p_imag'length);
-- 				ResQxDP <= std_logic_vector(v_p_imag(v_p_imag'high downto v_p_imag'high - PrealxDP'length + 1));
-- -- 				PimagxDP <= std_logic_vector(v_p_imag(v_p_imag'high downto v_p_imag'high - PrealxDP'length + 1));
-- 			end if;
-- 		end if;
-- 	end process;
-- 	
-- 	-- AXIS control for output port P
-- 	EnxS <= IQRdPxS or not IQVldPxSP;
-- 	IQRdPxS <= IQVldPxSP and PRdyxSI;
-- 	IQEnPxS <= VldxSP(2) and (IQRdPxS or not IQVldPxSP);
-- 	p_sync_reg_p : process(RstxRBI, ClkxCI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			IQVldPxSP <= '0';
-- 			IQRdyPxSP <= '1';
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			IQVldPxSP <= VldxSP(2) or (IQVldPxSP and not PRdyxSI);
-- 			IQRdyPxSP <= '0';
-- 			if (IQEnPxS = '1') then
-- 				PrealxDP <= ResIxDP;
-- 				PimagxDP <= ResQxDP;
-- 			end if;
-- 		end if;
-- 	end process;
-- 	
-- 
-- 	------------------------------------------------
-- 	--	Output Assignment
-- 	------------------------------------------------
-- 	ARdyxSO		<= IQRdyAxSP;
-- 	BRdyxSO		<= IQRdyBxSP;
-- 	PVldxSO		<= IQVldPxSP;
-- 	PrealxDO	<= PrealxDP;
-- 	PimagxDO	<= PimagxDP;
