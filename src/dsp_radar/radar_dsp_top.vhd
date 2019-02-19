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
	
	signal TxComplementQxD				: std_logic_vector((IQ_WIDTH_IN - 1) downto 0);
	
	signal DcVldxS, DcRdyxS				: std_logic;
	signal DcIxD, DcQxD					: std_logic_vector((IQ_WIDTH_OUT - 1) downto 0);
	
	signal MulVldxS, MulRdyxS			: std_logic;
	signal MulIxD, MulQxD				: std_logic_vector((IQ_WIDTH_OUT - 1) downto 0);
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
	
	p_comb_complement : process(TxQxDI)
		variable v_complement : std_logic_vector((TxQxDI'length - 1) downto 0);
	begin
		v_complement := not TxQxDI;
		TxComplementQxD <= std_logic_vector(signed(v_complement) + 1);
	end process;
	
	cplx_mul0 : entity work.cplx_mul
	generic map(
		A_WIDTH		=> IQ_WIDTH_OUT,
		B_WIDTH		=> IQ_WIDTH_IN,
		P_WIDTH		=> IQ_WIDTH_OUT,
		FSR_SHIFT	=> 0
	)
	port map(
		ClkxCI		=> ClkxCI,
		RstxRBI	 	=> RstxRBI,
		EnablexSI	=> '1',
		-- rx data
		AVldxSI		=> DcVldxS,
		ARdyxSO		=> DcRdyxS,
-- 		ArealxDI		=> std_logic_vector(to_signed(2, IQ_WIDTH_OUT)),
-- 		AimagxDI		=> std_logic_vector(to_signed(0, IQ_WIDTH_OUT)),
		ArealxDI	=> DcIxD,
		AimagxDI	=> DcQxD,
		-- tx data
		BVldxSI		=> TxVldxSI,
		BRdyxSO		=> TxRdyxSO,
		BrealxDI	=> TxIxDI,
		BimagxDI	=> TxComplementQxD,
		-- out
		PVldxSO		=> MulVldxS,
		PRdyxSI		=> MulRdyxS,
		PrealxDO	=> MulIxD,
		PimagxDO	=> MulQxD
-- 		PVldxSO		=> OutValxSO,
-- 		PRdyxSI		=> OutRdyxSI,
-- 		PrealxDO	=> IxDO,
-- 		PimagxDO	=> QxDO
	);
	
	cic_decim_i: entity work.cic_decim
	generic map(
		N	=> 4,
		M	=> 1,
		R	=> 64,
		Bin	=> 16,
		Bout=> 16
	)
	port map(
		ClkxCI		=> ClkxCI,
		RstxRBI		=> RstxRBI,
		ClkEnxSI	=> '1',
		-- multiplier out (dechirped singal)
		ValidxSI	=> MulVldxS,
		ReadyxSO	=> MulRdyxS,
		DataxDI		=> MulIxD,
		-- decimator out
		ValidxSO	=> OutValxSO,
		ReadyxSI	=> OutRdyxSI,
		DataxDO		=> IxDO
	);
	
	cic_decim_q: entity work.cic_decim
	generic map(
		N	=> 4,
		M	=> 1,
		R	=> 64,
		Bin	=> 16,
		Bout=> 16
	)
	port map(
		ClkxCI		=> ClkxCI,
		RstxRBI		=> RstxRBI,
		ClkEnxSI	=> '1',
		-- multiplier out (dechirped singal)
		ValidxSI	=> MulVldxS,
		ReadyxSO	=> open,
		DataxDI		=> MulQxD,
		-- decimator out
		ValidxSO	=> open,
		ReadyxSI	=> OutRdyxSI,
		DataxDO		=> QxDO
	);
	
	
	--TxRdyxSO 	<= '1';
end architecture arch;
