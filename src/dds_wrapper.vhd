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
		SCALE_WIDTH		: integer := 3;	-- number of bits for the scale factor (max = 1/(2^SCALE_WIDTH - 1))
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
		
		ScalexDI				: in  std_logic_vector((SCALE_WIDTH - 1) downto 0);
		TxValidInvxSI		: in  std_logic;
		RxValidInvxSI		: in  std_logic;
		
		
		
		
		dds_data_h			: out std_logic_vector(OUT_WIDTH downto 0);
		dds_data_l			: out std_logic_vector(OUT_WIDTH downto 0);
		
		--DDSRxValidxS		: out std_logic;
		
		-- AXIS interface for receive part (mixer)
		o_dds_rx_i			: out std_logic_vector((OUT_WIDTH - 1) downto 0);
		o_dds_rx_q			: out std_logic_vector((OUT_WIDTH - 1) downto 0);
		i_dds_rx_rdy		: in  std_logic;
		o_dds_rx_vld		: out std_logic;
		
		-- AXIS interface for transpitter part (output to LMS7002)
		o_dds_tx_i			: out std_logic_vector((OUT_WIDTH - 1) downto 0);
		o_dds_tx_q			: out std_logic_vector((OUT_WIDTH - 1) downto 0);
		i_dds_tx_rdy		: in  std_logic;
		o_dds_tx_vld		: out std_logic
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
	signal SyncScalexS			: std_logic_vector((SCALE_WIDTH - 1) downto 0);
	signal SyncTxValidInvxS		: std_logic;
	signal SyncRxValidInvxS		: std_logic;
	
	-- enable signal
	signal EnablexS				: std_logic;
	
	-- sweep signals
	signal SyncSweepEnxS			: std_logic;
	signal SyncSweepUpDownxS	: std_logic;
	
	signal SyncSweepRatexD		: std_logic_vector((PHASE_WIDTH - 1) downto 0);	
	signal SyncTopFTWxD			: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	signal SyncBotFTWxD			: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	
	-- full scale DDS output
	signal SyncScalexD			: std_logic_vector((SCALE_WIDTH -1) downto 0);
	signal FullScaleIxD			: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal FullScaleQxD			: std_logic_vector((OUT_WIDTH - 1) downto 0);
	
	-- ouput signals
	signal ValidxS					: std_logic;
	signal TxValidxSP				: std_logic;
	signal TxValidxSN				: std_logic;
	signal PhixD					: std_logic_vector((PHASE_WIDTH - 1) downto 0);
	signal IxDP, IxDN				: std_logic_vector((OUT_WIDTH - 1) downto 0);
	signal QxDP, QxDN				: std_logic_vector((OUT_WIDTH - 1) downto 0);
	
	-- rx sync fifo
	signal RstxRBI_sync			: std_logic;
	signal SyncFifoInxD			: std_logic_vector(2*OUT_WIDTH downto 0);
	signal SyncFifoOutxD			: std_logic_vector(2*OUT_WIDTH downto 0);
	signal RxValidxS				: std_logic;
	
	signal RxIxDP, RxQxDP		: std_logic_vector((OUT_WIDTH - 1) downto 0);
	
	signal WUsedxD					: std_logic_vector(8 downto 0);
	signal RUsedxD					: std_logic_vector(8 downto 0);
	
	signal WrReqxS					: std_logic;
	signal WrFullxS				: std_logic;
	signal WrQxD					: std_logic_vector((2*OUT_WIDTH - 1) downto 0);
	
	signal RdReqxS					: std_logic;
	signal RdEmptyxS				: std_logic;
	signal RdQxD					: std_logic_vector((2*OUT_WIDTH - 1) downto 0);
