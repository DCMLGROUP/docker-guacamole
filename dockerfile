FROM tomcat:9-jdk11

# ======================================
# VARIABLES GLOBALES PARAMÉTRABLES
# ======================================
ENV DEBIAN_FRONTEND=noninteractive \
    # Versions
    GUAC_VERSION=1.5.5 \
    MYSQL_CONNECTOR_VERSION=9.1.0 \
    # DB interne
    GUAC_DB_NAME=guacadb \
    GUAC_DB_USER=guacamole_user \
    GUAC_DB_PASSWORD=ChangeMe123 \
    # OpenID Connect
    EXTENSION_PRIORITY="openid" \
    OPENID_AUTHORIZATION_ENDPOINT="https://auth.dcmlgroup.fr/realms/lab-dcmlgroup/protocol/openid-connect/auth" \
    OPENID_JWKS_ENDPOINT="https://auth.dcmlgroup.fr/realms/lab-dcmlgroup/protocol/openid-connect/certs" \
    OPENID_TOKEN_ENDPOINT="https://auth.dcmlgroup.fr/realms/lab-dcmlgroup/protocol/openid-connect/token" \
    OPENID_LOGOUT_ENDPOINT="https://auth.dcmlgroup.fr/realms/lab-dcmlgroup/protocol/openid-connect/logout" \
    OPENID_ISSUER="https://auth.techpremium.eu/realms/Cabinet-AC" \
    OPENID_CLIENT_ID="guacamole" \
    OPENID_CLIENT_SECRET="HZFxp3zRhjRp5AdRajDFNoQYatuCEqrS" \
    OPENID_REDIRECT_URI="https://guacamole.stack.davidteixeira.fr." \
    OPENID_SCOPE="openid email profile" \
    OPENID_USERNAME_CLAIM="preferred_username" \
    OPENID_GROUPS_CLAIM="groups" \
    OPENID_ALLOW_UNVERIFIED_USERS="true" \
    OPENID_ALLOWED_GROUPS="technique users" \
    # Features
    CLIPBOARD_ENABLED="true" \
    DOCUMENT_PRINTING_ENABLED="true" \
    LOCAL_STORAGE_ENABLED="true" \
    LOCAL_STORAGE_DIR="/var/lib/guacamole"

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
# COMPILATION GUACAMOLE SERVER (guacd)
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
# GUACAMOLE WEBAPP (ROOT.war)
# ======================================
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war \
    && mv guacamole-${GUAC_VERSION}.war /usr/local/tomcat/webapps/ROOT.war

# ======================================
# JDBC + SCHEMAS SQL
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
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-openid-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-auth-openid-${GUAC_VERSION}.tar.gz \
    && mv guacamole-auth-openid-${GUAC_VERSION}/guacamole-auth-openid-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && rm -rf guacamole-auth-openid-${GUAC_VERSION}*

# ======================================
# ENREGISTREMENT DES SESSIONS
# ======================================
RUN wget https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz \
    && tar -xzf guacamole-history-recording-storage-${GUAC_VERSION}.tar.gz \
    && mv guacamole-history-recording-storage-${GUAC_VERSION}/guacamole-history-recording-storage-${GUAC_VERSION}.jar /etc/guacamole/extensions/ \
    && rm -rf guacamole-history-recording-storage-${GUAC_VERSION}*

# ======================================
# GUACAMOLE.PROPERTIES
# ======================================
RUN cat << EOF > /etc/guacamole/guacamole.properties

# =====================================
# BASE DE DONNÉES MARIADB
# =====================================
mysql-hostname: 127.0.0.1
mysql-port: 3306
mysql-database: ${GUAC_DB_NAME}
mysql-username: ${GUAC_DB_USER}
mysql-password: ${GUAC_DB_PASSWORD}

# =====================================
# OPENID CONNECT
# =====================================
extension-priority: ${EXTENSION_PRIORITY}

openid-authorization-endpoint: ${OPENID_AUTHORIZATION_ENDPOINT}
openid-jwks-endpoint: ${OPENID_JWKS_ENDPOINT}
openid-token-endpoint: ${OPENID_TOKEN_ENDPOINT}
openid-logout-endpoint: ${OPENID_LOGOUT_ENDPOINT}
openid-issuer: ${OPENID_ISSUER}

openid-client-id: ${OPENID_CLIENT_ID}
openid-client-secret: ${OPENID_CLIENT_SECRET}
openid-redirect-uri: ${OPENID_REDIRECT_URI}

openid-scope: ${OPENID_SCOPE}
openid-username-claim-type: ${OPENID_USERNAME_CLAIM}
openid-groups-claim-type: ${OPENID_GROUPS_CLAIM}

openid-allow-unverified-users: ${OPENID_ALLOW_UNVERIFIED_USERS}
openid-allowed-groups: ${OPENID_ALLOWED_GROUPS}

# =====================================
# OPTIONS
# =====================================
enable-clipboard-integration: ${CLIPBOARD_ENABLED}
document-printing-enabled: ${DOCUMENT_PRINTING_ENABLED}

local-storage-enabled: ${LOCAL_STORAGE_ENABLED}
local-storage-directory: ${LOCAL_STORAGE_DIR}

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
