library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- avg = avg + alpha * (x - avg)
-- y = x - avg

--or simply: y = x - offs

entity dc_removal is
	generic(
		ALPHA				: integer := 8;
		IQ_WIDTH_IN		: integer := 12;
		IQ_WIDTH_OUT	: integer := 12
	);
	port(
		ClkxCI		: in  std_logic;
		RstxRBI		: in  std_logic;
		
		
		--AutoxSI		: in  std_logic;
		
		--IOffsxDI	: in  std_logic_vector((IQ_WIDTH - 1) downto 0);
		--QOffsxDI	: in  std_logic_vector((IQ_WIDTH - 1) downto 0);
		
		InValxSI	: in  std_logic;
		InRdyxSO	: out std_logic;
		IxDI		: in  std_logic_vector((IQ_WIDTH_IN - 1) downto 0);
		QxDI		: in  std_logic_vector((IQ_WIDTH_IN - 1) downto 0);
		
		OutValxSO 	: out std_logic;
		OutRdyxSI	: in  std_logic;
		IxDO		: out std_logic_vector((IQ_WIDTH_OUT - 1) downto 0);
		QxDO		: out std_logic_vector((IQ_WIDTH_OUT - 1) downto 0)
		
	);
end dc_removal;

architecture arch of dc_removal is
	constant C_SHIFT : integer := IQ_WIDTH_OUT - IQ_WIDTH_IN;
	
	--DC offset values for I and Q
	signal DcIxDP, DcIxDN		: signed((IQ_WIDTH_OUT + ALPHA - 1) downto 0);
	signal DcQxDP, DcQxDN		: signed((IQ_WIDTH_OUT + ALPHA - 1) downto 0);
	
	signal DiffIxDP, DiffIxDN	: signed((IQ_WIDTH_OUT - 1) downto 0);
	signal DiffQxDP, DiffQxDN	: signed((IQ_WIDTH_OUT - 1) downto 0);
	
begin
	

-- 	DRdxS <= DVldxSI and DRdyxSP; -- D (input) is read
-- 	QRdxS <= QVldxSP and QRdyxSI; -- Q (output) is read
-- 	BEnxS <= DRdxS and (QVldxSP and not QRdyxSI); -- store input to temporary buffer B
-- 	p_axis_ctl : process(ClkxCI, RstxRBI)
-- 	begin
-- 		if (RstxRBI = '0') then
-- 			DRdyxSP <= '0';
-- 			BVldxSP <= '0';
-- 			QVldxSP <= '0';
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			DRdyxSP <= (QRdyxSI or not QVldxSP) or (DRdyxSP and (not DRdxS));
-- 			BVldxSP <= BEnxS or (BVldxSP and (not QRdxS));
-- 			QVldxSP <= (DRdxS or (QRdxS and BVldxSP)) or (QVldxSP and (not QRdyxSI));
-- 		end if;
-- 	end process;
-- 	
-- 	
-- 	p_axis_data : process(ClkxCI, RstxRBI)
-- 	begin
-- 		if (RstxRBI = '0') then
-- 			BxDP <= (others => '0');
-- 			QxDP <= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
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
	
	p_sync_register : process(ClkxCI, RstxRBI)
	begin
		if (RstxRBI = '0') then
			DcIxDP		<= (others => '0');
			DcQxDP		<= (others => '0');
			DiffIxDP	<= (others => '0');
			DiffQxDP	<= (others => '0');
		elsif (ClkxCI = '1' and ClkxCI'event) then
			if InValxSI = '1' then
				DcIxDP		<= DcIxDN;
				DcQxDP		<= DcQxDN;
				DiffIxDP	<= DiffIxDN;
				DiffQxDP	<= DiffQxDN;
			end if;
		end if;
	end process;
	
	DiffIxDN <= signed(IxDI & "0000") - signed(DcIxDP(DcIxDP'left downto DcIxDP'left - IQ_WIDTH_OUT + 1));
	DiffQxDN <= signed(QxDI & "0000") - signed(DcQxDP(DcQxDP'left downto DcQxDP'left - IQ_WIDTH_OUT + 1));
	
-- 	DiffIxDN <= shift_right(resize(IxDI, DiffIxDN'length), C_SHIFT) - signed(DcIxDP(DcIxDP'left downto DcIxDP'left - IQ_WIDTH_OUT + 1));
-- 	DiffQxDN <= shift_right(resize(QxDI, DiffQxDN'length), C_SHIFT) - signed(DcQxDP(DcQxDP'left downto DcQxDP'left - IQ_WIDTH_OUT + 1));

	DcIxDN <= signed(DcIxDP) + resize(signed(DiffIxDP), IQ_WIDTH_OUT + ALPHA);
	DcQxDN <= signed(DcQxDP) + resize(signed(DiffQxDP), IQ_WIDTH_OUT + ALPHA);
	
	IxDO <= std_logic_vector(DiffIxDP);
	QxDO <= std_logic_vector(DiffQxDP);
	
	OutValxSO	<= InValxSI  when rising_edge(ClkxCI);
	InRdyxSO	<= OutRdyxSI when rising_edge(ClkxCI);
	
end architecture arch;