begin
	------------------------------------------------------------------------------------------------
	--	Instantiate Components
	------------------------------------------------------------------------------------------------
	
	sync_reg0 : entity work.sync_reg
	port map (ClkxCI, '1', RstxRBI, RstxRBI_sync);
	
	sync_reg1 : entity work.sync_reg
	port map (ClkxCI, '1', TaylorEnxSI, SyncTaylorEnxS);
	
	sync_reg2 : entity work.sync_reg
	port map (ClkxCI, '1', TruncDithEnxSI, SyncTruncDithEnxS);
	
	sync_reg3 : entity work.sync_reg
	port map (ClkxCI, '1', PhaseDithEnxSI, SyncPhaseDithEnxS);
	
	sync_reg4 : entity work.sync_reg
	port map (ClkxCI, '1', SweepEnxSI, SyncSweepEnxS);
	
	sync_reg5 : entity work.sync_reg
	port map (ClkxCI, '1', SweepUpDonwxSI, SyncSweepUpDownxS);
	
	sync_reg6 : entity work.sync_reg
	port map (ClkxCI, '1', TxValidInvxSI, SyncTxValidInvxS);
	
	sync_reg7 : entity work.sync_reg
	port map (ClkxCI, '1', RxValidInvxSI, SyncRxValidInvxS);
	
	
	bus_sync_reg0 : entity work.bus_sync_reg
	generic map (32)
	port map(ClkxCI, '1', SweepRatexDI, SyncSweepRatexD);
	
	bus_sync_reg1 : entity work.bus_sync_reg
	generic map (32)
	port map(ClkxCI, '1', TopFTWxDI, SyncTopFTWxD);
	
	bus_sync_reg2 : entity work.bus_sync_reg
	generic map (32)
	port map(ClkxCI, '1', BotFTWxDI, SyncBotFTWxD);
	
	bus_sync_reg3 : entity work.bus_sync_reg
	generic map(SCALE_WIDTH)
	port map(ClkxCI, '1', ScalexDI, SyncScalexD);
	
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
		QxDO					=> FullScaleQxD,
		IxDO					=> FullScaleIxD
--		QxDO					=> QxD,
--		IxDO					=> IxD
	);

	
			
	--write signals	
	WrReqxS	<= ValidxS and (not WrFullxS);
--	WrReqxS	<= ValidxS;
	WrQxD		<= (FullScaleQxD & FullScaleIxD) when rising_edge(ClkxCI);
--	WrQxD		<= "000" & RUsedxD & "000" & WUsedxD;

--	p_sync_gen_test_data : process(ClkxCI, RstxRBI)
--	begin
--		if (RstxRBI = '0') then
--			WrReqxS <= '0';
--			WrQxD <= (others => '0');
--		else
--			if rising_edge(ClkxCI) then
--				if WrReqxS = '0' and WrFullxS = '0' then
--					WrReqxS	<= '1';
--					WrQxD		<= std_logic_vector(unsigned(WrQxD) + 1);
--				else
--					WrReqxS	<= '0';
--				end if;
--			end if;
--		end if;
--	end process;
	
	--read signals
	RdReqxS	<= i_dds_rx_rdy and (not RdEmptyxS);
	--https://www.altera.com/en_US/pdfs/literature/ug/ug_fifo.pdf
	--For show-ahead mode, the FIFO Intel FPGA IP core treats the rdreq port as a read-acknowledge 
	--that automatically outputs the first word of valid data in the FIFO Intel FPGA IP core (when the 
	--empty is low) without asserting the rdreq signal. 
	
	RxIxDP <= FullScaleIxD when rising_edge(ClkxCI);
	RxQxDP <= FullScaleQxD when rising_edge(ClkxCI);
	
	iqfifo0 : entity work.dds_iqfifo
	generic map(
		IQ_WIDTH	=> OUT_WIDTH
	)
	port map(
		WrClkxCI		=> ClkxCI,
		RstxRBI		=> RstxRBI,
		RdClkxCI		=> RxClkxCI,
		WrIxDI		=> RxIxDP,
		WrQxDI		=> RxQxDP,
		WrRdyxSO		=> open,
		WrValxSI		=> ValidxS,
		RdIxDO		=> o_dds_rx_i,
		RdQxDO		=> o_dds_rx_q,
		RdRdyxSI		=> i_dds_rx_rdy,
		RdValxSO		=> o_dds_rx_vld
	);
	
