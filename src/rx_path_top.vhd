-- ----------------------------------------------------------------------------	
-- FILE:    rx_path_top.vhd
-- DESCRIPTION:   describe file
-- DATE: March 27, 2017
-- AUTHOR(s):  Lime Microsystems
-- REVISIONS:
-- ----------------------------------------------------------------------------	
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.dds_pkg.all;

-- ----------------------------------------------------------------------------
-- Entity declaration
-- ----------------------------------------------------------------------------
entity rx_path_top is
   generic( 
      dev_family           : string := "Cyclone IV E";
      iq_width             : integer := 12;
      invert_input_clocks  : string := "OFF";
      smpl_buff_rdusedw_w  : integer := 11; --bus width in bits 
      pct_buff_wrusedw_w   : integer := 12  --bus width in bits 
      );
   port (
      clk                  : in std_logic;
      reset_n              : in std_logic;
      test_ptrn_en         : in std_logic;
      --Mode settings
      sample_width         : in std_logic_vector(1 downto 0); --"10"-12bit, "01"-14bit, "00"-16bit;
      mode                 : in std_logic; -- JESD207: 1; TRXIQ: 0
      trxiqpulse           : in std_logic; -- trxiqpulse on: 1; trxiqpulse off: 0
      ddr_en               : in std_logic; -- DDR: 1; SDR: 0
      mimo_en              : in std_logic; -- SISO: 1; MIMO: 0
      ch_en                : in std_logic_vector(1 downto 0); --"01" - Ch. A, "10" - Ch. B, "11" - Ch. A and Ch. B. 
      fidm                 : in std_logic; -- External Frame ID mode. Frame start at fsync = 0, when 0. Frame start at fsync = 1, when 1.
      --Rx interface data 
      DIQ                  : in std_logic_vector(iq_width-1 downto 0);
      fsync                : in std_logic;
      --samples
      smpl_fifo_wrreq_out  : out std_logic;
      --Packet fifo ports 
      pct_fifo_wusedw      : in std_logic_vector(pct_buff_wrusedw_w-1 downto 0);
      pct_fifo_wrreq       : out std_logic;
      pct_fifo_wdata       : out std_logic_vector(63 downto 0);
      pct_hdr_cap          : out std_logic;
      --sample nr
      clr_smpl_nr          : in std_logic;
      ld_smpl_nr           : in std_logic;
      smpl_nr_in           : in std_logic_vector(63 downto 0);
      smpl_nr_cnt          : out std_logic_vector(63 downto 0);
      --flag control
      tx_pct_loss          : in std_logic;
      tx_pct_loss_clr      : in std_logic;
      --sample compare
      smpl_cmp_start       : in std_logic;
      smpl_cmp_length      : in std_logic_vector(15 downto 0);
      smpl_cmp_done        : out std_logic;
      smpl_cmp_err         : out std_logic;
	-- DDS
	-- control
	i_dds_ctl			: in  t_dds_ctl;
	-- IQ m_axis in rx_clk domain
	i_dds_rx_i			: in  std_logic_vector((iq_width - 1) downto 0);
	i_dds_rx_q			: in  std_logic_vector((iq_width - 1) downto 0);
	o_dds_rx_rdy		: out std_logic;
	i_dds_rx_vld		: in  std_logic
     
   );
end rx_path_top;

-- ----------------------------------------------------------------------------
-- Architecture
-- ----------------------------------------------------------------------------
architecture arch of rx_path_top is
--declare signals,  components here


--sync registers
signal test_ptrn_en_sync      : std_logic;
signal reset_n_sync           : std_logic;
signal tx_pct_loss_sync       : std_logic;
signal tx_pct_loss_clr_sync   : std_logic;
signal sample_width_sync      : std_logic_vector(1 downto 0); 
signal mode_sync              : std_logic;
signal trxiqpulse_sync        : std_logic; 
signal ddr_en_sync            : std_logic; 
signal mimo_en_sync           : std_logic;
signal ch_en_sync             : std_logic_vector(1 downto 0);
signal fidm_sync              : std_logic;
signal clr_smpl_nr_sync       : std_logic;
signal ld_smpl_nr_sync        : std_logic;
signal smpl_nr_in_sync        : std_logic_vector(63 downto 0);	

