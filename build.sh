#!/bin/bash

OPENRESTY_VERSION=1.27.1.2

PWD=$(cd $(dirname "$0"); pwd) 

docker build -f ${PWD}/Dockerfile -t simonkuang/openresty:bookworm-fat --build-arg OPENRESTY_VERSION=${OPENRESTY_VERSION} --build-arg IN_GFW=1 .

