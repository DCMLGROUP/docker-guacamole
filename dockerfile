FROM tomcat:9-jdk11

ARG GUAC_VERSION=1.6.0
ARG MYSQL_CONNECTOR_VERSION=9.1.0

ENV DEBIAN_FRONTEND=noninteractive \
    GUAC_VERSION=${GUAC_VERSION} \
    MYSQL_CONNECTOR_VERSION=${MYSQL_CONNECTOR_VERSION} \
    CLIPBOARD_ENABLED="true" \
    DOCUMENT_PRINTING_ENABLED="true" \
    LOCAL_STORAGE_ENABLED="true" \
    LOCAL_STORAGE_DIR="/var/lib/guacamole" \
    GUACAMOLE_HOME=/etc/guacamole

RUN apt-get update && apt-get install -y \
    build-essential \
    libcairo2-dev \
    libjpeg-turbo8-dev \
    libpng-dev \
    libtool-bin \
    uuid-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    freerdp2-dev \
    libpango1.0-dev \
    libssh2-1-dev \
    libtelnet-dev \
    libvncserver-dev \
    libwebsockets-dev \
    libpulse-dev \
    libssl-dev \
    libvorbis-dev \
    libwebp-dev \
    mariadb-server \
    mariadb-client \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/guacamole/extensions \
    /etc/guacamole/lib \
    /var/lib/guacamole/recordings \
    /opt/guacamole/schema

WORKDIR /tmp

RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/source/guacamole-server-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-server-${GUAC_VERSION}.tar.gz \
    && cd guacamole-server-${GUAC_VERSION} \
    && ./configure \
    && make \
    && make install \
    && ldconfig \
    && cd /tmp \
    && rm -rf guacamole-server-${GUAC_VERSION}*

RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war \
    && mv guacamole-${GUAC_VERSION}.war /usr/local/tomcat/webapps/ROOT.war

RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz \
    && mv guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && cp guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema/*.sql /opt/guacamole/schema/ \
    && rm -rf guacamole-auth-jdbc-${GUAC_VERSION}*

RUN wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz \
    && tar -xzf mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz \
    && cp mysql-connector-j-${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar /etc/guacamole/lib/ \
    && rm -rf mysql-connector-j-${MYSQL_CONNECTOR_VERSION}*

RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-sso-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-auth-sso-${GUAC_VERSION}.tar.gz \
    && mv guacamole-auth-sso-${GUAC_VERSION}/openid/guacamole-auth-sso-openid-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && rm -rf guacamole-auth-sso-${GUAC_VERSION}*

RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz \
    && mv guacamole-history-recording-storage-${GUAC_VERSION}/guacamole-history-recording-storage-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && rm -rf guacamole-history-recording-storage-${GUAC_VERSION}*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
