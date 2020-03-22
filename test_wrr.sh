#!/bin/bash

KERNEL_SOURCE_DIR=/root/zwp/src/5.6
g_wrr_queue_count=8
g_dev_name="nvme0n1"

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
	log "start run fio: $rw_test $rw_name"
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
		--terse-version=3 \
		--minimal \
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
	local major_minor=`cat /sys/block/${g_dev_name}/dev`
	echo "$major_minor $wrr" > $file
	log "write $major_minor $wrr to $file"
	

	# run fio
	local index
	if [ $wrr == "low" ]; then
		index="03"
	elif [ $wrr == "medium" ]; then
		index="02"
	else
		index="01"
	fi
	run_fio ${index}_${wrr}
}

function has_module()
{
	local md=$1
	lsmod | grep -w $md > /dev/null
	if [ $? -eq 0 ]; then
		log "$md moudle exist"
		return 1;
	fi

	log "$md moudle not exist"
	return 0
}

function modify_hw_weight()
{
       local h=64
       local m=32
       local l=8
       local ab=0

       nvme set-feature /dev/${g_dev_name} -f 1 -v `printf "0x%x\n" $(($ab<<0|$l<<8|$m<<16|$h<<24))`

	log "nvme weight, high=$h, medium=$m, low=$l"
}

function setup_hw_queue()
{
	local md="nvme"
	local nr_read=0
	local nr_poll=0
	local no_arg=$1


	# preload nvme module
	modprobe nvme
	sleep 3

	local qcnt_file=/sys/block/${g_dev_name}/device/queue_count
	local total=0
	if [ -e $qcnt_file ]; then
		total=`cat $qcnt_file`
	else
		total=`ls /sys/block/${g_dev_name}/mq/ | wc -l`
	fi
	log "queue count $total"
	g_wrr_queue_count=`expr $total / 4` # split into 4 parts: default, low, medium, high
	log "g_wrr_queue_count: $g_wrr_queue_count"
	local nr_low=$g_wrr_queue_count
	local nr_medium=$g_wrr_queue_count
	local nr_high=$g_wrr_queue_count
	local nr_urgent=0

	has_module $md
	if [ $? -eq 1 ]; then
		modprobe -r $md
	fi

	dmesg -C

	local file=$KERNEL_SOURCE_DIR/drivers/nvme/host/nvme-core.ko
	insmod $file
	file=$KERNEL_SOURCE_DIR/drivers/nvme/host/$md.ko
	if [ $no_arg -eq 1 ]; then
		insmod $file
	else
		insmod  $file \
			read_queues=$nr_read \
			poll_queues=$nr_poll \
			wrr_low_queues=$nr_low \
			wrr_medium_queues=$nr_medium \
			wrr_high_queues=$nr_high \
			wrr_urgent_queues=$nr_urgent
	fi

	# wait module ready
	while true
	do
		has_module $md
		if [ $? -eq 1 ]; then
			break;
		fi
		sleep 1
		echo "$md not ready, retry"
	done

	# wait nvme block device initilization done
	while true
	do
		lsblk | grep nvme > /dev/null 2>&1
		if [ $? -eq 0 ]; then
			break;
		fi
		sleep 0.1
	done
	local cfg=`dmesg | grep "urgent queues" | tail -1`
	log "$cfg"

	modify_hw_weight
}


function test()
{
	test_perf high &
	test_perf medium &
	test_perf low &

	wait
	log "done"
}

function test_rr()
{
	# do set any module parameters when load module
	setup_hw_queue 1

	# set wrr queues
	#setup_hw_queue 0


	setup_fio "/dev/${g_dev_name}" "randread" "4K"
	test
	setup_fio "/dev/${g_dev_name}" "randwrite" "4K"
	test
	setup_fio "/dev/${g_dev_name}" "read" "512K"
	test
	setup_fio "/dev/${g_dev_name}" "write" "512K"
	test

	dir="rr"
	rm -rf $dir
	mkdir $dir
	mv *.log $dir

}

function test_wrr()
{
	# do set any module parameters when load module
	#setup_hw_queue 1

	# set wrr queues
	setup_hw_queue 0

	setup_fio "/dev/${g_dev_name}" "randread" "4K"
	test
	setup_fio "/dev/${g_dev_name}" "randwrite" "4K"
	test
	setup_fio "/dev/${g_dev_name}" "read" "512K"
	test
	setup_fio "/dev/${g_dev_name}" "write" "512K"
	test

	dir="wrr"
	rm -rf $dir
	mkdir $dir
	mv *.log $dir
}

log "start test NVMe rr"
test_rr

sleep 30

log "start test NVMe wrr"

test_wrr

log "start compare data"

./cmp.sh
