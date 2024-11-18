#!/bin/bash

# Check root
WHOAMI=$(whoami)

if [[ "$WHOAMI" != "root" ]]; then
        echo "This script needs to be run as root or with sudo, exiting"
        exit 1
else
        echo "current user has correct permissions"
fi
# Variables
PROG_NAME=$(/bin/basename "$0" | cut -d . -f1)
LOGFACILITY="local7"
LOGLEVEL="notice"

# Check if wifi is enabled
if ! nmcli radio wifi; then
    echo "WiFi is disabled. Enabling WiFi..."
    nmcli radio wifi on
fi


# Standard logging function
logmessage() {
    msg="${1}"
    logger -p ${LOGFACILITY}.${LOGLEVEL} -t "${PROG_NAME}" "${msg}"
    echo "$(date) $(uname -n) ${PROG_NAME}: ${msg}"
}

# Debug logging function
function debugecho() {
    [[ $VERBOSE ]] && logmessage "$@"
}

# Help/usage function
function usage() {
    echo "usage: ${PROG_NAME} -s <SSID> -p <password> [-v]"
    exit 1
}

# Main script logic
while getopts ":s:p:vh" opt; do
    case ${opt} in
        s )
            SSID=$OPTARG
            logmessage "SSID specified: $SSID"
            ;;
        p )
            PASSWORD=$OPTARG
            logmessage "Password specified."
            ;;
        v )
            VERBOSE=true
            logmessage "Verbose mode enabled."
            ;;
        h )
            usage
            ;;
        \? )
            logmessage "Invalid option: -$OPTARG"
            usage
            ;;
        : )
            logmessage "Invalid option: -$OPTARG requires an argument."
            usage
            ;;
    esac
done

# Check if SSID and PASSWORD are set
if [ -z "$SSID" ] || [ -z "$PASSWORD" ]; then
    logmessage "SSID or password not specified. Exiting."
    usage
fi

# Connect to Wi-Fi
logmessage "Attempting to connect to Wi-Fi network: $SSID"

# Attempt to connect to the Wi-Fi network
nmcli device wifi connect "$SSID" password "$PASSWORD"
if [ $? -eq 0 ]; then
    logmessage "Successfully connected to $SSID."
else
    logmessage "Failed to connect to $SSID."
    exit 1
fi

# Check connection status
CONNECTION_STATUS=$(nmcli -t -f ACTIVE,SSID dev wifi | grep -E "^yes:$SSID")
if [ -n "$CONNECTION_STATUS" ]; then
    logmessage "Connection status: Connected to $SSID."
else
    logmessage "Connection status: Not connected to $SSID."
fi

logmessage "Script completed successfully."

nmcli con show
