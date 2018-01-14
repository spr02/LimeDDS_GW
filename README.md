# Custom gateware for the LimeSDR
This is a custom gateware for the LimeSDR, that includes the [DDS Core](https://github.com/spr02/DDS). Using this core the LimeSDR can be configured to be used as a single-tone or sweep generator. Furthermore a complex mixer can be enabled in the receive path that can mix the generated output signal with the received signal. This is makes it possible to extract a beat frequency and is therefore a dooropener for FMCW radar applications up to 60MHz bandwidth using the LimeSDR.

## Dependencies


## Build


## Run


## TODO
- enable signal for DDS core
- valid signal for DDS core
- frequency sweep for DDS core
- complex multiplier
- module that generates iq sel signal according to mimo_en and i/q data
