
#set -x
#fields: case bw iops rd_avg_lat wr_avg_lat

function showm()
{
	# test_fio  RR_metric_1 RR_metric_2  WRR_metric1 WRR_metric2
	printf "%-20s %-15s %-15s %-15s %-15s\n" "$1" "$2" "$3" "$4" "$5"
}

function show_header()
{
	local TC="$1"  # test case
	local M1="$2"  # metric 1
	local M2="$3"  # metric 2
	# test_fio  RR_metric_1 RR_metric_2  WRR_metric1 WRR_metric2
	#printf "%-20s %-15s %-15s %-15s %-15s\n" "$TC" "(RR)$M1" "(RR)$M2" "(WRR)$M1" "(WRR)$M2"
	showm "$TC" "(RR)$M1" "(RR)$M2" "(WRR)$M1" "(WRR)$M2"
	echo "--------------------------------------------------------------------------------"
}

function show_body()
{
	local level="high medium low"
	local l
	local TC="$1"  # test case
	local MF1=$2   # metric 1 field index
	local MF2=$3   # metric 2 field index

	for l in $level
	do
		local pt=${TC}_$l
		local rrm1 rrm2 wrrm1 wrrm2
		#rr
		local rrfile=./rr.log
		local wrrfile=./wrr.log
		eval `grep ^$pt $rrfile | awk -v f1=$MF1 -v f2=$MF2 '{printf("rrm1=%s;rrm2=%s;\n", $f1, $f2)}'`
		eval `grep ^$pt $wrrfile | awk -v f1=$MF1 -v f2=$MF2 '{printf("wrrm1=%s;wrrm2=%s;\n", $f1, $f2)}'`
		showm $pt $rrm1 $rrm2 $wrrm1 $wrrm2
	done

	printf "\n\n"
}

#fields: case bw iops rd_avg_lat wr_avg_lat
function show_randread()
{
	# randread
	tc=randread
	mf1=3
	mf2=4
	m1="IOPS"
	m2="latency"

	show_header $tc $m1 $m2
	show_body $tc $mf1 $mf2
}

#fields: case bw iops rd_avg_lat wr_avg_lat
function show_randwrite()
{
	# randwrite
	tc=randwrite
	mf1=3
	mf2=5
	m1="IOPS"
	m2="latency"

	show_header $tc $m1 $m2
	show_body $tc $mf1 $mf2
}

#fields: case bw iops rd_avg_lat wr_avg_lat
function show_randwrite()
{
	# randwrite
	tc=randwrite
	mf1=3
	mf2=5
	m1="IOPS"
	m2="latency"

	show_header $tc $m1 $m2
	show_body $tc $mf1 $mf2
}

#fields: case bw iops rd_avg_lat wr_avg_lat
function show_read()
{
	# read
	tc=read
	mf1=2
	mf2=4
	m1="BW"
	m2="latency"

	show_header $tc $m1 $m2
	show_body $tc $mf1 $mf2
}
#fields: case bw iops rd_avg_lat wr_avg_lat
function show_write()
{
	# write
	tc=write
	mf1=2
	mf2=5
	m1="BW"
	m2="latency"

	show_header $tc $m1 $m2
	show_body $tc $mf1 $mf2
}

if [ ! -d ./rr ]; then
	echo "not found directory: rr"
	exit
fi

if [ ! -d ./wrr ]; then
	echo "not found directory: wrr"
	exit
fi

# generate compare file rr and wrr
pushd rr
../parse_fio_terse.sh . > ../rr.log
popd
pushd wrr
../parse_fio_terse.sh . > ../wrr.log
popd
show_randread
show_randwrite
show_read
show_write

