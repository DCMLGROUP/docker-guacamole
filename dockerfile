FROM tomcat:9-jdk11

# ======================================
# VARIABLES GLOBALENT PARAMÉTRABLES
# ======================================
ENV DEBIAN_FRONTEND=noninteractive \
    # Versions
    GUAC_VERSION=1.5.5 \
    MYSQL_CONNECTOR_VERSION=9.1.0 \
    # Base de données interne MariaDB
    GUAC_DB_NAME=guacadb \
    GUAC_DB_USER=guacamole_user \
    GUAC_DB_PASSWORD=ChangeMe123 \
    # OpenID Connect
    OPENID_AUTHORIZATION_ENDPOINT="" \
    OPENID_TOKEN_ENDPOINT="" \
    OPENID_JWKS_ENDPOINT="" \
    OPENID_ISSUER="" \
    OPENID_CLIENT_ID="guacamole" \
    OPENID_CLIENT_SECRET="" \
    OPENID_REDIRECT_URI="" \
    OPENID_SCOPE="openid email profile" \
    OPENID_USERNAME_CLAIM_TYPE="preferred_username"


# ======================================
# INSTALLATION DES DÉPENDANCES
# ======================================
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


# ======================================
# CRÉATION DES RÉPERTOIRES
# ======================================
RUN mkdir -p /etc/guacamole/extensions \
    /etc/guacamole/lib \
    /var/lib/guacamole/recordings \
    /opt/guacamole/schema

WORKDIR /tmp


# ======================================
# GUACAMOLE SERVER (guacd)
# ======================================
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/source/guacamole-server-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-server-${GUAC_VERSION}.tar.gz \
    && cd guacamole-server-${GUAC_VERSION} \
    && ./configure \
    && make \
    && make install \
    && ldconfig \
    && cd /tmp \
    && rm -rf guacamole-server-${GUAC_VERSION}*


# ======================================
# GUACAMOLE CLIENT (WebApp → ROOT.war)
# ======================================
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war \
    && mv guacamole-${GUAC_VERSION}.war /usr/local/tomcat/webapps/ROOT.war


# ======================================
# EXTENSION JDBC + SCHÉMAS SQL
# ======================================
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz \
    && mv guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && cp guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema/*.sql /opt/guacamole/schema/ \
    && rm -rf guacamole-auth-jdbc-${GUAC_VERSION}*


# ======================================
# MYSQL CONNECTOR (DRIVER)
# ======================================
RUN wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz \
    && tar -xzf mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz \
    && cp mysql-connector-j-${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar /etc/guacamole/lib/ \
    && rm -rf mysql-connector-j-${MYSQL_CONNECTOR_VERSION}*


# ======================================
# EXTENSION OPENID CONNECT
# ======================================
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-sso-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-auth-sso-${GUAC_VERSION}.tar.gz \
    && mv guacamole-auth-sso-${GUAC_VERSION}/openid/guacamole-auth-sso-openid-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && rm -rf guacamole-auth-sso-${GUAC_VERSION}*


# ======================================
# EXTENSION : ENREGISTREMENT DES SESSIONS
# ======================================
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz \
    && mv guacamole-history-recording-storage-${GUAC_VERSION}/guacamole-history-recording-storage-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && rm -rf guacamole-history-recording-storage-${GUAC_VERSION}*


# ======================================
# FICHIER DE CONFIG PRINCIPAL
# ======================================
RUN cat << EOF > /etc/guacamole/guacamole.properties
# ============================
# BASE MARIADB
# ============================
mysql-hostname: 127.0.0.1
mysql-port: 3306
mysql-database: ${GUAC_DB_NAME}
mysql-username: ${GUAC_DB_USER}
mysql-password: ${GUAC_DB_PASSWORD}

# ============================
# OPENID CONNECT
# ============================
openid-authorization-endpoint: ${OPENID_AUTHORIZATION_ENDPOINT}
openid-token-endpoint: ${OPENID_TOKEN_ENDPOINT}
openid-jwks-endpoint: ${OPENID_JWKS_ENDPOINT}
openid-issuer: ${OPENID_ISSUER}
openid-client-id: ${OPENID_CLIENT_ID}
openid-client-secret: ${OPENID_CLIENT_SECRET}
openid-redirect-uri: ${OPENID_REDIRECT_URI}
openid-scope: ${OPENID_SCOPE}
openid-username-claim-type: ${OPENID_USERNAME_CLAIM_TYPE}

# ============================
# ENREGISTREMENTS VIDÉO
# ============================
recording-search-path: /var/lib/guacamole/recordings
EOF


# ======================================
# CONFIG GUACD
# ======================================
RUN cat << EOF > /etc/guacamole/guacd.conf
[server]
bind_host = 0.0.0.0
bind_port = 4822
EOF


# ======================================
# ENTRYPOINT
# ======================================
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV GUACAMOLE_HOME=/etc/guacamole

EXPOSE 8080
ENTRYPOINT ["/entrypoint.sh"]
