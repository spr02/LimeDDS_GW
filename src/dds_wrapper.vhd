-- ----------------------------------------------------------------------------	
-- FILE:	dds_core.vhd
-- DESCRIPTION:	Serial configuration interface to control DDS and signal generator modules
-- DATE:	December 24, 2017
-- AUTHOR(s):	Jannik Springer (jannik.springer@rwth-aachen.de)
-- REVISIONS:	
-- ----------------------------------------------------------------------------	


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.helper_util.all;


entity dds_wrapper is
	generic(
		LUT_DEPTH		: integer := 8;		-- number of lut address bits
		LUT_AMPL_PREC	: integer := 16;	-- number of databits stored in LUT for amplitude
		LUT_GRAD_PREC	: integer := 5;		-- number of databist stored in LUT for gradient (slope)
		PHASE_WIDTH		: integer := 32;	-- number of bits of phase accumulator
		LFSR_WIDTH		: integer := 32;	-- number of bits used for the LFSR/PNGR
	   LFSR_POLY      : std_logic_vector := "111"; -- polynomial of the LFSR/PNGR
		LFSR_SEED		: integer := 12364;	-- seed for LFSR
		OUT_WIDTH		: integer := 12		-- number of bits actually output (should be equal to DAC bits)
	);
	port(
		ClkxCI				: in  std_logic; -- either MCLK2RX_pll_d (RX) or lmlclk (TX)
		RstxRBI				: in  std_logic; -- eirther stream_rxen_fx3clk (RX) or mclk1tx_locked (TX)
		RxClkxCI				: in  std_logic;
		
		EnablexSI			: in  std_logic;
		
		--------- lime signals---------
		mimo_en				: in  std_logic;
		ddr_en				: in  std_logic;
		ch_en					: in  std_logic_vector(1 downto 0);
		-------------------------------
		
		TaylorEnxSI			: in  std_logic;
		
		TruncDithEnxSI		: in std_logic;
		
		PhaseDithEnxSI		: in  std_logic;
		PhaseDithMasksxSI	: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		PhixDI				: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		SweepEnxSI			: in  std_logic;
		SweepUpDonwxSI		: in  std_logic;
		SweepRatexDI		: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		TopFTWxDI			: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);		
		BotFTWxDI			: in  std_logic_vector((PHASE_WIDTH - 1) downto 0);
		
		dds_data_h			: out std_logic_vector(OUT_WIDTH downto 0);
		dds_data_l			: out std_logic_vector(OUT_WIDTH downto 0);
		
		
		dds_rx_h				: out std_logic_vector(OUT_WIDTH downto 0);
		dds_rx_l				: out std_logic_vector(OUT_WIDTH downto 0)
	);
end dds_wrapper;



architecture arch of dds_wrapper is
	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------

	-- syncronize inputs
	signal SyncFTWxD				: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	signal SyncTaylorEnxS		: std_logic;
	signal SyncTruncDithEnxS	: std_logic;
	signal SyncPhaseDithEnxS	: std_logic;
	signal SyncPhaseDithMasksxS: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	
	-- enable signal
	signal EnablexS				: std_logic;
	
	-- sweep signals
	signal SyncSweepEnxS			: std_logic;
	signal SyncSweepUpDownxS	: std_logic;
	
	signal SyncSweepRatexD		: std_logic_vector((PHASE_WIDTH - 1) downto 0);	
	signal SyncTopFTWxD			: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	signal SyncBotFTWxD			: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	
	-- ouput signals
	signal ValidxS					: std_logic;
	signal PhixD					: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	signal IxD						: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal QxD						: std_logic_vector((OUT_WIDTH - 1) downto 0);
	
	-- rx sync fifo
	signal RstxRBI_sync			: std_logic;
	signal SyncFifoInxD			: std_logic_vector(2*OUT_WIDTH downto 0);
	signal SyncFifoOutxD			: std_logic_vector(2*OUT_WIDTH downto 0);
