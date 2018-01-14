-- ----------------------------------------------------------------------------	
-- FILE:	ddscfg.vhd
-- DESCRIPTION:	Serial configuration interface to control DDS and signal generator modules
-- DATE:	December 24, 2017
-- AUTHOR(s):	Lime Microsystems, Jannik Springer
-- REVISIONS:	
-- ----------------------------------------------------------------------------	

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mem_package.all;
use work.revisions.all;


entity ddscfg is
	port (
		------------------------------------------------------------------
		-------------------- Lime Signals --------------------------------
		------------------------------------------------------------------
		-- Address and location of this module
		-- Will be hard wired at the top level
		maddress			: in  std_logic_vector(9 downto 0);
		mimo_en			: in  std_logic;	-- MIMO enable, from TOP SPI (always 1)
	
		-- Serial port IOs
		sdin				: in  std_logic;	-- Data in
		sclk				: in  std_logic;	-- Data clock
		sen				: in  std_logic;	-- Enable signal (active low)
		sdout				: out std_logic;	-- Data out
	
		-- Signals coming from the pins or top level serial interface
		lreset			: in std_logic; 	-- Logic reset signal, resets logic cells only  (use only one reset)
		mreset			: in std_logic; 	-- Memory reset signal, resets configuration memory only (use only one reset)
	
		------------------------------------------------------------------
		-------------------- User Signals --------------------------------
		------------------------------------------------------------------
		DDSEnablexSO	: out std_logic;
		DDSTxSelxSO		: out std_logic;
		DDSRxSelxSO		: out std_logic;
		
		FTW0xDO			: out std_logic_vector(31 downto 0)
	
	);
end ddscfg;

architecture  arch of ddscfg is
	------------------------------------------------------------------------------------------------
	--	Componentes
	------------------------------------------------------------------------------------------------
	use work.mcfg_components.mcfg32wm_fsm;										-- fsm used to control read and write actions to the configuration memory
	for all: mcfg32wm_fsm use entity work.mcfg32wm_fsm(mcfg32wm_fsm_arch);

	------------------------------------------------------------------------------------------------
	--	Signals and types
	------------------------------------------------------------------------------------------------
	signal inst_reg								: std_logic_vector(15 downto 0);		-- Instruction register
	signal inst_reg_en							: std_logic;

	signal din_reg								: std_logic_vector(15 downto 0);		-- Data in register
	signal din_reg_en							: std_logic;
	
	signal dout_reg								: std_logic_vector(15 downto 0);		-- Data out register
	signal dout_reg_sen, dout_reg_len			: std_logic;
	
	signal mem									: marray32x16;							-- Config memory
	signal mem_we								: std_logic;
	
	signal oe									: std_logic;							-- Tri state buffers control
	
	
