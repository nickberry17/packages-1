#!/bin/sh
#
# Copyright (C) 2010 segal.di.ubi.pt
#
# This is free software, licensed under the GNU General Public License v2.
#

mode="$1"

# Fix potential typo in mode (backward compatibility).
[ "$mode" = "allways" ] && mode="always"

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
		echo "Error: invalid pingsize. pingsize should be small, windows, standard, big, huge or jumbo"
		echo "Cooresponding ping packet sizes (bytes): small=1, windows=32, standard=56, big=248, huge=1492, jumbo=9000"
		;;
	esac
	echo $ps
}

shutdown_now() {
	local forcedelay="$1"

	reboot &

	[ "$forcedelay" -ge 1 ] && {
		sleep "$forcedelay"

		echo b >/proc/sysrq-trigger # Will immediately reboot the system without syncing or unmounting your disks.
	}
}

watchcat_always() {
	local period="$1"
	local forcedelay="$2"

	sleep "$period" && shutdown_now "$forcedelay"
}

watchcat_restart_modemmanager() {
	logger -t INFO "Connection lost. Resetting bands and reconnecting modem now."
	/usr/bin/mmcli -m any --set-current-bands=any
	/etc/init.d/modemmanager restart
	ifup mobiledata
}

watchcat_monitor_modemmanager() {
	local period="$1"
	local forcedelay="$2"
	local pinghosts="$3"
	local pingperiod="$4"
	local pingsize="$5"

	time_now="$(cat /proc/uptime)"
	time_now="${time_now%%.*}"
	time_lastcheck="$time_now"
	time_lastcheck_withinternet="$time_now"

	pingsize="$(get_ping_size "$pingsize")"

	while true; do
		# account for the time ping took to return. With a ping time of 5s, ping might take more than that, so it is important to avoid even more delay.
		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_diff="$((time_now - time_lastcheck))"

		[ "$time_diff" -lt "$pingperiod" ] && {
			sleep_time="$((pingperiod - time_diff))"
			sleep "$sleep_time"
		}

		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_lastcheck="$time_now"

		for host in $pinghosts
		do
			if ping -c 1 "$host" &> /dev/null
			then
				time_lastcheck_withinternet="$time_now"
			else
				time_diff="$((time_now-time_lastcheck_withinternet))"
				logger -p daemon.info -t "watchcat[$$]" "no internet connectivity for $time_diff seconds. Restarting modem reaching $period"
			fi
		done

		time_diff="$((time_now - time_lastcheck_withinternet))"
		[ "$time_diff" -ge "$period" ] && {
			watchcat_restart_modemmanager
			/etc/init.d/watchcat start
		}

	done
}

watchcat_ping() {
	local period="$1"
	local forcedelay="$2"
	local pinghosts="$3"
	local pingperiod="$4"
	local pingsize="$5"

	time_now="$(cat /proc/uptime)"
	time_now="${time_now%%.*}"
	time_lastcheck="$time_now"
	time_lastcheck_withinternet="$time_now"

	pingsize="$(get_ping_size "$pingsize")"

	while true; do
		# account for the time ping took to return. With a ping time of 5s, ping might take more than that, so it is important to avoid even more delay.
		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_diff="$((time_now - time_lastcheck))"

		[ "$time_diff" -lt "$pingperiod" ] && {
			sleep_time="$((pingperiod - time_diff))"
			sleep "$sleep_time"
		}

		time_now="$(cat /proc/uptime)"
		time_now="${time_now%%.*}"
		time_lastcheck="$time_now"

		for host in $pinghosts; do
			if ping -s "$pingsize" -c 1 "$host" &>/dev/null; then
				time_lastcheck_withinternet="$time_now"
			else
				time_diff="$((time_now - time_lastcheck_withinternet))"
				logger -p daemon.info -t "watchcat[$$]" "no internet connectivity for "$time_diff" seconds. Rebooting this router when reaching "$period""
			fi
		done

		time_diff="$((time_now - time_lastcheck_withinternet))"
		[ "$time_diff" -ge "$period" ] && shutdown_now "$forcedelay"

	done
}

case "$mode" in
always)
	watchcat_always "$2" "$3"
	;;
ping)
	watchcat_ping "$2" "$3" "$4" "$5" "$6"
	;;
network)
	watchcat_monitor_modemmanager "$2" "$3" "$4" "$5" "$6"
	;;
*)
	echo "Error: invalid mode selected: $mode"
	;;
esac
