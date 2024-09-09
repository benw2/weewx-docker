FROM alpine:3.20.3

# Set WeeWX version to install 
# http://weewx.com/downloads/ or https://github.com/weewx/weewx/releases
ARG WEEWX_VERSION=5.0.2

# Comma-separated list of plugins (URLs) to install
ARG INSTALL_PLUGINS="\
  https://github.com/matthewwall/weewx-mqtt/archive/master.zip,\
  https://github.com/matthewwall/weewx-interceptor/archive/master.zip,\
  https://github.com/gjr80/weewx-gw1000/releases/latest/download/gw1000.zip"

ENTRYPOINT ["/usr/bin/weewxd"]
WORKDIR /home/weewx

# Install WeeWX dependencies
# ephem requires gcc so we use a virtual apk environment for that
RUN apk add --no-cache --virtual \
  mysql-client \
  openssh-client \
  rsync \
  tzdata \
  ca-certificates \
  python3 \
  py3-configobj \
  py3-cheetah \
  py3-pip \
  py3-wheel \
  py3-mysqlclient \
  py3-pillow \
  py3-paho-mqtt &&\
  apk add --no-cache --virtual .build-deps build-base python3-dev &&\
  pip3 install --break-system-packages ephem &&\
  pip3 install --break-system-packages --no-cache-dir weewx==${WEEWX_VERSION} &&\
  apk del .build-deps

# Patch WeeWX logger to output to stdout and make sure non-root has
# access the default outputs
RUN SP=$(/usr/bin/find /usr/lib -name site-packages) &&\
  echo "Using python site-packages path: $SP" &&\
  sed -i 's/handlers = syslog/handlers = console/g' $SP/weeutil/logger.py &&\
  mkdir /home/weewx/archive /home/weewx/public_html &&\
  chmod 777 /home/weewx/archive /home/weewx/public_html &&\
  cp $SP/weewx_data/weewx.conf /home/weewx/weewx.conf &&\
  chmod 666 /home/weewx/weewx.conf

# Install plugins
RUN if [ ! -z "${INSTALL_PLUGINS}" ]; then \
  OLDIFS=$IFS; \
  IFS=','; \
  for PLUGIN in ${INSTALL_PLUGINS}; do \
  IFS=$OLDIFS; \
  weectl extension install --yes $PLUGIN ; \
  done; \
  fi; \
  rm -f /home/weewx/weewx.conf.*

# Overwrite the interceptor to include the time override hack
COPY src/interceptor.py /home/weewx/bin/user

VOLUME ["/data"]
CMD ["--config", "/data/weewx.conf"]
