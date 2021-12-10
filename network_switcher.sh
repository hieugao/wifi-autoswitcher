#!/usr/bin/env bash

gateway_ips='1.1.1.1 8.8.8.8'

# Subtract the using network and get from the next access point to it.
max="$(($(nmcli con | grep wifi | wc -l ) - 1 + 2))"

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

echo "🚀 Start at $(date +'%Y-%m-%d %T')"

while sleep 25s; do
    if ! check_gateways; then
	echo "🔴 $(date +'%Y-%m-%d %T')"

	# Source: https://stackoverflow.com/a/6022441/16553764
	nmcli con up uuid $(nmcli con | sed -n "3p;${max}p" | shuf -n 1 | tr -s ' ' | cut -d ' ' -f 2)
    fi
done
