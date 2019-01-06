library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use work.helper_util.all;


entity dds_iqfifo is
	generic(
		IQ_WIDTH			: integer := 12;
		DEPTH				: integer := 3
	);
	port(
		WrClkxCI		: in  std_logic;
		RstxRBI			: in  std_logic;
		RdClkxCI		: in  std_logic;
		
		-- AXIS Input
		WrIxDI			: in  std_logic_vector((IQ_WIDTH - 1) downto 0);
		WrQxDI			: in  std_logic_vector((IQ_WIDTH - 1) downto 0);
		WrRdyxSO		: out std_logic;
		WrValxSI		: in  std_logic;
		
		-- AXIS Output
		RdIxDO			: out std_logic_vector((IQ_WIDTH - 1) downto 0);
		RdQxDO			: out std_logic_vector((IQ_WIDTH - 1) downto 0);
		RdRdyxSI		: in  std_logic;
		RdValxSO		: out std_logic
		
	);
end dds_iqfifo;


architecture arch of dds_iqfifo is
	COMPONENT dcfifo_mixed_widths
	GENERIC (
		add_usedw_msb_bit				: STRING;
		intended_device_family		: STRING;
		lpm_numwords					: NATURAL;
		lpm_showahead					: STRING;
		lpm_type							: STRING;
		lpm_width						: NATURAL;
		lpm_widthu						: NATURAL;
		lpm_widthu_r					: NATURAL;
		lpm_width_r						: NATURAL;
		overflow_checking				: STRING;
		rdsync_delaypipe				: NATURAL;
		read_aclr_synch				: STRING;
		underflow_checking			: STRING;
		use_eab							: STRING;
		write_aclr_synch				: STRING;
		wrsync_delaypipe				: NATURAL
	);
	PORT (
		aclr	: IN STD_LOGIC ;
		data	: IN STD_LOGIC_VECTOR (lpm_width-1 downto 0);
		rdclk	: IN STD_LOGIC ;
		rdreq	: IN STD_LOGIC ;
		wrclk	: IN STD_LOGIC ;
		wrreq	: IN STD_LOGIC ;
		q		: OUT STD_LOGIC_VECTOR(lpm_width_r-1 downto 0);
		rdempty	: OUT STD_LOGIC ;
		rdusedw	: OUT STD_LOGIC_VECTOR (lpm_widthu_r-1 downto 0); 
		wrempty	: out std_logic;
		wrfull	: OUT STD_LOGIC;
		wrusedw	: OUT STD_LOGIC_VECTOR (lpm_widthu-1 downto 0)
	);
	END COMPONENT;

	signal RstxR		: std_logic;

	signal WrReqxS		: std_logic;
	signal WrFullxS	: std_logic;
	signal WrQxD		: std_logic_vector((2*IQ_WIDTH - 1) downto 0);
	
	signal RdReqxS		: std_logic;
	signal RdEmptyxS	: std_logic;
	signal RdQxD		: std_logic_vector((2*IQ_WIDTH - 1) downto 0);
	
begin
	--reset/clear
	RstxR <= not RstxRBI;

	-- write request and data
	WrReqxS	<= WrValxSI and (not WrFullxS);
	WrQxD	<= WRQxDI & WrIxDI;
	
	-- read request
	RdReqxS	<= RdRdyxSI and (not RdEmptyxS);

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
	
	iqfifo0 : dcfifo_mixed_widths
	generic map(
		add_usedw_msb_bit       => "ON",
		intended_device_family  => "Cyclone IV E",
		lpm_numwords            => 2**DEPTH, --16 words
		lpm_showahead           => "ON",-- i.e. read_req = read acknowledgement
		lpm_type                => "dcfifo_mixed_widths",
		lpm_width               => 2*IQ_WIDTH,
		lpm_widthu              => DEPTH,
		lpm_widthu_r            => DEPTH,
		lpm_width_r             => 2*IQ_WIDTH,
		use_eab                 => "OFF", --use block ram
		overflow_checking       => "ON",
		underflow_checking      => "ON",
		rdsync_delaypipe        => 4,
		wrsync_delaypipe        => 4,
		read_aclr_synch         => "OFF",
		write_aclr_synch        => "OFF"
	)
	port map(
		aclr    	=> RstxR,
		--write interface
		data    	=> WrQxD,
		wrclk   	=> WrClkxCI,
		wrreq   	=> WrReqxS,
		wrfull  	=> WrFullxS,
		wrempty		=> open,
		wrusedw		=> open,
		--read interace
		q       	=> RdQxD,
		rdclk   	=> RdClkxCI,
		rdreq   	=> RdReqxS,
		rdempty 	=> RdEmptyxS,
		rdusedw 	=> open
	);
	
	
	--output assignment
	WrRdyxSO	<= not WrFullxS;
	RdValxSO	<= not RdEmptyxS;
	RdQxDO		<= RdQxD((2*IQ_WIDTH-1) downto IQ_WIDTH);
	RdIxDO		<= RdQxD((1*IQ_WIDTH-1) downto 0);
	
--	RdValxSO		<= RdReqxS when rising_edge(RdClkxCI);
	
end arch;