signal smpl_cmp_start_sync    : std_logic;
signal smpl_cmp_length_sync   : std_logic_vector(15 downto 0);



--inst0 
signal inst0_fifo_wrreq       : std_logic;
signal inst0_fifo_wdata       : std_logic_vector(iq_width*4-1 downto 0);
signal inst0_smpl_cnt_en      : std_logic;
--inst1
signal inst1_wrfull           : std_logic;
signal inst1_q                : std_logic_vector(iq_width*4-1 downto 0);
signal inst1_rdusedw          : std_logic_vector(smpl_buff_rdusedw_w-1 downto 0);
--inst2
signal inst2_pct_hdr_0        : std_logic_vector(63 downto 0);
signal inst2_pct_hdr_1        : std_logic_vector(63 downto 0);
signal inst2_smpl_buff_rdreq  : std_logic;
signal inst2_smpl_buff_rddata : std_logic_vector(63 downto 0);
--inst3
signal inst3_q                : std_logic_vector(63 downto 0);

--internal signals
type my_array is array (0 to 5) of std_logic_vector(63 downto 0);
signal delay_chain   : my_array;

signal tx_pct_loss_detect     : std_logic;

-- ----------
-- DDS
-- ----------
-- control 
signal dds_en_sync, mix_en_sync	: std_logic;


-- loopback
signal dds_lb_fifo_valid	: std_logic;
signal dds_lb_fifo_rdy		: std_logic;
signal dds_lb_fifo_data		: std_logic_vector((4*iq_width - 1) downto 0);

-- received signal from LMS7002
signal RxIQVldxS, RxIQRdyxS	: std_logic;
signal RxIxD, RxQxD			: std_logic_vector((iq_width - 1) downto 0);

-- radar signal
signal RadarIQVldxS, RadarIQRdyxS	: std_logic;
signal RadarIxD, RadarQxD			: std_logic_vector(15 downto 0);
signal radar_fifo_vld				: std_logic;
signal radar_fifo_rdy				: std_logic;
signal radar_fifo_data				: std_logic_vector(63 downto 0);

-- mux 0 (LMS7002 or DDS LB)
signal mux0_sampl_fifo_wdata, mux0_sampl_fifo_wdata_reg	: std_logic_vector((4*iq_width - 1) downto 0);
signal mux0_sampl_fifo_wrreq, mux0_sampl_fifo_wrreq_reg	: std_logic;
signal mux0_fifo_wdata_resize							: std_logic_vector(63 downto 0);

-- mux 1 (mux 0 or radar dsp)
signal mux2_wdata					: std_logic_vector(63 downto 0);
signal mux2_wrreq					: std_logic;
signal mux1_sampl_fifo_wrreq, mux1_sampl_fifo_wrreq_reg		: std_logic;
signal mux1_sampl_fifo_wdata, mux1_sampl_fifo_wdata_reg		: std_logic_vector(63 downto 0);

-- sweep sync
signal dds_swp_sync_sync, dds_swp_sync_hold : std_logic;


begin


sync_reg0 : entity work.sync_reg 
port map(clk, '1', reset_n, reset_n_sync);
 
sync_reg1 : entity work.sync_reg 
port map(clk, '1', tx_pct_loss, tx_pct_loss_sync);
 
sync_reg2 : entity work.sync_reg 
port map(clk, '1', tx_pct_loss_clr, tx_pct_loss_clr_sync);

sync_reg3 : entity work.sync_reg 
port map(clk, '1', mode, mode_sync);

sync_reg4 : entity work.sync_reg 
port map(clk, '1', trxiqpulse, trxiqpulse_sync);

sync_reg5 : entity work.sync_reg 
port map(clk, '1', ddr_en, ddr_en_sync);