begin
	
	
	------------------------------------------------------------------------------------------------
	--	Instantiate Components
	------------------------------------------------------------------------------------------------
	fsm: mcfg32wm_fsm
	port map( 
		address => maddress,
		mimo_en => mimo_en,
		inst_reg => inst_reg,
		sclk => sclk,
		sen => sen,
		reset => lreset,
		inst_reg_en => inst_reg_en,
		din_reg_en => din_reg_en,
		dout_reg_sen => dout_reg_sen,
		dout_reg_len => dout_reg_len,
		mem_we => mem_we,
		oe => oe,
		stateo => open
	);
	
	------------------------------------------------------------------------------------------------
	--	Synchronus process (sequential logic and registers)
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
    -- ProcessName: p_sync_inst_reg
    -- This process implements the instruction register.
    --------------------------------------------
	p_sync_inst_reg: process(sclk, lreset)
		variable i: integer;
	begin
		if lreset = '0' then
			inst_reg <= (others => '0');
		elsif sclk'event and sclk = '1' then
			if inst_reg_en = '1' then
				for i in 15 downto 1 loop
					inst_reg(i) <= inst_reg(i-1);
				end loop;
				inst_reg(0) <= sdin;
			end if;
		end if;
	end process p_sync_inst_reg;

	--------------------------------------------
    -- ProcessName: p_sync_din_reg
    -- This process implements the data register.
    --------------------------------------------
	p_sync_din_reg: process(sclk, lreset)
		variable i: integer;
	begin
		if lreset = '0' then
			din_reg <= (others => '0');
		elsif sclk'event and sclk = '1' then
			if din_reg_en = '1' then
				for i in 15 downto 1 loop
					din_reg(i) <= din_reg(i-1);
				end loop;
				din_reg(0) <= sdin;
			end if;
		end if;
	end process p_sync_din_reg;
	
	--------------------------------------------
    -- ProcessName: p_sync_data_out
    -- This process implements the data output register, needed in conjunction with the actual memory process. Also implements read-only registers.
    --------------------------------------------
	p_sync_data_out: process(sclk, lreset)
		variable i: integer;
	begin
		if lreset = '0' then
			dout_reg <= (others => '0');
		elsif sclk'event and sclk = '0' then
			-- Shift operation
			if dout_reg_sen = '1' then
				for i in 15 downto 1 loop
					dout_reg(i) <= dout_reg(i-1);
				end loop;
				dout_reg(0) <= dout_reg(15);
			-- Load operation
			elsif dout_reg_len = '1' then
				case inst_reg(4 downto 0) is	-- mux read-only outputs
					--when "00001" => dout_reg <= x"0002";
					when "00010" => dout_reg <= (15 downto 8 => '0') & std_logic_vector(to_unsigned(COMPILE_REV, 8));
					when "00011" => dout_reg <= "1010101010101010";
					when others  => dout_reg <= mem(to_integer(unsigned(inst_reg(4 downto 0))));
				end case;
			end if;			      
		end if;
	end process p_sync_data_out;
	
	sdout <= dout_reg(15) and oe;
	
	
	--------------------------------------------
    -- ProcessName: p_sync_mem
    -- This process infers a memory used to store the configuration of the DDS and signal generator.
    --------------------------------------------
	p_sync_mem: process(sclk, mreset) --(remap)
	begin
		-- Defaults
		if mreset = '0' then	
			mem(0)	<= "0000000000000000"; -- Version
			mem(1)	<= "0000000000000000"; -- Control (General, e.g. enable, interpol, dithering, mode)
			mem(2)	<= "0000000000000000"; -- Control (Further mode specification, i.e. number of sweeps, fmcw mode, FSK mode)
			mem(3)	<= "0000000000000000"; -- Control (Reserved for future version)
			mem(4)	<= "0000000000000000"; -- F0.H (start in sweep mode, f0 for fsk mode)
			mem(5)	<= "0000000000000000"; -- F0.L 
			mem(6)	<= "0000000000000000"; -- F1.H (stop in sweep mode, f1 for fsk mode)
			mem(7)	<= "0000000000000000"; -- F1.L
			mem(8)	<= "0000000000000000"; -- F2.H
			mem(9)	<= "0000000000000000"; -- F2.L
			mem(10)	<= "0000000000000000"; -- F3.H
			mem(11)	<= "0000000000000000"; -- F3.L
			mem(12)	<= "0000000000000000"; -- P0.H (phase offset 0)
			mem(13)	<= "0000000000000000"; -- P0.L
			mem(14)	<= "0000000000000000"; -- P1.H (phase offset 1)
			mem(15)	<= "0000000000000000"; -- P1.L
			mem(16)	<= "0000000000000000"; -- P2.H (phase offset 2)
			mem(17)	<= "0000000000000000"; -- P2.L
			mem(18)  <= "0000000000000000"; -- P3.H (phase offset 3)
			mem(19)	<= "0000000000000000"; -- P3.L
			mem(20)	<= "0000000000000000"; -- R.H (sweep rate)
			mem(21)	<= "0000000000000000"; -- R.L
			mem(22)	<= "0000000000000000"; -- 
			mem(23)	<= "0000000000000000"; -- 
			mem(24)	<= "0000000000000000"; -- 
			mem(25)	<= "0000000000000000"; -- 
			mem(26)	<= "0000000000000000"; --
			mem(27)	<= "0000000000000000"; --
			mem(28)	<= "0000000000000000"; --
			mem(29)	<= "0000000000000000"; --
			mem(30)	<= "0000000000000000"; --
			mem(31) <= "0000000000000000"; --
			
		elsif sclk'event and sclk = '1' then
				if mem_we = '1' then
					mem(to_integer(unsigned(inst_reg(4 downto 0)))) <= din_reg(14 downto 0) & sdin;
				end if;
		end if;
	end process p_sync_mem;
	
	
	------------------------------------------------------------------------------------------------
	--	Combinatorical process (parallel logic)
	------------------------------------------------------------------------------------------------
	
	--------------------------------------------
    -- ProcessName: p_comb_MUX
    -- This process implements a multiplexer, that is used to apply either 0 or the correct data to
    -- the multiply input (if input is valid).
    --------------------------------------------
	-- p_comb_MUX : process (MulInValidxSI, MulInLxDI)
	-- begin
	   -- if (MulInValidxSI = '0') then
	       -- MulInLxD <= (others => '0');
	   -- else
	       -- MulInLxD <= MulInLxDI;
	   -- end if;
	-- end process p_comb_MUX;
	
	
	
	
	------------------------------------------------------------------------------------------------
	--	Output Assignment
	------------------------------------------------------------------------------------------------
	DDSEnablexSO	<= mem(1)(0);
	DDSTxSelxSO		<= mem(1)(1);
	DDSRxSelxSO		<= mem(1)(2);
	
	FTW0xDO			<= mem(4) & mem(5);
	
end arch;
