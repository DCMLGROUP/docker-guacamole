#!/bin/bash
set -e

echo "==> Démarrage MariaDB..."
mysqld_safe --bind-address=127.0.0.1 &
# Attente que MariaDB réponde
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
  mysql -uroot <<EOF
CREATE DATABASE ${GUAC_DB_NAME};
CREATE USER '${GUAC_DB_USER}'@'localhost' IDENTIFIED BY '${GUAC_DB_PASSWORD}';
GRANT SELECT,INSERT,UPDATE,DELETE ON ${GUAC_DB_NAME}.* TO '${GUAC_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

  echo "Import des schémas SQL Guacamole..."
  cat /opt/guacamole/schema/*.sql | mysql -uroot ${GUAC_DB_NAME}
else
  echo "Base ${GUAC_DB_NAME} déjà initialisée, OK."
fi

echo "==> Création du groupe technique avec droits complets..."

mysql -uroot ${GUAC_DB_NAME} <<EOF

-- Création du groupe (s'il n'existe pas déjà)
INSERT IGNORE INTO guacamole_user_group (entity_id, disabled)
SELECT entity_id, 0 FROM guacamole_entity
WHERE name = 'tech_group' AND type = 'USER_GROUP';

-- Si le groupe n'existe pas encore dans guacamole_entity
INSERT IGNORE INTO guacamole_entity (name, type)
VALUES ('tech_group', 'USER_GROUP');

-- Associer entity -> user_group (si nécessaire)
INSERT IGNORE INTO guacamole_user_group (entity_id, disabled)
SELECT entity_id, 0 FROM guacamole_entity
WHERE name = 'tech_group' AND type = 'USER_GROUP';

-- Donner tous les droits système
INSERT IGNORE INTO guacamole_system_permission (entity_id, permission)
SELECT e.entity_id, p.permission
FROM guacamole_entity e
JOIN (
  SELECT 'CREATE_CONNECTION' AS permission
  UNION SELECT 'CREATE_CONNECTION_GROUP'
  UNION SELECT 'CREATE_SHARING_PROFILE'
  UNION SELECT 'CREATE_USER'
  UNION SELECT 'CREATE_USER_GROUP'
  UNION SELECT 'ADMINISTER'
) p
WHERE e.name = 'tech_group';

EOF

echo "Groupe technique créé avec droits complets."

echo "==> Démarrage de guacd..."
guacd &

echo "==> Démarrage de Tomcat (Guacamole Web)..."
exec catalina.sh run
