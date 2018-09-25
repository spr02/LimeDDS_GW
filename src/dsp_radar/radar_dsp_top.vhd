library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity radar_dsp is
	generic(
		IQ_WIDTH_IN		: integer := 12;
		IQ_WIDTH_OUT	: integer := 12
	);
	port(
		ClkxCI		: in  std_logic;
		RstxRBI		: in  std_logic;
		
		
		RxValxSI	: in  std_logic;
		RxRdyxSO	: out std_logic;
		RxIxDI		: in  std_logic_vector((IQ_WIDTH_IN - 1) downto 0);
		RxQxDI		: in  std_logic_vector((IQ_WIDTH_IN - 1) downto 0);
		
		TxVldxSI	: in  std_logic;
		TxRdyxSO	: out std_logic;
		TxIxDI		: in  std_logic_vector((IQ_WIDTH_IN - 1) downto 0);
		TxQxDI		: in  std_logic_vector((IQ_WIDTH_IN - 1) downto 0);
		
		OutValxSO 	: out std_logic;
		OutRdyxSI	: in  std_logic;
		IxDO		: out std_logic_vector((IQ_WIDTH_OUT - 1) downto 0);
		QxDO		: out std_logic_vector((IQ_WIDTH_OUT - 1) downto 0)
		
	);
end radar_dsp;

architecture arch of radar_dsp is

	signal RxFifoVldxS, RxFifoRdyxS		: std_logic;
	signal RxFifoIxD, RxFifoQxD			: std_logic_vector((IQ_WIDTH_IN - 1) downto 0);
	
	signal DcVldxS, DcRdyxS				: std_logic;
	signal DcIxD, DcQxD					: std_logic_vector((IQ_WIDTH_OUT - 1) downto 0);
begin

	iqfifo0 : entity work.dds_iqfifo
	generic map(
		IQ_WIDTH	=> IQ_WIDTH_IN
	)
	port map(
		WrClkxCI	=> ClkxCI,
		RstxRBI		=> RstxRBI,
		RdClkxCI	=> ClkxCI,
		WrIxDI		=> RxIxDI,
		WrQxDI		=> RxQxDI,
		WrRdyxSO	=> RxRdyxSO,
		WrValxSI	=> RxValxSI,
		RdIxDO		=> RxFifoIxD,
		RdQxDO		=> RxFifoQxD,
		RdRdyxSI	=> RxFifoRdyxS,
		RdValxSO	=> RxFifoVldxS
	);
	
	
	dc_block0 : entity work.dc_removal
	generic map(
		ALPHA				=> 9,
		IQ_WIDTH_IN		=> IQ_WIDTH_IN,
		IQ_WIDTH_OUT	=> IQ_WIDTH_OUT
	)
	port map(
		ClkxCI		=> ClkxCI,
		RstxRBI		=> RstxRBI,
		
		InValxSI	=> RxFifoVldxS,
		InRdyxSO	=> RxFifoRdyxS,
		IxDI		=> RxFifoIxD,
		QxDI		=> RxFifoQxD,
-- 		InValxSI	=> RxValxSI,
-- 		InRdyxSO	=> RxRdyxSO,
-- 		IxDI		=> RxIxDI,
-- 		QxDI		=> RxQxDI,
		
		OutValxSO 	=> DcVldxS,
		OutRdyxSI	=> DcRdyxS,
		IxDO		=> DcIxD,
		QxDO		=> DcQxD
--  		OutValxSO 	=> OutValxSO,
--  		OutRdyxSI	=> OutRdyxSI,
--  		IxDO		=> IxDO,
--  		QxDO		=> QxDO
	);
	
	cplx_mul0 : entity work.cplx_mul
	generic map(
		A_WIDTH		=> IQ_WIDTH_OUT,
		B_WIDTH		=> IQ_WIDTH_IN,
		P_WIDTH		=> IQ_WIDTH_OUT
	)
	port map(
		ClkxCI		=> ClkxCI,
		RstxRBI	 	=> RstxRBI,
		EnablexSI	=> '1',
		-- rx data
		AVldxSI		=> DcVldxS,
		ARdyxSO		=> DcRdyxS,
		ArealxDI	=> DcIxD,
		AimagxDI	=> DcQxD,
		-- tx data
		BVldxSI		=> TxVldxSI,
		BRdyxSO		=> TxRdyxSO,
		BrealxDI	=> TxQxDI,
		BimagxDI	=> TxIxDI,
		-- out
		PVldxSO		=> OutValxSO,
		PRdyxSI		=> OutRdyxSI,
		PrealxDO	=> IxDO,
		PimagxDO	=> QxDO
	);
	
	
	--TxRdyxSO 	<= '1';
end architecture arch;
