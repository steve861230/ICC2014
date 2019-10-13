#---------------------------------------
#-- How to use this Makefile?
#--   1. RTL simulation:
#--         make rtlsim
#--   2. Gate-level simulation:
#--         make glsim
#---------------------------------------
#-- note: 
#--   You should edit your "design name" 
#--   and "simulation command".
#---------------------------------------

## edit your design name
rtl_design = STI_DAC.v

## edit your gate-level netlist
netlist = STI_DAC_syn.v

## edit testbench name
testfixture = testfixture1.v

## cell library gate
tsmc13 = /usr/cad/CBDK/CBDK_IC_Contest_v2.1/Verilog/tsmc13.v
tsmc13_neg = /usr/cad/CBDK/CBDK_IC_Contest_v2.1/Verilog/tsmc13_neg.v

## edit your RTL simulation command
rtlsim:
	ncverilog $(testfixture) $(rtl_design) +access+r +notimingcheck

## edit your gate-level simulation command
glsim:
	ncverilog $(testfixture) $(netlist) -v $(tsmc13) $(tsmc13_neg) +access+r +define+SDF
