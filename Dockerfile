# This Dockerfile sets up cmqttd, which bridges a C-Bus PCI to a MQTT server.
#
# This requires about 120 MiB of dependencies, and the
# The final image size is about 100 MiB.
#
# Example use:
#
# $ docker build -t cmqttd .
# $ docker run --device /dev/ttyUSB0 -e "SERIAL_PORT=/dev/ttyUSB0" \
#     -e "MQTT_SERVER=192.2.0.1" -e "TZ=Australia/Adelaide" -it cmqttd

# use home assistant builder to build this add-on
# e.g.:
# function builder() {
#   docker run \
#     --rm \
#     -it \
#     --privileged \
#     -v ${PWD}:/data \
#     -v /var/run/docker.sock:/var/run/docker.sock:ro \
#     ghcr.io/home-assistant/amd64-builder:latest --target /data $@
# }
# builder --aarch64 --amd64

# NOTE: we need a specific python version, and this one works.
# doesn't look like pyserial supports anything above 3.8 explicitly? 3.7.17 seems to work fine.
# this is why we use a homeassistant base image with an old version of alpine linux, which uses an old version of python.
ARG BUILD_FROM=homeassistant/amd64-base:3.11
FROM $BUILD_FROM AS base

# FROM homeassistant/amd64-base:3.11 AS base

# Install most Python deps here, because that way we don't need to include build tools in the
# final image.
RUN apk add --no-cache python3 py3-cffi py3-paho-mqtt py3-six tzdata
RUN pip3 install 'pyserial==3.4' 'pyserial_asyncio==0.4'

# Runs tests and builds a distribution tarball
FROM base AS builder
# See also .dockerignore
ADD . /cbus
WORKDIR /cbus
RUN pip3 install 'parameterized' && \
    python3 -m unittest && \
    python3 setup.py bdist -p generic --format=gztar

# cmqttd runner image
FROM base AS cmqttd
COPY COPYING COPYING.LESSER Dockerfile README.md entrypoint-cmqttd.sh /
COPY --from=builder /cbus/dist/cbus-0.2.generic.tar.gz /
RUN tar zxf /cbus-0.2.generic.tar.gz && rm /cbus-0.2.generic.tar.gz

# Runs cmqttd itself
CMD /entrypoint-cmqttd.sh