begin
	------------------------------------------------------------------------------------------------
	--	Instantiate Components
	------------------------------------------------------------------------------------------------
	
	sync_reg0 : entity work.sync_reg
	port map (ClkxCI, '1', TaylorEnxSI, SyncTaylorEnxS);
	
	sync_reg1 : entity work.sync_reg
	port map (ClkxCI, '1', TruncDithEnxSI, SyncTruncDithEnxS);
	
	sync_reg2 : entity work.sync_reg
	port map (ClkxCI, '1', PhaseDithEnxSI, SyncPhaseDithEnxS);
	
	sync_reg3 : entity work.sync_reg
	port map (ClkxCI, '1', SweepEnxSI, SyncSweepEnxS);
	
	sync_reg4 : entity work.sync_reg
	port map (ClkxCI, '1', SweepUpDonwxSI, SyncSweepUpDownxS);
	
	bus_sync_reg0 : entity work.bus_sync_reg
	generic map (32)
	port map(ClkxCI, '1', SweepRatexDI, SyncSweepRatexD);
	
	bus_sync_reg1 : entity work.bus_sync_reg
	generic map (32)
	port map(ClkxCI, '1', TopFTWxDI, SyncTopFTWxD);
	
	bus_sync_reg2 : entity work.bus_sync_reg
	generic map (32)
	port map(ClkxCI, '1', BotFTWxDI, SyncBotFTWxD);
	
	DDS0 : entity work.dds
	generic map(
		LUT_DEPTH		=> LUT_DEPTH,
		LUT_AMPL_PREC	=> LUT_AMPL_PREC,
		LUT_GRAD_PREC	=> LUT_GRAD_PREC,
		PHASE_WIDTH		=> PHASE_WIDTH,
		GRAD_WIDTH		=> 17,
		LFSR_WIDTH		=> LFSR_WIDTH,
	   LFSR_POLY      => LFSR_POLY,
		LFSR_SEED		=> LFSR_SEED,
		OUT_WIDTH		=> OUT_WIDTH
	)
	port map(
		ClkxCI				=> ClkxCI,
		RstxRBI				=> RstxRBI,
		EnablexSI			=> EnablexS,
		TaylorEnxSI			=> SyncTaylorEnxS,
		TruncDithEnxSI		=> SyncTruncDithEnxS,
		PhaseDithEnxSI		=> SyncPhaseDithEnxS,
		PhaseDithMasksxSI	=> "00000000001111111111111111111111",
		SweepEnxSI			=> SyncSweepEnxS,
		SweepUpDownxSI		=> SyncSweepUpDownxS,
		SweepRatexDI		=> SyncSweepRatexD,
		TopFTWxDI			=> SyncTopFTWxD,
		BotFTWxDI			=> SyncBotFTWxD,
--		FTWxDI				=> SyncBotFTWxD,
		PhixDI				=> PhixDI,
		ValidxSO				=> ValidxS,
		PhixDO				=> PhixD,
		QxDO					=> QxD,
		IxDO					=> IxD
	);

	sync_reg5 : entity work.sync_reg
	port map (ClkxCI, '1', RstxRBI, RstxRBI_sync);
	
	SyncFifoInxD	<= ValidxS & QxD & IxD;
	
	sync_fifo_rw_inst : entity work.sync_fifo_rw
	generic map( 
		dev_family  => "Cyclone IV E",
		data_w      => 2*OUT_WIDTH+1
	)
	port map(
		--input ports 
      wclk         => ClkxCI,      
		rclk         => RxClkxCI,
      reset_n      => RstxRBI,
      sync_en      => RstxRBI_sync,
      sync_data    => SyncFifoInxD,
      sync_q       => SyncFifoOutxD
   );
	
	------------------------------------------------------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
    -- ProcessName: p_sync_gen_enable
    -- This process generates the enable signal
    --------------------------------------------
 	p_sync_gen_enable : process(ClkxCI, RstxRBI)
 	begin
 		if RstxRBI = '0' then
 			EnablexS		<= '0';
 		elsif ClkxCI'event and ClkxCI = '1' then
 			EnablexS		<= not EnablexS;
 		end if;
 	end process;
 	
	
	--------------------------------------------
    -- ProcessName: p_sync_registers
    -- This process implements some registers to delay or syncronize data.
    --------------------------------------------
-- 	p_sync_registers : process(ClkxCI, RstxRBI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			Lut0AmplIxDP	<= (others => '0');
-- 			CorrIxDP		<= (others => '0');
-- 			IxDP			<= (others => '0');
-- 			Lut0AmplQxDP	<= (others => '0');
-- 			CorrQxDP		<= (others => '0');
-- 			QxDP			<= (others => '0');
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			Lut0AmplIxDP	<= Lut0AmplIxDN;
-- 			CorrIxDP		<= CorrIxDN;
-- 			IxDP			<= IxDN;
-- 			Lut0AmplQxDP	<= Lut0AmplQxDN;
-- 			CorrQxDP		<= CorrQxDN;
-- 			QxDP			<= QxDN;
-- 		end if;
-- 	end process p_sync_registers;
	

	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------

	--------------------------------------------
	-- ProcessName: p_comb_phase_accumulator_logic
	-- This process implements the accumulator logic with an optional addition of dithering noise.
	--------------------------------------------
-- 	p_comb_phase_accumulator_logic : process(PhaseAccxDP, FTWxDI, PhaseDithgEnxSI, PhaseDithMasksxSI, DitherNoisexD)
-- 		variable PhaseAcc		: unsigned((PhaseAccxDP'length - 1) downto 0);
-- 		variable Ftw			: unsigned((FTWxDI'length - 1) downto 0);
-- 		variable DitherNoise 	: unsigned((DitherNoisexD'length - 1) downto 0);
-- 	begin
-- 		PhaseAcc	:= unsigned(PhaseAccxDP);
-- 		Ftw			:= unsigned(FTWxDI);
-- 		DitherNoise	:= unsigned(PhaseDithMasksxSI and DitherNoisexD);
-- 		
-- 		if (PhaseDithgEnxSI = '1') then
-- 			PhaseAcc := PhaseAcc + Ftw + DitherNoise;
-- 		else
-- 			PhaseAcc := PhaseAcc + Ftw;
-- 		end if;
-- 		
-- 		PhaseAccxDN <= std_logic_vector(PhaseAcc);
-- 	end process p_comb_phase_accumulator_logic;


	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	-- receive!!
	--dds_data_h		<= ValidxS & QxD;
	--dds_data_l		<= ValidxS & IxD;
	
	--dds_data_h	<= ValidxS & "000000000000"; -- imag part
	--dds_data_l	<= ValidxS & "000000001111"; -- real part
	-- 000000001111  -> reads as 240
	
	dds_rx_h			<= SyncFifoOutxD(2*OUT_WIDTH) & SyncFifoOutxD((2*OUT_WIDTH - 1) downto OUT_WIDTH);
	dds_rx_l			<= SyncFifoOutxD(2*OUT_WIDTH) & SyncFifoOutxD((OUT_WIDTH-1) downto 0);
	
	--dds_rx_h			<= (others => '0');
	--dds_rx_l			<= (others => '0');
	
	-- receive!!
	dds_data_h		<= ValidxS & IxD;
	dds_data_l		<= ValidxS & QxD;

end arch;
