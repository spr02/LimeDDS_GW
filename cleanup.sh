rm -f ddr2_phy0_summary.csv ddr2_phy1_summary.csv ddr2_phy_autodetectedpins.tcl PLLJ_PLLSPE_INFO.txt LimeSDR-USB_lms7_trx.qws
rm -rf db incremental_db

# remove all generated files in output_files
pushd output_files
find . ! -name 'rbf_file_setup.cof' -type f -exec rm -f {} +
#ls | grep -v rbf_file_setup.cof | xargs rm -f
popd
