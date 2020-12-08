#!/bin/sh
#
# Copyright (C) 2010 segal.di.ubi.pt
# Copyright (C) 2020 nbembedded.com
# Support for multiple interfaces, ModemManager interfaces, restarting
# an interface, and ping packet size added by nbembedded.com
#
# This is free software, licensed under the GNU General Public License v2.
#

mode="$1"

# Fix potential typo in mode and provide backward compatibility.
[ "$mode" = "allways" ] && mode="periodic_reboot"
[ "$mode" = "always" ] && mode="periodic_reboot"
[ "$mode" = "ping" ] && mode="ping_reboot"

get_ping_size() {
	ps=$1
	case "$ps" in
	small)
		ps="1"
		;;
	windows)
		ps="32"
		;;
	standard)
		ps="56"
		;;
	big)
		ps="248"
		;;
	huge)
		ps="1492"
		;;
	jumbo)
		ps="9000"
		;;
	*)
		echo "Error: invalid ping_size. ping_size should be small, windows, standard, big, huge or jumbo"
		echo "Cooresponding ping packet sizes (bytes): small=1, windows=32, standard=56, big=248, huge=1492, jumbo=9000"
		;;
	esac
	echo $ps
}

shutdown_now() {
	local force_delay="$1"

	reboot &

	[ "$force_delay" -ge 1 ] && {
		sleep "$force_delay"

		echo b >/proc/sysrq-trigger # Will immediately reboot the system without syncing or unmounting your disks.
	}
}

watchcat_periodic() {
	local period="$1"
	local force_delay="$2"

	sleep "$period" && shutdown_now "$force_delay"
}

watchcat_restart_modemmanager_iface() {
	logger -t INFO "Resetting bands and reconnecting modem: $1 now."
	/usr/bin/mmcli -m any --set-current-bands=any
	/etc/init.d/modemmanager restart
	ifup "$1"
}

watchcat_restart_network_iface() {
	logger -t INFO "Restarting network interface: $1."
	ifdown "$1"
	ifup "$1"
}

watchcat_monitor_network() {
	local period="$1"
	local force_delay="$2"
	local ping_hosts="$3"
	local ping_period="$4"
	local ping_size="$5"
	local wc_interface="$6"
	local mm_iface_name="$7"

	time_now="$(cat /proc/uptime)"
	time_now="${time_now%%.*}"
	time_lastcheck="$time_now"
	time_lastcheck_withinternet="$time_now"
	ping_size="$(get_ping_size "$ping_size")"

	while true; do
		# account for the time ping took to return. With a ping time of 5s, ping might take more than that, so it is important to avoid even more delay.
		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_diff="$((time_now - time_lastcheck))"

		[ "$time_diff" -lt "$ping_period" ] && {
			sleep_time="$((ping_period-time_diff))"
			sleep "$sleep_time"
		}

		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_lastcheck="$time_now"

		for host in $ping_hosts
		do
			if ping -I "$wc_interface" -c 1 "$host" &> /dev/null
			then
				time_lastcheck_withinternet="$time_now"
			else
				time_diff="$((time_now-time_lastcheck_withinternet))"
				logger -p daemon.info -t "watchcat[$$]" "no internet connectivity on interface $wc_interface for $time_diff seconds. Restarting $wc_interface after reaching $period"
			fi
		done

		time_diff="$((time_now - time_lastcheck_withinternet))"
		[ "$time_diff" -ge "$period" ] && {
			if [ "$mm_iface_name" -ne "" ] 
			then
				watchcat_restart_network_iface "$wc_interface"
			else
				watchcat_restart_modemmanager_iface "$mm_iface_name"
			fi
			/etc/init.d/watchcat start
		}

	done
}

watchcat_ping() {
	local period="$1"
	local force_delay="$2"
	local ping_hosts="$3"
	local ping_period="$4"
	local ping_size="$5"

	time_now="$(cat /proc/uptime)"
	time_now="${time_now%%.*}"
	time_lastcheck="$time_now"
	time_lastcheck_withinternet="$time_now"

	ping_size="$(get_ping_size "$ping_size")"

	while true; do
		# account for the time ping took to return. With a ping time of 5s, ping might take more than that, so it is important to avoid even more delay.
		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_diff="$((time_now - time_lastcheck))"

		[ "$time_diff" -lt "$ping_period" ] && {
			sleep_time="$((ping_period-time_diff))"
			sleep "$sleep_time"
		}

		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_lastcheck="$time_now"

		for host in $ping_hosts; do
			if ping -s "$ping_size" -c 1 "$host" &>/dev/null; then
				time_lastcheck_withinternet="$time_now"
			else
				time_diff="$((time_now-time_lastcheck_withinternet))"
				logger -p daemon.info -t "watchcat[$$]" "no internet connectivity for $time_diff seconds. Rebooting this router when reaching $period"
			fi
		done

		time_diff="$((time_now-time_lastcheck_withinternet))"
		[ "$time_diff" -ge "$period" ] && shutdown_now "$force_delay"

	done
}

case "$mode" in
periodic_reboot)
	watchcat_periodic "$2" "$3"
	;;
ping_reboot)
	watchcat_ping "$2" "$3" "$4" "$5" "$6"
	;;
restart_iface)
	watchcat_monitor_network "$2" "$3" "$4" "$5" "$6" "$7"
	;;
*)
	echo "Error: invalid mode selected: $mode"
	;;
esac
