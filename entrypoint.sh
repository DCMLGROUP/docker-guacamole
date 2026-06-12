#!/bin/bash
set -e

echo "==> Démarrage MariaDB..."
mysqld_safe --bind-address=127.0.0.1 &

echo "==> Attente de MariaDB..."
for i in {1..30}; do
  if mysqladmin ping -uroot --silent; then
    echo "MariaDB est prêt."
    break
  fi
  echo "En attente de MariaDB..."
  sleep 1
done

echo "==> Initialisation base Guacamole (si nécessaire)..."
if ! mysql -uroot -e "USE ${GUAC_DB_NAME};" >/dev/null 2>&1; then
  echo "Base ${GUAC_DB_NAME} absente, création..."
  mysql -uroot <<SQL
CREATE DATABASE ${GUAC_DB_NAME};
CREATE USER '${GUAC_DB_USER}'@'localhost' IDENTIFIED BY '${GUAC_DB_PASSWORD}';
GRANT SELECT,INSERT,UPDATE,DELETE ON ${GUAC_DB_NAME}.* TO '${GUAC_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
  echo "Import des schémas SQL Guacamole..."
  cat /opt/guacamole/schema/*.sql | mysql -uroot ${GUAC_DB_NAME}
else
  echo "Base ${GUAC_DB_NAME} déjà initialisée, OK."
fi

echo "==> Vérification que les tables Guacamole existent..."
until mysql -uroot ${GUAC_DB_NAME} -e "SELECT 1 FROM guacamole_entity LIMIT 1;" >/dev/null 2>&1; do
  echo "Tables pas encore prêtes..."
  sleep 2
done

echo "==> Création du groupe 'technique' avec droits complets..."
mysql -uroot ${GUAC_DB_NAME} <<SQL
INSERT IGNORE INTO guacamole_entity (name, type) VALUES ('technique', 'USER_GROUP');

INSERT IGNORE INTO guacamole_user_group (entity_id, disabled)
SELECT entity_id, 0 FROM guacamole_entity WHERE name = 'technique' AND type = 'USER_GROUP';

INSERT IGNORE INTO guacamole_system_permission (entity_id, permission)
SELECT e.entity_id, perm.permission
FROM guacamole_entity e
JOIN (
  SELECT 'ADMINISTER'            AS permission
  UNION SELECT 'CREATE_CONNECTION'
  UNION SELECT 'CREATE_CONNECTION_GROUP'
  UNION SELECT 'CREATE_USER'
  UNION SELECT 'CREATE_USER_GROUP'
  UNION SELECT 'CREATE_SHARING_PROFILE'
) perm WHERE e.name = 'technique';
SQL

echo "==> Vérification du groupe créé..."
mysql -uroot ${GUAC_DB_NAME} -e "
  SELECT e.name, g.user_group_id
  FROM guacamole_entity e
  JOIN guacamole_user_group g ON e.entity_id = g.entity_id
  WHERE e.name = 'technique';
"

echo "==> Génération de guacamole.properties..."
cat > /etc/guacamole/guacamole.properties <<PROPS
mysql-hostname: 127.0.0.1
mysql-port: 3306
mysql-database: ${GUAC_DB_NAME}
mysql-username: ${GUAC_DB_USER}
mysql-password: ${GUAC_DB_PASSWORD}

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

enable-clipboard-integration: ${CLIPBOARD_ENABLED}
document-printing-enabled: ${DOCUMENT_PRINTING_ENABLED}

local-storage-enabled: ${LOCAL_STORAGE_ENABLED}
local-storage-directory: ${LOCAL_STORAGE_DIR}
PROPS

echo "==> Démarrage de guacd..."
guacd &

echo "==> Démarrage de Tomcat (Guacamole Web)..."
exec catalina.sh run
