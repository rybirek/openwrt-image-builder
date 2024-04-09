FROM debian:stable-slim AS build-stage
ARG DEVICE=ea8300
ARG OPENWRT_VERSION=v22.03.2
ARG SHOULD_ADD_HAASMESH=0
ARG CPUS

## Install dependencies
RUN apt-get update
RUN apt-get install -y sudo build-essential clang flex g++ gawk gettext \
      git libncurses5-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
      file wget
RUN apt-get clean

# Add openwrt user
RUN useradd -m openwrt && \
    echo 'openwrt ALL=NOPASSWD: ALL' > /etc/sudoers.d/openwrt

## Clone and prepare OpenWRT
USER openwrt
WORKDIR /home/openwrt

RUN git clone -b $OPENWRT_VERSION git://git.openwrt.org/openwrt/openwrt.git
RUN openwrt/scripts/feeds update -a
RUN openwrt/scripts/feeds install -a

WORKDIR /home/openwrt/openwrt
COPY devices/$DEVICE.config /home/openwrt/openwrt/.config
USER root
RUN chmod 777 /home/openwrt/openwrt/.config
USER openwrt
RUN export TERM=xterm

#ADD ./toolchain-aarch64_cortex-a72_gcc-12.3.0_musl /home/openwrt/

RUN git config --global user.email "ireneusz.rybicki@outlook.com"
RUN git config --global user.name "Ireneusz Rybicki"
WORKDIR /home/openwrt/patchs
COPY  patchs/$DEVICE.patch /home/openwrt/patchs
WORKDIR /home/openwrt/openwrt
RUN git am --whitespace=fix /home/openwrt/patchs/$DEVICE.patch

## Clone and prepare HaasMesh
RUN if [ $SHOULD_ADD_HAASMESH -eq 1 ]; then \
    git clone https://github.com/drandyhaas/haasmesh.git && \
    haasmesh/script/setupnodebuild.sh $DEVICE && \
    date > files/etc/config/sysupgrade.version.txt \
    ; fi

# Apply config changes
RUN make defconfig
# Build OpenWRT
RUN if [ -z $CPUS ]; then \
    make -j $(($(nproc)+1)) V=sc download world \
    ; else \
    make -j$CPUS V=sc download world \
    ; fi

FROM scratch AS export-stage
COPY --from=build-stage /home/openwrt/openwrt/bin/ /
