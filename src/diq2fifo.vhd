-- ----------------------------------------------------------------------------	
-- FILE: 	diq2fifo.vhd
-- DESCRIPTION:	Writes DIQ data to FIFO, FIFO word size = 4  DIQ samples 
-- DATE:	Jan 13, 2016
-- AUTHOR(s):	Lime Microsystems
-- REVISIONS:
-- ----------------------------------------------------------------------------	
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- ----------------------------------------------------------------------------
-- Entity declaration
-- ----------------------------------------------------------------------------
entity diq2fifo is
   generic( 
      dev_family				: string := "Cyclone IV E";
      iq_width					: integer := 12;
      invert_input_clocks	: string := "ON"
      );
   port (
      clk         : in std_logic;
      reset_n     : in std_logic;
		test_ptrn_en: in std_logic;
		dds_en		: in std_logic;
      --Mode settings
      mode			: in std_logic; -- JESD207: 1; TRXIQ: 0
		trxiqpulse	: in std_logic; -- trxiqpulse on: 1; trxiqpulse off: 0
		ddr_en 		: in std_logic; -- DDR: 1; SDR: 0
		mimo_en		: in std_logic; -- SISO: 1; MIMO: 0
		ch_en			: in std_logic_vector(1 downto 0); --"01" - Ch. A, "10" - Ch. B, "11" - Ch. A and Ch. B. 
		fidm			: in std_logic; -- External Frame ID mode. Frame start at fsync = 0, when 0. Frame start at fsync = 1, when 1.
      --Rx interface data 
      DIQ		 	: in std_logic_vector(iq_width-1 downto 0);
		fsync	 	   : in std_logic;
	 --DDS data
	 dds_data_h		: in std_logic_vector(iq_width downto 0);
	 dds_data_l		: in std_logic_vector(iq_width downto 0);
      --fifo ports 
      fifo_wfull  : in std_logic;
      fifo_wrreq  : out std_logic;
      fifo_wdata  : out std_logic_vector(iq_width*4-1 downto 0) 

        );
end diq2fifo;

-- ----------------------------------------------------------------------------
-- Architecture
-- ----------------------------------------------------------------------------
architecture arch of diq2fifo is
--declare signals,  components here
signal inst0_diq_out_h 	: std_logic_vector (iq_width downto 0); 
signal inst0_diq_out_l 	: std_logic_vector (iq_width downto 0); 

signal inst2_data_h		: std_logic_vector (iq_width downto 0);
signal inst2_data_l		: std_logic_vector (iq_width downto 0); 

signal mux0_diq_h			: std_logic_vector (iq_width downto 0); 
signal mux0_diq_l			: std_logic_vector (iq_width downto 0);

signal mux0_diq_h_reg	: std_logic_vector (iq_width downto 0); 
signal mux0_diq_l_reg	: std_logic_vector (iq_width downto 0);
  
-- mux for dds data
signal cplx_mul_h		: std_logic_vector((iq_width - 1) downto 0);
signal cplx_mul_l		: std_logic_vector((iq_width - 1) downto 0);

signal mux1_diq_h			: std_logic_vector (iq_width downto 0); 
signal mux1_diq_l			: std_logic_vector (iq_width downto 0);

signal mux1_diq_h_reg	: std_logic_vector (iq_width downto 0); 
signal mux1_diq_l_reg	: std_logic_vector (iq_width downto 0);
  
signal ChannelxSN, ChannelxSP : std_logic_vector(1 downto 0);

begin

inst0_lms7002_ddin : entity work.lms7002_ddin
	generic map( 
      dev_family				=> dev_family,
      iq_width					=> iq_width,
      invert_input_clocks	=> invert_input_clocks
	)
	port map (
      clk       	=> clk,
      reset_n   	=> reset_n, 
		rxiq		 	=> DIQ, 
		rxiqsel	 	=> fsync, 
		data_out_h	=> inst0_diq_out_h, 
		data_out_l	=> inst0_diq_out_l 
        );
        
        
