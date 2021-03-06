FROM ubuntu:trusty

MAINTAINER Adolfo Builes <builes.adolfo@gmail.com>
# Based on Dockerfile https://github.com/bbcrd/audiowaveform

ENV GMOCK_VERSION 1.7.0
ENV BUILD_TYPE Release

RUN apt-get update \
  && apt-get install -y cmake \
			make \
			g++ \
			gcc \
			libmad0-dev \
			libsndfile1-dev \
			libgd2-xpm-dev \
			libboost-filesystem-dev \
			libboost-program-options-dev \
			libboost-regex-dev \
			git-core

RUN apt-get install -y python-pip
RUN pip install awscli

RUN apt-get install curl
RUN curl -sL https://deb.nodesource.com/setup_6.x | bash
RUN apt-get install rlwrap nodejs

RUN apt-get install -y wget


RUN wget https://github.com/bbcrd/audiowaveform/archive/1.0.11.tar.gz -O audiowaveform.tar.gz

RUN tar xf audiowaveform.tar.gz

RUN ls

WORKDIR /audiowaveform-1.0.11

RUN ls

WORKDIR build

RUN cmake -D CMAKE_BUILD_TYPE=${BUILD_TYPE} -D ENABLE_TESTS=0 .. \
   && make \
   && make install

RUN wget https://raw.githubusercontent.com/abuiles/lc-ecs-worker/master/lc-ecs-worker.sh
RUN wget https://raw.githubusercontent.com/abuiles/lc-ecs-worker/master/clean.js

RUN chmod +x clean.js
RUN chmod +x lc-ecs-worker.sh

ENTRYPOINT ["./lc-ecs-worker.sh"]
