#!/bin/bash

g_wrr_queue_count=8

function log()
{
	local pid=`sh -c 'echo $PPID'`
	local func=${FUNCNAME[1]}
	echo -e "`date '+%F %T'` [$pid][$func] $*"
}

function setup_fio()
{
	rw_file="$1" # /dev/nvme0n1
	rw_test=$2 # read/write/randread/randwrite
	rw_bs=$3  # 4K/128K
}

function run_fio()
{
	local rw_name=$1
	local file=${rw_test}_${rw_name}.log
	log "start"
	fio --bs=$rw_bs \
		--ioengine=libaio \
		--iodepth=32 \
		--filename=$rw_file \
		--direct=1 \
		--runtime=60 \
		--numjobs=$g_wrr_queue_count \
		--rw=$rw_test \
		--name=${rw_name} \
		--group_reporting \
		--output $file
}

function test_perf()
{
	local wrr=$1
	local path="/sys/fs/cgroup/blkio/wrr_${wrr}"
	# get current pid and write it into cgroup.procs
	local pid=`sh -c 'echo $PPID'`

	# crate blkio cgroup test directory
	if [ ! -d $path ]; then
		log "create: $path"
		mkdir -p $path
	fi

	local file=$path/cgroup.procs
	echo $pid > $file
	log "write $pid to $file"

	# set wrr
	file=$path/blkio.wrr
	echo "$wrr" > $file
	log "write $wrr to $file"
	

	# run fio
	run_fio $wrr
}

function has_module()
{
	local md=$1
	lsmod | grep -w $md > /dev/null
	if [ $? ]; then
		log "$md moudle exist"
		return 1;
	fi

	log "$md moudle not exist"
	return 0
}

function setup_hw_queue()
{
	local md="nvme"
	local nr_read=0
	local nr_poll=0


	local total=`cat /sys/block/nvme0n1/device/queue_count`
	log "queue count $total"
	g_wrr_queue_count=`expr $total / 4` # split into 4 parts: default, low, medium, high
	local wrr_low_queues=$g_wrr_queue_count
	local wrr_medium_queues=$g_wrr_queue_count
	local wrr_high_queues=$g_wrr_queue_count

	local wrr_urgent_queues=0


	has_module $md
	if [ $? -eq 1 ]; then
		modprobe -r $md
	fi

	local file=./drivers/nvme/host/pci/$md.ko
	insmod  $file \
		read_queues=$nr_read \
		poll_queues=$nr_poll \
		wrr_low_queues=$nr_low \
		wrr_medium_queues=$nr_medium \
		wrr_high_queues=$nr_high \
		wrr_urgent_queues=$nr_urgent

	has_module $md

	local cfg=`dmesg | grep wrr | tail -1`
}


function test()
{
	test_perf high &
	test_perf medium &
	test_perf low &

	wait
	log "done"
}

setup_hw_queue


setup_fio "/dev/nvme0n1" "randread" "4K"
test
setup_fio "/dev/nvme0n1" "randwrite" "4K"
test
setup_fio "/dev/nvme0n1" "read" "512K"
test
setup_fio "/dev/nvme0n1" "write" "512K"
test