sync_reg6 : entity work.sync_reg 
port map(clk, '1', mimo_en, mimo_en_sync);

sync_reg7 : entity work.sync_reg 
port map(clk, '1', fidm, fidm_sync);

sync_reg8 : entity work.sync_reg 
port map(clk, '1', clr_smpl_nr, clr_smpl_nr_sync);

sync_reg9 : entity work.sync_reg 
port map(clk, '1', ld_smpl_nr, ld_smpl_nr_sync);

sync_reg10 : entity work.sync_reg 
port map(clk, '1', test_ptrn_en, test_ptrn_en_sync);

sync_reg11 : entity work.sync_reg 
port map(clk, '1', smpl_cmp_start, smpl_cmp_start_sync);

sync_reg12 : entity work.sync_reg 
port map(clk, '1', i_dds_ctl.rx_sel, dds_en_sync);

sync_reg13 : entity work.sync_reg 
port map(clk, '1', i_dds_ctl.mix_en, mix_en_sync);

sync_reg14 : entity work.sync_reg
port map(clk, '1', i_dds_ctl.sweep_sync, dds_swp_sync_sync);

bus_sync_reg0 : entity work.bus_sync_reg
generic map (2)
port map(clk, '1', sample_width, sample_width_sync);

bus_sync_reg1 : entity work.bus_sync_reg
generic map (2)
port map(clk, '1', ch_en, ch_en_sync);

bus_sync_reg2 : entity work.bus_sync_reg
generic map (64)
port map(clk, '1', smpl_nr_in, smpl_nr_in_sync);

bus_sync_reg3 : entity work.bus_sync_reg
generic map (16)
port map(clk, '1', smpl_cmp_length, smpl_cmp_length_sync);





-- ----------------------------------------------------------------------------
-- diq2fifo instance (LMS7002 DIQ -> fifo words)
-- ----------------------------------------------------------------------------
diq2fifo_inst0 : entity work.diq2fifo
   generic map( 
      dev_family           => dev_family,
      iq_width             => iq_width,
      invert_input_clocks  => invert_input_clocks
      )
   port map(
      clk               => clk,
      reset_n           => reset_n_sync,
      --Mode settings
      test_ptrn_en      => test_ptrn_en_sync,
      mode              => mode_sync, -- JESD207: 1; TRXIQ: 0
      trxiqpulse        => trxiqpulse_sync, -- trxiqpulse on: 1; trxiqpulse off: 0
      ddr_en            => ddr_en_sync, -- DDR: 1; SDR: 0
      mimo_en           => mimo_en_sync, -- SISO: 1; MIMO: 0
      ch_en             => ch_en_sync, --"01" - Ch. A, "10" - Ch. B, "11" - Ch. A and Ch. B. 
      fidm              => fidm_sync, -- External Frame ID mode. Frame start at fsync = 0, when 0. Frame start at fsync = 1, when 1.
      --Rx interface data 
      DIQ               => DIQ,
      fsync             => fsync,
      --fifo ports 
      fifo_wfull        => inst1_wrfull,
      fifo_wrreq        => inst0_fifo_wrreq,
      fifo_wdata        => inst0_fifo_wdata, 
      smpl_cmp_start    => smpl_cmp_start_sync,
      smpl_cmp_length   => smpl_cmp_length_sync,
      smpl_cmp_done     => smpl_cmp_done,
      smpl_cmp_err      => smpl_cmp_err,
      smpl_cnt_en       => inst0_smpl_cnt_en
        );
        
        
smpl_fifo_wrreq_out <= inst0_fifo_wrreq; 
        

