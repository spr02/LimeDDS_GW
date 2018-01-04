set module [lindex $quartus(args) 0]
 
if [string match "quartus_asm" $module] {
	# Include commands here that are run after the assember
	post_message "Running after assembler"
	set cmd "quartus_cpf -c rbf_file_setup.cof"
	#qexec "quartus_cpf -c rbf_file_setup.cof"
	# If the command can't be run, return an error.
	if { [catch {open "|$cmd"} input] } {
		return -code error $input
  }
}
post_message "*******************************************************************"
post_message "Generated programming file: LimeSDR-USB_lms7_dds_trx_HW_1.4.rbf" -submsgs [list "Output file saved in /output_files directory"]
post_message "*******************************************************************"
