FROM tomcat:9-jdk11

ENV DEBIAN_FRONTEND=noninteractive \
    GUAC_VERSION=1.6.0 \
    MYSQL_CONNECTOR_VERSION=9.1.0 \
    GUAC_DB_NAME=guacadb \
    GUAC_DB_USER=guaca_nachos \
    GUAC_DB_PASSWORD=P@ssword!

# Paquets nécessaires : Guacamole Server + MariaDB + outils
RUN apt-get update && apt-get install -y \
    build-essential \
    libcairo2-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libtool-bin \
    uuid-dev \
    libossp-uuid-dev \
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

# Dossiers Guacamole
RUN mkdir -p /etc/guacamole/extensions \
    /etc/guacamole/lib \
    /var/lib/guacamole/recordings \
    /opt/guacamole/schema

WORKDIR /tmp

# 1) Guacamole Server (guacd)
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/source/guacamole-server-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-server-${GUAC_VERSION}.tar.gz \
    && cd guacamole-server-${GUAC_VERSION} \
    && ./configure \
    && make \
    && make install \
    && ldconfig \
    && cd /tmp \
    && rm -rf guacamole-server-${GUAC_VERSION}*

# 2) WebApp Guacamole (guacamole.war)
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war \
    && mv guacamole-${GUAC_VERSION}.war /usr/local/tomcat/webapps/guacamole.war

# 3) Extension JDBC MySQL + scripts SQL
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz \
    && mv guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && cp guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema/*.sql /opt/guacamole/schema/ \
    && rm -rf guacamole-auth-jdbc-${GUAC_VERSION}*

# 4) MySQL Connector/J
RUN wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz \
    && tar -xzf mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz \
    && cp mysql-connector-j-${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar /etc/guacamole/lib/ \
    && rm -rf mysql-connector-j-${MYSQL_CONNECTOR_VERSION}*

# 5) Extension TOTP
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-totp-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-auth-totp-${GUAC_VERSION}.tar.gz \
    && mv guacamole-auth-totp-${GUAC_VERSION}/guacamole-auth-totp-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && rm -rf guacamole-auth-totp-${GUAC_VERSION}*

# 6) Extension enregistrement vidéo (history-recording-storage)
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz \
    && mv guacamole-history-recording-storage-${GUAC_VERSION}/guacamole-history-recording-storage-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && rm -rf guacamole-history-recording-storage-${GUAC_VERSION}*

# 7) Fichier guacamole.properties (DB + TOTP + recordings)
RUN bash -c 'cat >/etc/guacamole/guacamole.properties <<EOF
# ============================
# Base MariaDB
# ============================
mysql-hostname: 127.0.0.1
mysql-port: 3306
mysql-database: ${GUAC_DB_NAME}
mysql-username: ${GUAC_DB_USER}
mysql-password: ${GUAC_DB_PASSWORD}

# ============================
# TOTP (MFA)
# ============================
totp-issuer: Guacamole Lab
totp-digits: 6
totp-period: 30
totp-mode: sha1

# ============================
# Enregistrements vidéo
# ============================
recording-search-path: /var/lib/guacamole/recordings
EOF'

# 8) guacd.conf (optionnel, valeurs par défaut)
RUN bash -c 'cat >/etc/guacamole/guacd.conf <<EOF
[server]
bind_host = 0.0.0.0
bind_port = 4822
EOF'

# Script d'entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV GUACAMOLE_HOME=/etc/guacamole

EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
