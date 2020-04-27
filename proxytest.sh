#!/bin/bash

############################################################
# author: sedgwickz
# email: kunnsh@gmail.com
# usage: ./proxytest.sh [v2ray|shadowsocks-libev] [method]
# example: ./proxytest.sh shadowsocks-libev aes-256-gcm
#
############################################################

p_type=$1
method=$2
password=123456
local_port=20000
tunnel_port=20001
server_port=20002

v2ray_config=ewogICAiaW5ib3VuZCI6IHsKICAgICAgICAicHJvdG9jb2wiOiAic2hhZG93c29ja3MiLAogICAgICAgICJwb3J0IjogMjAwMDIsCiAgICAgICAgInNldHRpbmdzIjogewogICAgICAgICAgICAibWV0aG9kIjogImFlcy0yNTYtZ2NtIiwKICAgICAgICAgICAgInBhc3N3b3JkIjogIjEyMzQ1NiIsCiAgICAgICAgICAgICJsZXZlbCI6IG51bGwKICAgICAgICB9CiAgICB9LAogICAgIm91dGJvdW5kIjogewogICAgICAgICJwcm90b2NvbCI6ICJmcmVlZG9tIiwKICAgICAgICAic2V0dGluZ3MiOiB7fQogICAgfSwKICAgICJpbmJvdW5kRGV0b3VyIjogW10sCiAgICAib3V0Ym91bmREZXRvdXIiOiBbCiAgICAgICAgewogICAgICAgICAgICAicHJvdG9jb2wiOiAiYmxhY2tob2xlIiwKICAgICAgICAgICAgInNldHRpbmdzIjoge30sCiAgICAgICAgICAgICJ0YWciOiAiYmxvY2tlZCIKICAgICAgICB9CiAgICBdLAogICAgInJvdXRpbmciOiB7CiAgICAgICAgInN0cmF0ZWd5IjogInJ1bGVzIiwKICAgICAgICAic2V0dGluZ3MiOiB7CiAgICAgICAgICAgICJydWxlcyI6IFsKICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAgICAidHlwZSI6ICJmaWVsZCIsCiAgICAgICAgICAgICAgICAgICAgImlwIjogWwogICAgICAgICAgICAgICAgICAgICAgICI6OjEvMTI4IiwKICAgICAgICAgICAgICAgICAgICAgICAgImZjMDA6Oi83IiwKICAgICAgICAgICAgICAgICAgICAgICAgImZlODA6Oi8xMCIKICAgICAgICAgICAgICAgICAgICBdLAogICAgICAgICAgICAgICAgICAgICJvdXRib3VuZFRhZyI6ICJibG9ja2VkIgogICAgICAgICAgICAgICAgfQogICAgICAgICAgICBdCiAgICAgICAgfQogICAgfQp9

usage() {
	echo "usage: ./proxytest.sh [v2ray|shadowsocks-libev] [method]"
}

exists() {
	command -v "$1" >/dev/null 2>&1
}

check_environment() {
	if ! exists ss-tunnel; then
		echo "ss-tunnel doesn't exist, please install shadowsocks-libev"
		exit 1
	fi

	if ! exists iperf3; then
		echo "iperf3 doesn't exist"
		exit 1
	fi
}

ss_test() {
	check_environment
	ss-tunnel -l $local_port -L 127.0.0.1:$tunnel_port -s 127.0.0.1 -p $server_port -m $method -k $password &
	ss_tunnel_pid=$!
	ss-server -s 127.0.0.1 -p $server_port -m $method -k $password &
	ss_pid=$!

	iperf3 -s -p $tunnel_port >/dev/null 2>&1 & 
	iperf3_pid=$!

	sleep 3
	iperf3 -c 127.0.0.1 -p $local_port -R  

	sleep 3
	kill $iperf3_pid $ss_tunnel_pid $ss_pid
	echo "finished!🚀"
}

v2ray_test() {
	check_environment
	exists v2ray || (echo "v2ray doesn't exist"; exit 1)
	exists base64 || (echo "openssl doesn't exist"; exit 1)
	ss-tunnel -l $local_port -L 127.0.0.1:$tunnel_port -s 127.0.0.1 -p $server_port -m $method -k $password &
	ss_tunnel_pid=$!
	temp_file=$(mktemp)
	echo $v2ray_config | base64 -d | sed -e "s/20002/$server_port/g" | sed -e "s/aes-256-gcm/$method/g" | sed -e "s/123456/$password/g" > $temp_file
	v2ray -c $temp_file &
	v2ray_pid=$!

	iperf3 -s -p $tunnel_port >/dev/null 2>&1 &
	iperf3_pid=$!
	
	sleep 3
	iperf3 -c 127.0.0.1 -p $local_port -R	
	kill $iperf3_pid $ss_tunnel_pid $v2ray_pid
	rm $temp_file
	echo "finished!🚀"
}

no_proxy() {
	exists iperf3 || (echo "iperf3 doesn't exist; exit 1")
	iperf3 -s -p $server_port >/dev/null 2>&1 &
	iperf3_pid=$!
	
	sleep 3
	iperf3 -c 127.0.0.1 -p $server_port -R	
	kill $iperf3_pid 
	echo "finished!🚀"
}

main() {
	if [ "${p_type,,}" == "shadowsocks-libev" ]; then
		ss_test
	elif [ "${p_type,,}" == "v2ray" ]; then
		v2ray_test
	else
		no_proxy
	fi
}

while getopts 'h' option; do
	case "$option" in
		h) usage; exit 0;;
	esac
done

main
