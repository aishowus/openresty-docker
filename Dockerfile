FROM openresty/openresty:bookworm-fat AS builder

USER root

ARG OPENRESTY_VERSION="1.27.1.2"
ARG NGINX_VERSION="1.27.1"
ARG IN_GFW=""

#ENV DEBIAN_FRONTEND=noninteractive

COPY misc/gfw.sh /root/docker-gfw.sh

RUN ( if [ -n "${IN_GFW}" ]; then /bin/bash /root/docker-gfw.sh bookworm; fi ) && \
  apt-get update -y && apt-get install -y gcc make git libpcre3-dev zlib1g-dev libssl-dev libxml2-dev libxslt-dev libedit-dev && \
  mkdir -p /data/soft/openresty && cd /data/soft && \
  curl -Lo /data/soft/openresty-${OPENRESTY_VERSION}.tar.gz https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz && \
  tar --strip-component=1 -C /data/soft/openresty -zxf /data/soft/openresty-${OPENRESTY_VERSION}.tar.gz && \
  ( if [ -n "${IN_GFW}" ]; then /bin/bash /root/docker-gfw.sh git; fi ) && \
  git clone --depth=1 https://github.com/bellard/quickjs /data/soft/quickjs && \
  cd /data/soft/quickjs && CFLAGS='-fPIC' make libquickjs.a && \
  git clone --depth=1 https://github.com/nginx/njs.git /data/soft/njs && \
  cd /data/soft/njs && \
  ./configure \
    --cc-opt="-O -I/data/soft/quickjs" \
    --ld-opt="-O -L/data/soft/quickjs" && \
  make -j`nproc` && \
  cp /data/soft/njs/build/njs /usr/bin/njs && \
  cd /data/soft/openresty && \
  ./configure --add-dynamic-module="/data/soft/njs/nginx" \
    --with-cc-opt="-I/data/soft/quickjs" \
    --with-ld-opt="-L/data/soft/quickjs" && \
  make -j`nproc` && \
  mkdir -p /usr/local/openresty/nginx/modules && \
  find /data/soft/openresty/build -type f -name "ngx_*_js_module.so" \
    -exec cp "{}" /usr/local/openresty/nginx/modules/ \;

FROM openresty/openresty:bookworm-fat AS prod

COPY --from=builder /usr/bin/njs /usr/bin/njs
COPY --from=builder /usr/local/openresty/nginx/modules \
  /usr/local/openresty/nginx/modules

COPY misc/gfw.sh /root/docker-gfw.sh

RUN cp /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.bak && \
  (if [ -n "${IN_GFW}" ]; then /bin/bash /root/docker-gfw.sh bookworm; fi ) && \
  apt-get update -y && apt-get install -y libpcre3-dev zlib1g-dev libssl-dev libxml2-dev libxslt-dev libedit-dev && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /root/docker-gfw.sh && \
  mv /etc/apt/sources.list.d/debian.sources.bak /etc/apt/sources.list.d/debian.sources

