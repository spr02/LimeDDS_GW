-- ----------------------------------------------------------------------------	
-- FILE:	dds_iq2fifo.vhd
-- DESCRIPTION:	Packs two consecutive IQ words into a fifo word.
-- DATE:	June 5, 2018
-- AUTHOR(s):	Jannik Springer (jannik.springer@rwth-aachen.de)
-- REVISIONS:	
-- ----------------------------------------------------------------------------	


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;


entity dds_iq2fifo is
	generic(
		IQ_WIDTH		: integer := 12
	);
	port(
		ClkxCI			: in  std_logic; -- either MCLK2RX_pll_d (RX) or lmlclk (TX)
		RstxRBI			: in  std_logic; -- eirther stream_rxen_fx3clk (RX) or mclk1tx_locked (TX)
		
		IQValxSI		: in  std_logic; --IQ Data valid
		IQRdyxSO		: out std_logic; --ready to accept new IQ data
		IxDI			: in  std_logic_vector((IQ_WIDTH - 1) downto 0);
		QxDI			: in  std_logic_vector((IQ_WIDTH - 1) downto 0);
		
		FifoValxSO		: out std_logic; -- fifo word valid
		FifoRdyxSI		: in  std_logic; -- fifo is ready to accept new data
		FifoQxDO		: out std_logic_vector((4*IQ_WIDTH-1) downto 0)
	);
end dds_iq2fifo;


architecture arch of dds_iq2fifo is
	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------
	subtype Pos0Range		is natural range (1*IQ_WIDTH - 1) downto 0*IQ_WIDTH;
	subtype Pos1Range		is natural range (2*IQ_WIDTH - 1) downto 1*IQ_WIDTH;
	subtype Pos2Range		is natural range (3*IQ_WIDTH - 1) downto 2*IQ_WIDTH;
	subtype Pos3Range		is natural range (4*IQ_WIDTH - 1) downto 3*IQ_WIDTH;
	

	signal FifoRdyxSP, FifoRdyxSN	: std_logic;
	signal FifoValxSP				: std_logic;
	signal FifoStatusxSP, FifoStatusxSN	: std_logic;
	
	

	signal IQBufxDP					: std_logic_vector((2*IQ_WIDTH - 1) downto 0);
	signal IQValxSP					: std_logic;
	signal IQEnxS					: std_logic;
	
	
	
	signal IQAxDP, IQBxDP			: std_logic_vector((2*IQ_WIDTH - 1) downto 0);
	
	signal IQRdyxSP					: std_logic;
	
	
	signal IQValAxSP				: std_logic;
	signal IQEnAxS					: std_logic;
	
	signal IQValBxSP				: std_logic;
	signal IQEnBxS					: std_logic;
	
	signal FifoEnxS					: std_logic;
	signal FifoValxS				: std_logic;
begin

	------------------------------------------------------------------------------------------------
	--	Synchronus processes (data signals)
	------------------------------------------------------------------------------------------------
	
	--input buffer, to compensate delay of rdy
	p_sync_process_iq_buf : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQBufxDP <= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			if IQEnxS = '1' then
				IQBufxDP <= QxDI & IxDI;
			end if;
		end if;
	end process;
	
	--output buffer for position A
	p_sync_process_iq_a : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQAxDP <= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			if IQEnAxS = '1' then
				if IQValxSP = '0' then
					IQAxDP <= QxDI & IxDI;
				else
					IQAxDP <= IQBufxDP;
				end if;
			end if;
		end if;
	end process;
	
	--output buffer for position B
	p_sync_process_iq_b : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQBxDP <= (others => '0');
		elsif ClkxCI'event and ClkxCI = '1' then
			if IQEnBxS = '1' then
				IQBxDP <= QxDI & IxDI;
			end if;
		end if;
	end process;
	
	------------------------------------------------------------------------------------------------
	--	Synchronus processes (control signals)
	------------------------------------------------------------------------------------------------
	-- generate ready signal for IQ input
	p_sync_gen_rdy : process (RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQRdyxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
-- 			IQRdyxSP <= ((not IQValAxSP and not IQValBxSP) or (FifoRdyxSI and FifoValxS)) or (IQRdyxSP and not (IQValAxSP and IQValBxSP and not FifoRdyxSI));
			IQRdyxSP <= ((not IQValAxSP and not IQValBxSP) or (FifoRdyxSI and FifoValxS)) or (IQRdyxSP and not (FifoValxS and not FifoRdyxSI));
		end if;
	end process;
	
	-- generate valid signal for output buffer in position A
	p_sync_gen_val_a : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQValAxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			IQValAxSP <= IQEnAxS or (IQValAxSP and not (FifoRdyxSI and FifoValxS));
		end if;
	end process;
	
	-- generate valid signal for output buffer in position B
	p_sync_gen_val_b : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQValBxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			IQValBxSP <= IQEnBxS or (IQValBxSP and not (FifoRdyxSI and FifoValxS));
		end if;
	end process;
	
	-- generate valid signal for internal IQ buffer
	p_sync_process_iq_buf_val : process(RstxRBI, ClkxCI)
	begin
		if RstxRBI = '0' then
			IQValxSP <= '0';
		elsif ClkxCI'event and ClkxCI = '1' then
			IQValxSP <= (IQEnxS and FifoValxS and not FifoRdyxSI) or (IQValxSP and not IQEnAxS);
		end if;
	end process;
	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------

	-- enable signals for IQ interface
	IQEnxS	<= IQValxSI and IQRdyxSP;
	IQEnAxS <= ((IQEnxS and not IQValAxSP and not IQValBxSP) or ((IQValxSP or IQEnxS) and FifoValxS and FifoRdyxSI));
	IQEnBxS	<= IQValxSI and IQValAxSP and not IQValBxSP;
	
	-- valid signal for FIFO interface
	FifoValxS <= IQValAxSP and IQValBxSP;
	
	
	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	IQRdyxSO	<= IQRdyxSP;
	FifoValxSO	<= FifoValxS;
	FifoQxDO	<= IQBxDP & IQAxDP;

end arch;