-- ----------------------------------------------------------------------------
-- IQ Axis to fifo (DDS loop back)
-- ---------------------------------------------------------------------------- 
	dds_iq2fifo_rx0 : entity work.dds_iq2fifo
	generic map(
		IQ_WIDTH		=> iq_width
	)
	port map(
		ClkxCI		=> clk,
		RstxRBI		=> reset_n_sync,
		IQValxSI	=> i_dds_rx_vld,
		IQRdyxSO	=> o_dds_rx_rdy,
		IxDI		=> i_dds_rx_i,
		QxDI		=> i_dds_rx_q,
		FifoValxSO	=> dds_lb_fifo_valid,
		FifoRdyxSI	=> dds_lb_fifo_rdy,
		FifoQxDO	=> dds_lb_fifo_data
	);
	
	dds_lb_fifo_rdy	<= not inst1_wrfull;
	
	
-- ----------------------------------------------------------------------------
-- RADAR DSP: fifo -> iq -> fifo 
-- ---------------------------------------------------------------------------- 

	-- fifo interface to AXIS IQ interface
	dds_fifo2iq_rx1 : entity work.dds_fifo2iq
	generic map(
		IQ_WIDTH		=> iq_width
	)
	port map(
		ClkxCI		=> clk,
		RstxRBI		=> reset_n_sync,
		
		FifoValxSI	=> inst0_fifo_wrreq,
		FifoRdyxSO	=> open,
		FifoQxDI		=> inst0_fifo_wdata,
		
		IQValxSO		=> RxIQVldxS,
		IQRdyxSI		=> RxIQRdyxS,
		IxDO			=> RxIxD,
		QxDO			=> RxQxD
	);
	
	--custom DSP block, used for RADAR specific processing
	--i.e. in -> fifo -> dc_block -> mix (DDS) -> CIC (downsampling) -> FIR -> DS -> out
	radar_dsp0 : entity work.radar_dsp
	generic map(
		IQ_WIDTH_IN		=> iq_width,
		IQ_WIDTH_OUT	=> 16
	)
	port map(
		ClkxCI		=> clk,
		RstxRBI		=> reset_n_sync,
		-- RX (from LMS7002)
		RxValxSI		=> RxIQVldxS,
		RxRdyxSO		=> RxIQRdyxS,
		RxIxDI		=> RxIxD,
		RxQxDI		=> RxQxD,
		-- TX (from DDS)
		TxVldxSI		=> i_dds_rx_vld,
		TxRdyxSO		=> open,
		TxIxDI		=> i_dds_rx_i,
		TxQxDI		=> i_dds_rx_q,
		-- DSP output
		OutValxSO	=> RadarIQVldxS,
		OutRdyxSI	=> RadarIQRdyxS,
		--OutRdyxSI	=> '1',
		IxDO			=> RadarIxD,
		QxDO			=> RadarQxD
	);
	
	-- AXIS IQ interface to fifo interface
	dds_iq2fifo_rx1 : entity work.dds_iq2fifo
	generic map(
		IQ_WIDTH		=> 16 --iq_width
	)
	port map(
		ClkxCI		=> clk,
		RstxRBI		=> reset_n_sync,
		IQValxSI	=> RadarIQVldxS,
		IQRdyxSO	=> RadarIQRdyxS,
		IxDI		=> RadarIxD,
		QxDI		=> RadarQxD,
		FifoValxSO	=> radar_fifo_vld,
		FifoRdyxSI	=> radar_fifo_rdy,
		FifoQxDO	=> radar_fifo_data
	);

	radar_fifo_rdy <= not inst1_wrfull;
	

-- ----------------------------------------------------------------------------
-- MUX0 : DDS loop back or RX (LMS7002)
-- ---------------------------------------------------------------------------- 

	-- dds_en_sync = rx_sel
	mux0_sampl_fifo_wrreq <= inst0_fifo_wrreq when dds_en_sync = '0' else dds_lb_fifo_valid and dds_lb_fifo_rdy;
	mux0_sampl_fifo_wdata <= inst0_fifo_wdata when dds_en_sync = '0' else dds_lb_fifo_data;
				  
				  
	p_sync_mux0 : process(reset_n_sync, clk)
	begin
		if reset_n_sync = '0' then
			mux0_sampl_fifo_wrreq_reg <= '0';
			mux0_sampl_fifo_wdata_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			mux0_sampl_fifo_wrreq_reg <= mux0_sampl_fifo_wrreq;
			mux0_sampl_fifo_wdata_reg <= mux0_sampl_fifo_wdata;
		end if;
	end process;

