FROM alpine:3.18.3

# Set WeeWX version to install 
# http://weewx.com/downloads/ or https://github.com/weewx/weewx/releases
ARG WEEWX=4.10.2

# Comma-separated list of plugins (URLs) to install
ARG INSTALL_PLUGINS="\
https://github.com/matthewwall/weewx-mqtt/archive/master.zip,\
https://github.com/matthewwall/weewx-interceptor/archive/master.zip"

ENTRYPOINT ["/home/weewx/bin/weewxd"]
WORKDIR /home/weewx

# Install WeeWX dependencies
# ephem requires gcc so we use a virtual apk environment for that
RUN apk add --no-cache \
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
    pip3 install ephem &&\
    apk del .build-deps

# Install WeeWX
ADD http://weewx.com/downloads/released_versions/weewx-$WEEWX.tar.gz .
RUN tar xvzf weewx-$WEEWX.tar.gz && \
    cd weewx-$WEEWX && \
    python3 ./setup.py build &&\
    python3 ./setup.py install --no-prompt &&\
    cd .. &&\
    rm -rf weewx-$WEEWX weewx-$WEEWX.tar.gz

# Patch WeeWX logger to output to stdout and make sure non-root has
# access the default outputs
RUN sed -i 's/handlers = syslog/handlers = console/g' /home/weewx/bin/weeutil/logger.py &&\
    mkdir /home/weewx/archive /home/weewx/public_html &&\
    chmod 777 /home/weewx/archive /home/weewx/public_html &&\
    touch /home/weewx/weewx.conf &&\
    chmod 666 /home/weewx/weewx.conf

# Install alarm/lowBattery scripts
# Will require configuration in order to run; this only makes them available
RUN cp examples/alarm.py examples/lowBattery.py bin/user/

# Install plugins
RUN if [ ! -z "${INSTALL_PLUGINS}" ]; then \
      OLDIFS=$IFS; \
      IFS=','; \
      for PLUGIN in ${INSTALL_PLUGINS}; do \
        IFS=$OLDIFS; \
	wget $PLUGIN &&\
	bin/wee_extension --install `basename $PLUGIN` ; \
	rm -f `basename $PLUGIN`; \
      done; \
    fi; \
    rm -f /home/weewx/weewx.conf.*

# Overwrite the interceptor to include the time override hack
COPY src/interceptor.py /home/weewx/bin/user

VOLUME ["/data"]
CMD ["/data/weewx.conf", "-x"]
