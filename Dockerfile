FROM debian:buster-slim

# define list
ARG xash_url=https://github.com/troll338cz/xash3d-tyabus
ARG amxmodx_url=https://www.amxmodx.org/amxxdrop/1.8/amxmodx-1.8.3-dev-git5201-base-linux.tar.gz
ARG metamod_url=https://github.com/tyabus/metamod-p
ARG hlsdk_url=https://github.com/sultim-t/hlsdk-xash3d
ARG server_path=/opt/xashds
ARG gamedir=valve
ARG apt_temp_pkgs='gcc-multilib g++-multilib cmake build-essential git ca-certificates curl'
ARG cmake_arch_flags='-DCMAKE_C_FLAGS="-m32" -DCMAKE_CXX_FLAGS="-m32" -DCMAKE_EXE_LINKER_FLAGS="-m32"'

# Set the locale (fix the locale warnings)
RUN apt-get update && apt-get install -y --no-install-recommends locales \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8
ENV LC_ALL en_US.UTF-8

# add 32 bit architecture
RUN dpkg --add-architecture i386

# install required packages
RUN apt-get -y update && apt-get install -y --no-install-recommends \
    $apt_temp_pkgs \
    libstdc++6:i386

# Temporary directory for building
WORKDIR /tmp

# XASH3D
RUN git clone $xash_url xash3d \
    && mkdir -p /tmp/xash3d/build

RUN cd /tmp/xash3d/build \
    && cmake $cmake_arch_flags \
    -DXASH_DEDICATED=1 .. \
    && make -j2

# METAMOD BUILD
RUN git clone $metamod_url metamod \
    && mkdir -p /tmp/metamod/build \
    && cd /tmp/metamod/build \
    && cmake $cmake_arch_flags .. && make -j2

# HLSDK BUILD
RUN cd /tmp && git clone $hlsdk_url hlsdk-xash3d \
    && mkdir -p hlsdk-xash3d/build && cd hlsdk-xash3d/build \
    && git reset --hard db4cd7846de57007b9ccdecd9e3905acf5c1f3d9 \
    && cmake $cmake_arch_flags .. \
    && make -j2

# Server
RUN mkdir -p $server_path

WORKDIR $server_path

RUN find /tmp/xash3d/build \
    -type f \
    \( -name '*.so' -o -name "xash3d" \) \
    -exec cp '{}' $server_path \;

COPY ./games/$gamedir.tar.gz $server_path/

RUN tar -xvzf $gamedir.tar.gz \
    && rm $gamedir.tar.gz

# METAMOD
RUN mkdir -p $server_path/$gamedir/addons/metamod/dlls

RUN find /tmp/metamod \
    -type f \
    -name '*metamod*.so' \
    -exec cp '{}' $server_path/$gamedir/addons/metamod/dlls/metamod.so \;

# HLSDK

RUN mkdir -p $server_path/$gamedir/dlls

RUN find /tmp/hlsdk-xash3d \
    -type f \
    -name '*hl*.so' \
    -exec cp '{}' $server_path/$gamedir/dlls \;

# configs
COPY ./conf/$gamedir/* $server_path/$gamedir/
COPY ./conf/metamod/plugins.ini $server_path/$gamedir/addons/metamod/plugins.ini

# clean temporary files and apt cache
RUN rm -rf /tmp/* \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["./xash3d", "-game $gamedir"]

CMD ["+map crossfire"]