mux0_fifo_wdata_resize	<= 	mux0_sampl_fifo_wdata_reg(47 downto 36) & "0000" & 
							mux0_sampl_fifo_wdata_reg(35 downto 24) & "0000" & 
							mux0_sampl_fifo_wdata_reg(23 downto 12) & "0000" & 
							mux0_sampl_fifo_wdata_reg(11 downto 0) & "0000";
	
	
-- ----------------------------------------------------------------------------
-- MUX1 : RADAR DSP or MUX0
-- ----------------------------------------------------------------------------
--	mux1_sampl_fifo_wdata <= mux0_sampl_fifo_wdata_reg when mix_en_sync = '0' else fifo_data;
	
	hold_inst : entity work.hold
	generic map(
		HOLD_CC => 2
	)
	port map(
		ClkxCI	=> clk,
		RstxRBI	=> reset_n_sync,
		TrigxSI	=> dds_swp_sync_sync,
		HoldxSO	=> dds_swp_sync_hold
	);
	
	p_sync_mux : process(clk, reset_n_sync)
	begin
		if rising_edge(clk) then
			if mix_en_sync = '0' then
				mux2_wdata <= mux0_fifo_wdata_resize;
				mux2_wrreq <= mux0_sampl_fifo_wrreq_reg;
			else
				mux2_wdata <= radar_fifo_data;
				mux2_wrreq <= radar_fifo_vld and radar_fifo_rdy;
			end if;
		end if;
	end process;
	
	-- add sweep sync word
	p_comb_sync_header : process(dds_swp_sync_hold, mux2_wdata, mux2_wrreq)
	begin
		if dds_swp_sync_hold = '1' then
			mux1_sampl_fifo_wrreq <= '1';
			mux1_sampl_fifo_wdata <= x"000B7FFF000B7FFF";
		else
			mux1_sampl_fifo_wrreq <= mux2_wrreq;
			mux1_sampl_fifo_wdata <= mux2_wdata;
		end if;
	end process;
				  
	p_sync_mux1 : process(reset_n_sync, clk)
	begin
		if reset_n_sync = '0' then
			mux1_sampl_fifo_wrreq_reg <= '0';
			mux1_sampl_fifo_wdata_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			mux1_sampl_fifo_wrreq_reg <= mux1_sampl_fifo_wrreq;
			mux1_sampl_fifo_wdata_reg <= mux1_sampl_fifo_wdata;
		end if;
	end process;
			  
-- ----------------------------------------------------------------------------
-- FIFO for storing samples
-- ----------------------------------------------------------------------------       
smpl_fifo_inst1 : entity work.fifo_inst
  generic map(
      dev_family      => dev_family, 
      wrwidth         => 64, --(iq_width*4),
      wrusedw_witdth  => smpl_buff_rdusedw_w,
      rdwidth         => 64, --(iq_width*4),
      rdusedw_width   => smpl_buff_rdusedw_w,
      show_ahead      => "OFF"
  ) 

  port map(
      --input ports 
      reset_n        => reset_n_sync,
      wrclk          => clk,
      wrreq          => mux1_sampl_fifo_wrreq_reg, --inst0_fifo_wrreq,
      data           => mux1_sampl_fifo_wdata_reg, --inst0_fifo_wdata,
      wrfull         => inst1_wrfull,
      wrempty        => open,
      wrusedw        => open,
      rdclk          => clk,
      rdreq          => inst2_smpl_buff_rdreq,
      q              => inst2_smpl_buff_rddata, --inst1_q,
      rdempty        => open,
      rdusedw        => inst1_rdusedw  
        );
 
