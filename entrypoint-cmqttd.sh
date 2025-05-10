#!/usr/bin/with-contenv bashio
# This line is commented out is did contain - "#!/bin/sh"
# This script is used as the entrypoint for the cmqttd Docker container. It is not intended for use
# outside of that environment.
#
# This allows passing configuration flags as environment variables, which are more Docker friendly.


# Import the add-on configuration options as environment variables
echo "Importing the add-on configuration options as script variables"

MQTT_USER=$(bashio::config 'mqtt_user')
MQTT_PASSWORD=$(bashio::config 'mqtt_password')
MQTT_SERVER=$(bashio::config 'mqtt_broker_address')
TCP_OR_SERIAL=$(bashio::config 'tcp_or_serial')
CBUS_CONNECTION=$(bashio::config 'cbus_connection_string')
MQTT_USE_TLS=$(bashio::config 'use_tls_for_mqtt')
MQTT_PORT=$(bashio::config 'mqtt_broker_port')
CMQTTD_CA_CERT_PATH=$(bashio::config 'broker_ca')
CMQTTD_CLIENT_CERT_PATH=$(bashio::config 'broker_client_cert')
CMQTTD_CLIENT_KEY_PATH=$(bashio::config 'broker_client_key')
CMQTTD_PROJECT_FILE=$(bashio::config 'project_file')
CBUS_TIMESYNC=$(bashio::config 'timesync')
CBUS_CLOCK=$(bashio::config 'no_clock')
CMQTTD_LOG_LEVEL=$(bashio::config 'log_verbosity')
CBUS_NETWORK_NUMBER=$(bashio::config 'cbus_network_number')


echo "Completed importing addon configuration options"

# The following variables values were passed through via the Home Assistant add on configuration options
echo "The following variable values were passed through via the Home Assistant add on configuration options"
echo "MQTT_USER = $MQTT_USER"
echo "MQTT_PASSWORD = NOT DISPLAYED IN LOG FILE"
echo "MQTT_SERVER = $MQTT_SERVER"
echo "TCP_OR_SERIAL = $TCP_OR_SERIAL"
echo "CBUS_CONNECTION = $CBUS_CONNECTION"
echo "MQTT_USE_TLS = $MQTT_USE_TLS"
echo "MQTT_PORT = $MQTT_PORT"
echo "CMQTTD_CA_CERT_PATH = $CMQTTD_CA_CERT_PATH"
echo "CMQTTD_CLIENT_CERT_PATH = $CMQTTD_CLIENT_CERT_PATH"
echo "CMQTTD_CLIENT_KEY_PATH = $CMQTTD_CLIENT_KEY_PATH"
echo "CMQTTD_PROJECT_FILE = $CMQTTD_PROJECT_FILE"
echo "CBUS_TIMESYNC = $CBUS_TIMESYNC"
echo "CBUS_CLOCK = $CBUS_CLOCK"
echo "CMQTTD_LOG_LEVEL = $CMQTTD_LOG_LEVEL"
echo "CBUS_NETWORK_NUMBER = $CBUS_NETWORK_NUMBER"

# Create the auth file
echo "Creating file /etc/cmqttd/auth"
mkdir -p /etc/cmqttd/
echo -e "$MQTT_USER\n$MQTT_PASSWORD" > /etc/cmqttd/auth


# Authentication file for MQTT
CMQTTD_AUTH_FILE="/etc/cmqttd/auth"


# MQTT use TLS
if [ "${MQTT_USE_TLS}" == "null" ]; then
      MQTT_USE_TLS="false"
fi

# C-Bus Clock
if [ "${CBUS_CLOCK}" == "null" ]; then
      CBUS_CLOCK="true"
fi

# C-BUS Time Sync
if [ "${CBUS_TIMESYNC}" == "null" ]; then
      CBUS_TIMESYNC="300"
fi


# Arguments that are always required.
CMQTTD_ARGS="--broker-address ${MQTT_SERVER:?unset} --timesync ${CBUS_TIMESYNC:-300}"

# Simple arguments
if [ "${MQTT_PORT}" == "null" ]; then
    MQTT_PORT=""
else
   CMQTTD_ARGS="${CMQTTD_ARGS} --broker-port ${MQTT_PORT}"
fi

if [ "${TCP_OR_SERIAL}" == "Use a serial connection to CBUS" ]; then
    echo "Using serial PCI at ${CBUS_CONNECTION}"
    CMQTTD_ARGS="${CMQTTD_ARGS} --serial ${CBUS_CONNECTION}"
