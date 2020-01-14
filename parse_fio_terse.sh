#!/bin/bash

function parse_bw_iops_lat_mean()
{
	local file=$1

	#  7 read_bandwidth
	# 48 write_bandwidth
	local bw=`awk -F ";" '{printf("%ld\n", $7 + $48)}' $file`

	#  8 read_iops
	# 49 write_iops
	local iops=`awk -F ";" '{printf("%ld\n", $8 + $49)}' $file`

	# 40 read_lat_mean
	local read_lat_mean=`awk -F ";" '{print $40}' $file`
	# 81 write_lat_mean
	local write_lat_mean=`awk -F ";" '{print $81}' $file`

	printf "%-20s %10d %10d %-10.2f %-10.2f\n", $file $bw $iops $read_lat_mean $write_lat_mean
}

parse_bw_iops_lat_mean $1
