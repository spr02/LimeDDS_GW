-- ----------------------------------------------------------------------------	
-- FILE:	dds_fifo2iq.vhd
-- DESCRIPTION:	Unpacks a fifo word to two IQ words, which are output in serial.
-- DATE:	June 5, 2018
-- AUTHOR(s):	Jannik Springer (jannik.springer@rwth-aachen.de)
-- REVISIONS:	
-- ----------------------------------------------------------------------------	


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
--use work.helper_util.all;




entity dds_fifo2iq is
	generic(
		IQ_WIDTH		: integer := 12
	);
	port(
		ClkxCI			: in  std_logic; -- either MCLK2RX_pll_d (RX) or lmlclk (TX)
		RstxRBI			: in  std_logic; -- eirther stream_rxen_fx3clk (RX) or mclk1tx_locked (TX)
		
		FifoValxSI		: in  std_logic; -- fifo word valid
		FifoRdyxSO		: out std_logic; -- ready to accept new fifo word
		FifoQxDI		: in  std_logic_vector((4*IQ_WIDTH-1) downto 0); 
		
		IQValxSO		: out std_logic; --IQ Data valid
		IQRdyxSI		: in  std_logic; --IQ interface is ready
		IxDO			: out std_logic_vector((IQ_WIDTH - 1) downto 0);
		QxDO			: out std_logic_vector((IQ_WIDTH - 1) downto 0)
	);
end dds_fifo2iq;


architecture arch of dds_fifo2iq is
	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------
	subtype Pos0Range		is natural range (1*IQ_WIDTH - 1) downto 0*IQ_WIDTH;
	subtype Pos1Range		is natural range (2*IQ_WIDTH - 1) downto 1*IQ_WIDTH;
	subtype Pos2Range		is natural range (3*IQ_WIDTH - 1) downto 2*IQ_WIDTH;
	subtype Pos3Range		is natural range (4*IQ_WIDTH - 1) downto 3*IQ_WIDTH;
	

	-- fifo interface and internal buffer
	signal FifoRdyxSP				: std_logic;	-- tied to output
	signal FifoEnxS					: std_logic;	-- enables fifo buffer
	signal FifoBufValxSP			: std_logic;	-- set if buffer holds valid fifo word
	signal FifoInxDP, FifoInxDN		: std_logic_vector((4*IQ_WIDTH - 1) downto 0);

	signal IQValxSP					: std_logic; -- tied to output
	signal IxDP, IxDN				: std_logic_vector((IQ_WIDTH - 1) downto 0);
	signal QxDP, QxDN				: std_logic_vector((IQ_WIDTH - 1) downto 0);
	
	signal IQValAxSP				: std_logic; -- set if I/QxDO currently holds pos A of fifo word (pos 1+2)
	signal IQValBxSP				: std_logic; -- set if I/QxDO currently holds pos B of fifo word (pos 3+4)
	
begin

	------------------------------------------------------------------------------------------------
	--	Synchronus processes (sequential logic and registers)
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
    -- ProcessName: p_sync_regs
    -- This process infers some registers.
    --------------------------------------------
	p_sync_regs : process (ClkxCI, RstxRBI)
	begin
		if RstxRBI = '0' then
			FifoInxDP	<= (others => '0');
			IxDP		<= (others => '0');
			QxDP		<= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			FifoInxDP	<= FifoInxDN;
			IxDP		<= IxDN;
			QxDP		<= QxDN;
		end if;
	end process;
	
	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------

	-- fifi interface
	p_sync_gen_rdy_fifo : process (RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			FifoRdyxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			FifoRdyxSP <= (((not IQValAxSP and not IQValBxSP) or (IQValAxSP and IQRdyxSI)) and not FifoRdyxSP) or (FifoRdyxSP and not FifoValxSI);
		end if;
	end process;
	
	p_sync_gen_val_fifo : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			FifoBufValxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			FifoBufValxSP <= FifoEnxS or (FifoBufValxSP and not (IQRdyxSI and IQValAxSP));
		end if;
	end process;
	
	FifoEnxS	<= FifoRdyxSP and FifoValxSI;
	FifoInxDN	<= FifoQxDI when FifoEnxS = '1' else FifoInxDP;
	
	
	-- iq interface
	p_sync_gen_val_a : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQValAxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			IQValAxSP <= ((FifoEnxS or FifoBufValxSP) and (IQRdyxSI or not IQValBxSP) and not IQValAxSP) or (IQValAxSP and not IQRdyxSI);
-- 			if IQValAxSP = '1' and IQRdyxSI = '1' then
-- 				IQValAxSP <= '0';
-- 			elsif ((FifoEnxS or FifoBufValxSP) and (IQRdyxSI or not IQValBxSP)) = '1' then
-- 				IQValAxSP <= '1';
-- 			end if;
		end if;
	end process;
	
	p_sync_gen_val_b : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQValBxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			IQValBxSP <= (IQValAxSP and IQRdyxSI) or (IQValBxSP and not IQRdyxSI);
		end if;
	end process;
	
	p_sync_gen_iq_val : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQValxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			IQValxSP <= (FifoEnxS or FifoBufValxSP or IQValAxSP) or (IQValBxSP and not IQRdyxSI);
		end if;
	end process;
	
	p_comb_iq_select : process(FifoEnxS, IQRdyxSI, IQValAxSP, IQValBxSP, FifoInxDP, FifoQxDI, IxDP, QxDP)
	begin
		
		if (IQValAxSP = '0' and IQValBxSP = '0') or (FifoEnxS = '1' and IQRdyxSI = '1') then -- FWFT logic
			IxDN		<= FifoQxDI(Pos0Range);
			QxDN		<= FifoQxDI(Pos1Range);
		elsif (IQValAxSP = '1' and IQRdyxSI = '1') then
			IxDN		<= FifoInxDP(Pos2Range);
			QxDN		<= FifoInxDP(Pos3Range);
		elsif (IQValBxSP = '1' and IQRdyxSI = '1') then
			IxDN		<= FifoInxDP(Pos0Range);
			QxDN		<= FifoInxDP(Pos1Range);
		else
			IxDN		<= IxDP;
			QxDN		<= QxDP;
		end if; 
	end process;
	
	
	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	FifoRdyxSO	<= FifoRdyxSP;
	IQValxSO	<= IQValxSP;
	IxDO		<= IxDP;
	QxDO		<= QxDP;

end arch;