else
    echo "Using TCP CNI at ${CBUS_CONNECTION}"
    CMQTTD_ARGS="${CMQTTD_ARGS} --tcp ${CBUS_CONNECTION}"
fi

if [ "${CBUS_CLOCK}" != "true" ]; then
    echo "Not responding to clock requests."
    CMQTTD_ARGS="${CMQTTD_ARGS} --no-clock"
fi

if [ "${MQTT_USE_TLS}" == "true" ]; then
    echo "Using TLS to connect to MQTT broker."

    # Using TLS, check for certificates directory
    if [ "${CMQTTD_CA_CERT_PATH}" != "null" ]; then
          if [ -d "${CMQTTD_CA_CERT_PATH}" ]; then
              echo "Using custom certificates in ${CMQTTD_CA_CERT_PATH}"
              CMQTTD_ARGS="${CMQTTD_ARGS} --broker-ca ${CMQTTD_CA_CERT_PATH}"
          else
              echo "${CMQTTD_CA_CERT_PATH} not found, using Python CA store."
          fi
     else
          echo "Certificates Directory was not provided, using Python CA store."
     fi

    # Client certificates
    if [ "${CMQTTD_CLIENT_CERT_PATH}" == "null" ]; then
        echo  "No value was provided for CMQTTD_CLIENT_CERT_PATH, not using "
        echo "client certificates for authentication."
    elif [ "${CMQTTD_CLIENT_KEY_PATH}" == "null" ]; then
        echo  "No value was provided for CMQTTD_CLIENT_KEY_PATH, not using "
        echo "client certificates for authentication."
    elif [ -e "${CMQTTD_CLIENT_CERT_PATH}" ] && [ -e "${CMQTTD_CLIENT_KEY_PATH}" ]; then
        echo "Using client cert: ${CMQTTD_CLIENT_CERT_PATH}"
        echo "Using client key: ${CMQTTD_CLIENT_KEY_PATH}"
        CMQTTD_ARGS="${CMQTTD_ARGS} --broker-client-cert ${CMQTTD_CLIENT_CERT_PATH} --broker-client-key ${CMQTTD_CLIENT_KEY_PATH}"
    else
        echo "${CMQTTD_CLIENT_CERT_PATH} and/or ${CMQTTD_CLIENT_KEY_PATH} not found, not using "
        echo "client certificates for authentication."
    fi
else
    echo "Disabling TLS support."
    CMQTTD_ARGS="${CMQTTD_ARGS} --broker-disable-tls"
fi

if [ -e "${CMQTTD_AUTH_FILE}" ]; then
    echo "Using MQTT login details in ${CMQTTD_AUTH_FILE}"
    CMQTTD_ARGS="${CMQTTD_ARGS} --broker-auth ${CMQTTD_AUTH_FILE}"
else
    echo "${CMQTTD_AUTH_FILE} not found; skipping MQTT authentication."
fi

if [ "${CMQTTD_PROJECT_FILE}" == "null" ]; then
    echo "No value was provided for CMQTTD_PROJECT_FILE; using generated labels."
elif [ -e "${CMQTTD_PROJECT_FILE}" ]; then
    echo "Using C-Bus Toolkit project backup file ${CMQTTD_PROJECT_FILE}"
    CMQTTD_ARGS="${CMQTTD_ARGS} --project-file ${CMQTTD_PROJECT_FILE}"
else
    echo "${CMQTTD_PROJECT_FILE} not found; using generated labels."
fi

if [ "${CBUS_NETWORK_NUMBER}" == "null" ]; then
  echo "No cbus network number was supplied."
else
  echo "Naming this network ${CBUS_NETWORK_NUMBER}"
  CMQTTD_ARGS="${CMQTTD_ARGS} --name ${CBUS_NETWORK_NUMBER}"
fi

echo " "

if [ "${CMQTTD_LOG_LEVEL}" != "null" ]; then
      CMQTTD_ARGS="$CMQTTD_ARGS --verbosity $CMQTTD_LOG_LEVEL"
fi


# Announce what we think local time is on start-up. This will be sent to the C-Bus network.
echo "Local time zone: ${TZ:-UTC}"
echo -n "Current time: "
date -R

echo "Running cmqttd with flags: ${CMQTTD_ARGS}"
cmqttd $CMQTTD_ARGS

exit
