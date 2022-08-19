#/*================================================*\
#		  Filename 	﹕ start.do
#			Author 	﹕ Adolph
#	  Description  	﹕ Modelsim 仿真脚本文件
#		 Called by 	﹕ No file
#Revision History   ﹕ 
#		  			  Revision 1.0
#  			  Email	﹕ adolph1354238998@gmail.com
#\*================================================*/
#此脚本文件存放于工程文件夹下的tb子文件夹
#在 modelsim 的 transcript 窗口执行的时候使用
# do filename.do 命令后，自动执行仿真

#编译仿真库
transcript on
if ![file isdirectory verilog_libs] {
	file mkdir verilog_libs
}

vlib verilog_libs/altera_ver
vmap altera_ver ./verilog_libs/altera_ver
vlog -vlog01compat -work altera_ver {d:/intelfpga/18.1/quartus/eda/sim_lib/altera_primitives.v}
	# d:/intelfpga/18.1/quartus/eda/sim_lib/ 前述地址为Quartus 本地安装路径
	
vlib verilog_libs/lpm_ver
vmap lpm_ver ./verilog_libs/lpm_ver
vlog -vlog01compat -work lpm_ver {d:/intelfpga/18.1/quartus/eda/sim_lib/220model.v}

vlib verilog_libs/sgate_ver
vmap sgate_ver ./verilog_libs/sgate_ver
vlog -vlog01compat -work sgate_ver {d:/intelfpga/18.1/quartus/eda/sim_lib/sgate.v}

vlib verilog_libs/altera_mf_ver
vmap altera_mf_ver ./verilog_libs/altera_mf_ver
vlog -vlog01compat -work altera_mf_ver {d:/intelfpga/18.1/quartus/eda/sim_lib/altera_mf.v}

vlib verilog_libs/altera_lnsim_ver
vmap altera_lnsim_ver ./verilog_libs/altera_lnsim_ver
vlog -sv -work altera_lnsim_ver {d:/intelfpga/18.1/quartus/eda/sim_lib/altera_lnsim.sv}

vlib verilog_libs/cycloneive_ver
vmap cycloneive_ver ./verilog_libs/cycloneive_ver
vlog -vlog01compat -work cycloneive_ver {d:/intelfpga/18.1/quartus/eda/sim_lib/cycloneive_atoms.v}

#检查是否存在rtl_work,如果存在，则删除
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}

#建立 rtl_work
vlib rtl_work
vmap work rtl_work

#编译 testbench文件					       	
vlog    tb_IIC.v

#编译 设计文件（位于工程文件夹下的rtl子文件夹）					       	 
vlog ../rtl/IIC.v
#vlog ../rtl/*.v
#vlog ../rtl/*.v

#编译 IP文件
#如果设计中有IP文件，则需要找到所在路径下的.v文件，添加进来
#vlog ../rtl/.v

#指定仿真顶层模块	
#-L altera_ver 			这几个为可选项，用到谁的IP，就添加谁，不清楚就全部保留
#-L lpm_ver 	       
#-L sgate_ver 	        其他暂时没查到
#-L altera_mf_ver 	    PLL、ROM、RAM、FIFO、
#-L altera_lnsim_ver	接口相关
#-L cycloneive_ver	    

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cycloneive_ver -L rtl_work -L work -voptargs="+acc"  tb_IIC

#添加信号到波形窗 							  
#add wave -position insertpoint sim:/tb_IIC//*

do wave.do

run -all 