inst1_rxiq : entity work.rxiq
	generic map( 
      dev_family				=> dev_family,
      iq_width					=> iq_width
	)
	port map (
      clk         => clk,
      reset_n     => reset_n,
      trxiqpulse  => trxiqpulse,
		ddr_en 		=> ddr_en,
		mimo_en		=> mimo_en,
		ch_en			=> ch_en,
		fidm			=> fidm, --tied to zero (in bdf)
--       DIQ_h		 	=> mux0_diq_h_reg,
-- 		DIQ_l	 	   => mux0_diq_l_reg,
		DIQ_h			=> mux1_diq_h_reg,
		DIQ_l			=> mux1_diq_l_reg,
      fifo_wfull  => fifo_wfull,
      fifo_wrreq  => fifo_wrreq,
      fifo_wdata  => fifo_wdata
        );
		  
int2_test_data_dd	: entity work.test_data_dd
port map(

	clk       		=> clk,
	reset_n   		=> reset_n,
	fr_start	 		=> fidm,
	mimo_en   		=> mimo_en,		  
	data_h		  	=> inst2_data_h,
	data_l		  	=> inst2_data_l

);
	
------------------------------------------------------------------------------------
-- mux actual adc data or test pattern
------------------------------------------------------------------------------------
mux0_diq_h <= 	inst0_diq_out_h when test_ptrn_en = '0' else inst2_data_h;
mux0_diq_l <= 	inst0_diq_out_l when test_ptrn_en = '0' else inst2_data_l;	


process(clk, reset_n)
begin 
	if reset_n = '0' then 
		mux0_diq_h_reg <= (others=>'0');
		mux0_diq_l_reg <= (others=>'0');
	elsif (clk'event AND clk='1') then
		mux0_diq_h_reg <= mux0_diq_h;
		mux0_diq_l_reg <= mux0_diq_l;
	end if;
end process;	  
		  
------------------------------------------------------------------------------------
-- mux dds data or mux0
------------------------------------------------------------------------------------
--CPLX_MUL0 : entity work.cplx_mul
--generic map(
--	A_WIDTH	=> iq_width,
--	B_WIDTH	=> iq_width,
--	P_WIDTH	=> iq_width
--)
--port map(
--	ClkxCI		=> clk,
--	RstxRBI	 	=> reset_n,
--	EnablexSI	=> '1',
--	ArealxDI	=> dds_data_l((iq_width - 1) downto 0),
--	AimagxDI	=> dds_data_h((iq_width - 1) downto 0),
--	--BrealxDI => std_logic_vector(to_unsigned(1, iq_width)),
--	--BimagxDI => std_logic_vector(to_unsigned(0, iq_width)),
----	BrealxDI => dds_data_l((iq_width - 1) downto 0),
----	BimagxDI	=> dds_data_h((iq_width - 1) downto 0),
--	BrealxDI	=> mux0_diq_h_reg((iq_width - 1) downto 0),
--	BimagxDI	=> mux0_diq_l_reg((iq_width - 1) downto 0),
--	PrealxDO	=> cplx_mul_h,
--	PimagxDO	=> cplx_mul_l
--);


ChannelxSN <= dds_data_l(dds_data_l'left) & dds_data_h(dds_data_h'left);

DELAY_CHANNEL0 : entity work.DelayLine(rtl)
	generic map (
		DELAY_WIDTH		=> 2,
		DELAY_CYCLES	=> 2
	)
	port map(
		ClkxCI			=> clk,
		RstxRBI			=> reset_n,
		EnablexSI		=> '1',
		InputxDI			=> ChannelxSN,
		OutputxDO		=> ChannelxSP
	);


--mux1_diq_h <= mux0_diq_h_reg when dds_en = '0' else (ChannelxSP(1) & cplx_mul_h);
--mux1_diq_l <= mux0_diq_l_reg when dds_en = '0' else (ChannelxSP(0) & cplx_mul_l);

--mux1_diq_h <= mux0_diq_h_reg when dds_en = '0' else (dds_data_h(dds_data_h'left) & cplx_mul_h);
--mux1_diq_l <= mux0_diq_l_reg when dds_en = '0' else (dds_data_l(dds_data_l'left) & cplx_mul_l);

mux1_diq_h <= mux0_diq_h_reg when dds_en = '0' else dds_data_h;
mux1_diq_l <= mux0_diq_l_reg when dds_en = '0' else dds_data_l;

process(clk, reset_n)
begin 
	if reset_n = '0' then 
		mux1_diq_h_reg <= (others=>'0');
		mux1_diq_l_reg <= (others=>'0');
	elsif (clk'event AND clk='1') then
		mux1_diq_h_reg <= mux1_diq_h;
		mux1_diq_l_reg <= mux1_diq_l;
	end if;
end process;	 

end arch;   





