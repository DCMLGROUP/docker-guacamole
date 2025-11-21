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

echo "==> Démarrage de guacd..."
guacd &

echo "==> Démarrage de Tomcat (Guacamole Web)..."
exec catalina.sh run
