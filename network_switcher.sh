#!/usr/bin/env bash

gateway_ips='1.1.1.1 8.8.8.8'

access_point_number="$(nmcli con | grep wifi | wc -l)"

# Source: https://github.com/ltpitt/bash-network-repair-automation
function check_gateways {
    for ip in $gateway_ips; do
        ping -c 3 $ip > /dev/null 2>&1
        # The $? variable always contains the return code of the previous command.
        # In BASH return code 0 usually means that everything executed successfully.
        # In the next if we are checking if the ping command execution was successful.
        if [[ $? == 0 ]]; then
            return 0
        fi
    done
    return 1
}

# TODO: Switch to the strongest next network as an option with randomly

# Remove (subtract) the using network and get (plus) from the next access point to it.
max="$((access_point_number - 1 + 2))"

# Source: https://stackoverflow.com/a/6022441/16553764
function switch_network {
    current_network_name=$(nmcli con | sed -n "2p" | cut -d ' ' -f 1)

    next_network=$(nmcli con | sed -n "3p;${max}p" | shuf -n 1 | tr -s ' ') 
    next_network_name=$(echo $next_network | cut -d ' ' -f 1)
    next_network_uuid=$(echo $next_network | cut -d ' ' -f 2)

    echo "Switch from \"$current_network_name\" to \"$next_network_name\""
    nmcli con up uuid $next_network_uuid
}

echo "🚀 Start at $(date +'%Y-%m-%d %T')"


download_threshold=1
count_threshold=7 	# (8) 4 minutes / (4) 2 minutes
count=0

while sleep 25s; do
    if ! check_gateways; then
	echo "🔴 $(date +'%Y-%m-%d %T')"
	switch_network
    fi

    count=$((count+1))

    if [[ "$count" == "$count_threshold" ]]; then 
	
	# Use this instead of `speed-cli` is because I have a feeling that speed test will not reflect as much as
	# downloading a file, and also the file seems like come from long distance server so it's is good sample too.
        speed_text="$(wget -O /dev/null http://speedtest.tele2.net/10MB.zip 2>&1 | grep -o '\([0-9.]\+ [KM]B/s\)')"

	echo "🚦 $speed_text at $(date +'%Y-%m-%d %T')"

	speed="$(echo $speed_text | cut -d ' ' -f 1)"

	# If KB/s, convert in into MB/s
	if [[ "$(echo $speed_text | cut -d ' ' -f 2)" == "KB/s" ]]; then
	    speed=$(echo "$speed/1024" | bc -l)
	fi

	# ? Bash doesn't support floating point arithmetic but when I compare it, it's still working fine?
	# ? It connected to the next access point when the download was at 1007 KB/s (didn't covert to MB/s 😮),
	# ? 1.07 and 1.08 MB/s (check out the log file for more).
	#
	# And also floating point arithmetic only needed when the threshold is larger (smaller) than 1, 
	# because KB/s only printed for below 1024 KB (1 MB).
	#
	# Example: if (( $(echo "$speed/1024 < 1" |bc -l) )); then echo "Yes Sir"; fi
	# if [[ "$speed" < "$download_threshold" ]]; then switch_network; fi
	if (( $(echo "$speed < $download_threshold" | bc -l) )); then 
	    switch_network
	fi

	count=0
    fi
done