--samples are placed to MSb LSb ar filled with zeros 
-- inst2_smpl_buff_rddata <=  inst1_q(47 downto 36) & "0000" & 
--                            inst1_q(35 downto 24) & "0000" & 
--                            inst1_q(23 downto 12) & "0000" & 
--                            inst1_q(11 downto 0) & "0000";
    
    
--packet reserved bits  
  inst2_pct_hdr_0(15 downto 0)   <="000000000000" & tx_pct_loss_sync & pct_fifo_wusedw(pct_buff_wrusedw_w-1 downto pct_buff_wrusedw_w-3);
  inst2_pct_hdr_0(31 downto 16)  <=x"0201";
  inst2_pct_hdr_0(47 downto 32)  <=x"0403";
  inst2_pct_hdr_0(63 downto 48)  <=x"0605";
        
        
-- ----------------------------------------------------------------------------
-- Instance for packing samples to packets
-- ----------------------------------------------------------------------------       
data2packets_top_inst2 : entity work.data2packets_top
   generic map(
      smpl_buff_rdusedw_w => smpl_buff_rdusedw_w,  --bus width in bits 
      pct_buff_wrusedw_w  => pct_buff_wrusedw_w    --bus width in bits            
   )
   port map(
      clk               => clk,
      reset_n           => reset_n_sync,
      sample_width      => sample_width_sync,
      pct_hdr_0         => inst2_pct_hdr_0,
      pct_hdr_1         => inst2_pct_hdr_1,
      pct_buff_wrusedw  => pct_fifo_wusedw,
      pct_buff_wrreq    => pct_fifo_wrreq,
      pct_buff_wrdata   => pct_fifo_wdata,
      pct_hdr_cap       => pct_hdr_cap,
      smpl_buff_rdusedw => inst1_rdusedw,
      smpl_buff_rdreq   => inst2_smpl_buff_rdreq,
      smpl_buff_rddata  => inst2_smpl_buff_rddata   
        );
        
-- ----------------------------------------------------------------------------
-- Instance for packing sample counter for packet forming
-- ----------------------------------------------------------------------------        
smpl_cnt_inst3 : entity work.smpl_cnt
   generic map(
      cnt_width   => 64
   )
   port map(

      clk         => clk,
      reset_n     => reset_n_sync,
      mode        => mode_sync,
      trxiqpulse  => trxiqpulse_sync,
      ddr_en      => ddr_en_sync,
      mimo_en     => mimo_en_sync,
      ch_en       => ch_en_sync,
      sclr        => clr_smpl_nr_sync,
      sload       => ld_smpl_nr_sync,
      data        => smpl_nr_in_sync,
      cnt_en      => inst2_smpl_buff_rdreq,
      q           => inst3_q        
        );

-- ----------------------------------------------------------------------------
-- Instance for sample counter
-- ----------------------------------------------------------------------------        
iq_smpl_cnt_inst4 : entity work.iq_smpl_cnt
   generic map(
      cnt_width   => 64
   )
   port map(

      clk         => clk,
      reset_n     => reset_n_sync,
      mode        => mode_sync,
      trxiqpulse  => trxiqpulse_sync,
      ddr_en      => ddr_en_sync,
      mimo_en     => mimo_en_sync,
      ch_en       => ch_en_sync,
      sclr        => clr_smpl_nr_sync,
      sload       => ld_smpl_nr_sync,
      data        => smpl_nr_in_sync,
      cnt_en      => inst0_smpl_cnt_en,
      q           => smpl_nr_cnt        
        );
        
-- ----------------------------------------------------------------------------
-- There is 6 clock cycle latency from smpl_fifo_inst1 to packet formation
-- and smpl_cnt has to be delayed 6 cycles
-- ----------------------------------------------------------------------------        
delay_registers : process(clk, reset_n)
begin
   if reset_n = '0' then 
      delay_chain <= (others=>(others=>'0'));
   elsif (clk'event AND clk='1') then 
      for i in 0 to 5 loop
         if i=0 then 
            delay_chain(i) <= inst3_q;
         else 
            delay_chain(i) <= delay_chain(i-1);
         end if;
      end loop;
   end if;
end process;
        
inst2_pct_hdr_1 <=  delay_chain(5);      
  
end arch;   