--	rx_fifo0 : entity work.fifo_inst
--	generic map(
--		dev_family	    => "Cyclone IV E",
--		wrwidth         => 2*OUT_WIDTH,
--		wrusedw_witdth  => 9,
--		rdwidth         => 2*OUT_WIDTH,
--		rdusedw_width   => 9,
--		show_ahead      => "OFF"
--	)
--	port map( 
--		reset_n    => RstxRBI,
--		wrclk      => ClkxCI,
--		wrreq      => WrReqxS,
--		data       => WrQxD,
--		wrfull     => WrFullxS,
--		wrempty	  => open,
--		wrusedw    => WUsedxD,
--		rdclk 	  => RxClkxCI,
--		rdreq      => RdReqxS,
--		q          => RdQxD,
--		rdempty    => RdEmptyxS,
--		rdusedw    => RUsedxD  
--	);

--	dcfifo_mixed_widths_component : dcfifo_mixed_widths
--	GENERIC MAP (
--		add_usedw_msb_bit       => "ON",
--		intended_device_family  => dev_family,
--		lpm_numwords            => 2**(wrusedw_witdth-1),
--		lpm_showahead           => show_ahead,
--		lpm_type                => "dcfifo_mixed_widths",
--		lpm_width               => wrwidth,
--		lpm_widthu              => wrusedw_witdth,
--		lpm_widthu_r            => rdusedw_width,
--		lpm_width_r             => rdwidth,
--		overflow_checking       => "ON",
--		rdsync_delaypipe        => 4,
--		read_aclr_synch         => "OFF",
--		underflow_checking      => "ON",
--		use_eab                 => "ON",
--		write_aclr_synch        => "OFF",
--		wrsync_delaypipe        => 4
--	)
--	PORT MAP (
--		aclr    	=> aclr,
--		data    	=> data,
--		rdclk   	=> rdclk,
--		rdreq   	=> rdreq,
--		wrclk   	=> wrclk,
--		wrreq   	=> wrreq,
--		q       	=> q,
--		rdempty 	=> rdempty,
--		rdusedw 	=> rdusedw,
--		wrempty	=> wrempty,
--		wrfull  	=> wrfull,
--		wrusedw	=> wrusedw
--	);

	--SyncFifoInxD	<= ValidxS & QxD & IxD;
--	SyncFifoInxD <= ValidxS & FullScaleQxD & FullScaleIxD;
--	
--	sync_fifo_rw_inst : entity work.sync_fifo_rw
--	generic map( 
--		dev_family  => "Cyclone IV E",
--		data_w      => 2*OUT_WIDTH+1
--	)
--	port map(
--		--input ports 
--      wclk         => ClkxCI,      
--		rclk         => RxClkxCI,
--      reset_n      => RstxRBI,
--      sync_en      => RstxRBI_sync,
--      sync_data    => SyncFifoInxD,
--      sync_q       => SyncFifoOutxD
--   );
	
	------------------------------------------------------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------------------------------------------------------
	
	--DDS core is throtteled by ready signal of transmit AXIS interface
	EnablexS <= EnablexSI and i_dds_tx_rdy;
	
	
	--------------------------------------------
    -- ProcessName: p_sync_gen_enable
    -- This process generates the enable signal
    --------------------------------------------
