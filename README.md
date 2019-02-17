# Custom gateware for the LimeSDR
This is a custom gateware for the LimeSDR, that includes the [DDS Core](https://github.com/spr02/DDS). Using this core the LimeSDR can be configured to be used as a single-tone or sweep generator. Furthermore a complex mixer can be enabled in the receive path that can mix the generated output signal with the received signal. This is makes it possible to extract a beat frequency and is therefore a dooropener for FMCW radar applications up to 60MHz bandwidth using the LimeSDR.

## Dependencies
The project is build up upon the gateware developed for the LimeSDR [https://github.com/myriadrf/LimeSDR-USB_GW](https://github.com/myriadrf/LimeSDR-USB_GW) which is included as a submodule. To generate a bitstream you will need Quartus from Altera (Intel FPGA), i am using version 15.1.0. To get the source code with all submodules initialized (LimeSDR_gateware and src/DDS) you can use the following clone command:

```sh
git clone --recurse-submodules -j8 https://github.com/spr02/LimeDDS_GW.git
```

## Build
Load the project file in Quartus (lms7_dds_trx.qpf) and then generate the bitstream. The bitfile 'LimeSDR-USB_lms7_dds_trx_HW_1.4.rbf', which will be needed to progam the LimeSDR, will be automatically generated when running generate bitsream and is saved to the [output_files](output_files) directory.

Currently, line 111 in [src/DDS/hdl/dither.vhd](https://github.com/spr02/DDS/blob/aee4ea3802c6c7667cc91367ba4456cb10eb3cc5/hdl/dither.vhd#L111) needs to be changed to the following, for bitstream generation to work:
```vhdl
	constant MSB_POS : natural := 11; -- changed from 15 to 11
```

## Run/Program
You can either load the bitstream using LimeSuiteGUI or using the command line uitilty:

```sh
LimeUtil --fpga="output_files/LimeSDR-USB_lms7_dds_trx_HW_1.4.rbf"
```


## TODO
- adapt axis to fifo word converter for two channels/mimo_en/...
- add scale multiplier for output of CIC filter (or AGC)
- add CIC compensating FIR filter
- add another half band filter and decimation by factor of two

