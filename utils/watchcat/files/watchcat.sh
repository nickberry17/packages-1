#!/bin/sh
#
# Copyright (C) 2010 segal.di.ubi.pt
#
# This is free software, licensed under the GNU General Public License v2.
#

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
		echo "Error: invalid ping_size. ping_size should be either: small, windows, standard, big, huge or jumbo"
		echo "Cooresponding ping packet sizes (bytes): small=1, windows=32, standard=56, big=248, huge=1492, jumbo=9000"
		;;
	esac
	echo $ps
}

reboot_now() {
	reboot &

	[ "$1" -ge 1 ] && {
		sleep "$1"
		echo 1 >/proc/sys/kernel/sysrq
		echo b >/proc/sysrq-trigger # Will immediately reboot the system without syncing or unmounting your disks.
	}
}

watchcat_periodic() {
	local failure_period="$1"
	local force_reboot_delay="$2"

	sleep "$failure_period" && reboot_now "$force_reboot_delay"
}

watchcat_restart_modemmanager_iface() {
	[ $2 -gt 0 ] && {
		logger -t INFO "Resetting current-bands to 'any' on modem: $1 now."
		/usr/bin/mmcli -m any --set-current-bands=any
	}
	logger -t INFO "Reconnecting modem: $1 now."
	/etc/init.d/modemmanager restart
	ifup "$1"
}

watchcat_restart_network_iface() {
	logger -t INFO "Restarting network interface: $1."
	ifdown "$1"
	ifup "$1"
}

watchcat_monitor_network() {
	local failure_period="$1"
	local force_reboot_delay="$2"
	local ping_hosts="$3"
	local ping_frequency_interval="$4"
	local ping_failure_interval="$5"
	local ping_size="$6"
	local iface="$7"
	local mm_iface_name="$8"
	local mm_iface_unlock_bands="$9"

	local time_now="$(cat /proc/uptime)"
	time_now="${time_now%%.*}"

	[ "$time_now" -lt "$ping_failure_interval" ] && sleep "$((ping_failure_interval - time_now))"

	time_now="$(cat /proc/uptime)"
	time_now="${time_now%%.*}"
	local time_lastcheck="$time_now"
	local time_lastcheck_withinternet="$time_now"

	local ping_size="$(get_ping_size "$ping_size")"

	while true; do
		# account for the time ping took to return. With a ping time of 5s, ping might take more than that, so it is important to avoid even more delay.
		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		local time_diff="$((time_now - time_lastcheck))"

		[ "$time_diff" -lt "$ping_frequency_interval" ] && sleep "$((ping_frequency_interval - time_diff))"

		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_lastcheck="$time_now"

		for host in $ping_hosts; do
			if ping -I "$iface" -s "$ping_size" -c 1 "$host" &>/dev/null; then
				time_lastcheck_withinternet="$time_now"
			else
				logger -p daemon.info -t "watchcat[$$]" "no internet connectivity on "$iface" for $((time_now - time_lastcheck_withinternet)). Restarting "$iface" after reaching $failure_period"
			fi
		done

		[ "$((time_now - time_lastcheck_withinternet))" -ge "$failure_period" ] && {

			if [ "$mm_iface_name" -ne "" ]; then
				watchcat_restart_network_iface "$iface"
			else
				watchcat_restart_modemmanager_iface "$mm_iface_name" "$mm_iface_unlock_bands"
			fi
			/etc/init.d/watchcat start
		}
	done
}

watchcat_ping() {
	local failure_period="$1"
	local force_reboot_delay="$2"
	local ping_hosts="$3"
	local ping_frequency_interval="$4"
	local ping_failure_interval="$5"
	local ping_size="$6"

	local time_now="$(cat /proc/uptime)"
	time_now="${time_now%%.*}"

	[ "$time_now" -lt "$ping_failure_interval" ] && sleep "$((ping_failure_interval - time_now))"

	time_now="$(cat /proc/uptime)"
	time_now="${time_now%%.*}"
	local time_lastcheck="$time_now"
	local time_lastcheck_withinternet="$time_now"

	local ping_size="$(get_ping_size "$ping_size")"

	while true; do
		# account for the time ping took to return. With a ping time of 5s, ping might take more than that, so it is important to avoid even more delay.
		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		local time_diff="$((time_now - time_lastcheck))"

		[ "$time_diff" -lt "$ping_frequency_interval" ] && sleep "$((ping_frequency_interval - time_diff))"

		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_lastcheck="$time_now"

		for host in $ping_hosts; do
			if ping -s "$ping_size" -c 1 "$host" &>/dev/null; then
				time_lastcheck_withinternet="$time_now"
			else
				logger -p daemon.info -t "watchcat[$$]" "no internet connectivity for $((time_now - time_lastcheck_withinternet)). Reseting when reaching $failure_period"
			fi
		done

		[ "$((time_now - time_lastcheck_withinternet))" -ge "$failure_period" ] && reboot_now "$force_reboot_delay"
	done
}

mode="$1"

# Fix potential typo in mode and provide backward compatibility.
[ "$mode" = "allways" ] && mode="periodic_reboot"
[ "$mode" = "always" ] && mode="periodic_reboot"
[ "$mode" = "ping" ] && mode="ping_reboot"

case "$mode" in
periodic_reboot)
	watchcat_periodic "$2" "$3"
	;;
ping_reboot)
	watchcat_ping "$2" "$3" "$4" "$5" "$6" "$7"
	;;
restart_iface)
	watchcat_monitor_network "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
	;;
*)
	echo "Error: invalid mode selected: $mode"
	;;
esac