-- 	p_sync_gen_enable : process(ClkxCI, RstxRBI)
-- 	begin
-- 		if RstxRBI = '0' then
-- 			EnablexS		<= '0';
-- 		elsif ClkxCI'event and ClkxCI = '1' then
-- 			EnablexS		<= not EnablexS;
-- 		end if;
-- 	end process;
 	
	
	--------------------------------------------
	-- ProcessName: p_sync_registers
	-- This process implements some registers to delay or syncronize data.
	--------------------------------------------
 	p_sync_registers : process(ClkxCI, RstxRBI)
 	begin
 		if RstxRBI = '0' then
 			IxDP			<= (others => '0');
 			QxDP			<= (others => '0');
			TxValidxSP	<= '0';
 		elsif ClkxCI'event and ClkxCI = '1' then
 			IxDP			<= IxDN;
			QxDP			<= QxDN;
			TxValidxSP	<= TxValidxSN;
 		end if;
 	end process p_sync_registers;
	

	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------
	
	--scale the DDS outputs by a factor of 1/ScalexDI
	--QxD <= std_logic_vector(shift_right(signed(FullScaleQxD), to_integer(unsigned(ScalexDI))));
	--IxD <= std_logic_vector(shift_right(signed(FullScaleIxD), to_integer(unsigned(ScalexDI))));

	--------------------------------------------
	-- ProcessName: p_comb_scale
	-- This process implements two multiplier, used to scale the generated amplitued.
	-- Note that the fixed point formats of the signals are:
	-- FullScaleIxD/FullScaleQxD: <OUT_WIDTH.0> (signed)
	-- SyncScalexD: <1.SCALE_WIDTH-1> (unsigned)
	-- AmplScalexD: <2.SCALE_WIDTH-1> (signed)
	--------------------------------------------
	p_comb_scale : process(FullScaleIxD, FullScaleQxD, SyncScalexD)
		constant MSB_POS		: integer := OUT_WIDTH + SCALE_WIDTH - 2;
		constant LSB_POS		: integer := SCALE_WIDTH - 1;
		variable AmplScalexD	: signed(SCALE_WIDTH downto 0);
		variable AmplIxD		: signed((OUT_WIDTH - 1) downto 0);
		variable AmplQxD		: signed((OUT_WIDTH - 1) downto 0);
		variable ScaledIxD	: signed((OUT_WIDTH + SCALE_WIDTH) downto 0);
		variable ScaledQxD	: signed((OUT_WIDTH + SCALE_WIDTH) downto 0);
	begin
		AmplScalexD		:= signed("0" & SyncScalexD);
		AmplIxD			:= signed(FullScaleIxD);
		AmplQxD			:= signed(FullScaleQxD);
		
		ScaledIxD		:= AmplIxD * AmplScalexD;
		ScaledQxD		:= AmplQxD * AmplScalexD;

		IxDN				<= std_logic_vector(ScaledIxD(MSB_POS downto LSB_POS));
		QxDN				<= std_logic_vector(ScaledQxD(MSB_POS downto LSB_POS));
	end process;

	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	-- receive!!
	--dds_data_h		<= ValidxS & QxD;
	--dds_data_l		<= ValidxS & IxD;
	
	--dds_data_h	<= ValidxS & "000000000000"; -- imag part
	--dds_data_l	<= ValidxS & "000000001111"; -- real part
	-- 000000001111  -> reads as 240
	
--	RxValidxS		<= SyncFifoOutxD(2*OUT_WIDTH) when SyncRxValidInvxS = '0' else not SyncFifoOutxD(2*OUT_WIDTH);
--	dds_rx_h			<= RxValidxS & SyncFifoOutxD((2*OUT_WIDTH - 1) downto OUT_WIDTH);
--	dds_rx_l			<= RxValidxS & SyncFifoOutxD((OUT_WIDTH-1) downto 0);
	
	--RxValidxS		<= ValidxS;
--	dds_rx_h			<= "0" & FullScaleIxD;
--	dds_rx_l			<= "0" & FullScaleQxD;
	
	--DDSRxValidxS	<= RxValidxS;
	----------------------------------------------------------------------------
	--TODO clean up until these are the only interfaces!!
	
--	o_dds_rx_vld		<= not RdEmptyxS; -- since we have show ahead enabled, otherwise this would be 1cc delay rd_req
--	o_dds_rx_vld		<= RdReqxS when rising_edge(RxClkxCI);
--	o_dds_rx_i			<= RdQxD((OUT_WIDTH - 1) downto 0);
--	o_dds_rx_q			<= RdQxD((2*OUT_WIDTH - 1) downto OUT_WIDTH);
	
	--dds_rx_h			<= (others => '0');
	--dds_rx_l			<= (others => '0');
	
--	TxValidxSN		<= ValidxS when SyncTxValidInvxS = '0' else not ValidxS;
--	TxValidxSN		<= ValidxS;
	o_dds_tx_vld		<= ValidxS;
	o_dds_tx_i			<= IxDP;
	o_dds_tx_q			<= QxDP;
	------------------------------------------------------------------------
	-- receive!!
	dds_data_h		<= TxValidxSP & IxDP;
	dds_data_l		<= TxValidxSP & QxDP;
end arch;
