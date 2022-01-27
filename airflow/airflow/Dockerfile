FROM apache/airflow:2.2.3

#
#	prepare Python with pip
#
COPY requirements.txt .
RUN pip install -r requirements.txt

#
#	install OpenJDK from adoptopenjdk
#
USER root
RUN  apt-get update \
    &&  apt-get install -y --no-install-recommends wget software-properties-common \
    &&  mkdir -p /usr/share/man/man1/ \
    &&  wget -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public -O /tmp/jfrog.key \  
    &&  apt-key add /tmp/jfrog.key \
    &&  add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/ \
    &&  apt-get update \
    &&  apt-get install -y adoptopenjdk-8-hotspot \
    &&  rm /tmp/jfrog.key

#
#	install Apache Hop
#
ENV DEPLOYMENT_PATH=/opt/hop

# 	prepare user + group
RUN addgroup apache \
    && adduser --disabled-password --shell /bin/bash --gecos "" --home ${DEPLOYMENT_PATH} hop \
    && usermod -a -G apache hop\
    && usermod -a -G apache airflow\
    && chown hop:apache ${DEPLOYMENT_PATH} 

COPY --chown=hop:apache ./resources/hop/ /opt/hop

RUN chmod -R 775 ${DEPLOYMENT_PATH}/config \
    && mkdir ${DEPLOYMENT_PATH}/audit \
    && chown hop:apache ${DEPLOYMENT_PATH}/audit \
    && chmod -R 775 ${DEPLOYMENT_PATH}/audit



