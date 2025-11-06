#!/bin/bash
# Script to initialize MySQL and import dump during Docker build
set -e

echo "Initializing MySQL database..."
mysql_install_db --user=mysql --datadir=/var/lib/mysql

echo "Starting MySQL in background..."
mysqld_safe --user=mysql --datadir=/var/lib/mysql --skip-networking --skip-grant-tables &

echo "Waiting for MySQL to be ready..."
for i in {30..0}; do
    if mysqladmin ping --silent 2>/dev/null; then
        echo "MySQL is ready!"
        break
    fi
    echo "MySQL init process in progress... ($i)"
    sleep 1
done

if [ "$i" = 0 ]; then
    echo >&2 'MySQL init process failed.'
    exit 1
fi

echo "Setting up database..."
mysql -e "CREATE DATABASE IF NOT EXISTS magentodb CHARACTER SET utf8 COLLATE utf8_general_ci;"

echo "Loading grant tables and setting up users..."
mysql << EOF
FLUSH PRIVILEGES;
CREATE USER IF NOT EXISTS 'magentouser'@'localhost' IDENTIFIED BY 'MyPassword';
CREATE USER IF NOT EXISTS 'magentouser'@'127.0.0.1' IDENTIFIED BY 'MyPassword';
CREATE USER IF NOT EXISTS 'magentouser'@'%' IDENTIFIED BY 'MyPassword';
GRANT ALL PRIVILEGES ON magentodb.* TO 'magentouser'@'localhost';
GRANT ALL PRIVILEGES ON magentodb.* TO 'magentouser'@'127.0.0.1';
GRANT ALL PRIVILEGES ON magentodb.* TO 'magentouser'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '1234567890';
DELETE FROM mysql.user WHERE User = '' OR Password = '';
FLUSH PRIVILEGES;
EOF

echo "Decompressing database dump..."
xzcat /tmp/magento_dump.sql.xz > /tmp/magento_dump.sql

echo "Importing database dump (this may take a while)..."
mysql -uroot -p1234567890 magentodb < /tmp/magento_dump.sql

echo "Updating base URLs to localhost..."
mysql -uroot -p1234567890 magentodb -e "UPDATE core_config_data SET value='http://localhost:7770/' WHERE path LIKE '%base_url%';"

echo "Configuring search to use Elasticsearch..."
mysql -uroot -p1234567890 magentodb << EOF
INSERT INTO core_config_data (scope, scope_id, path, value) VALUES
('default', 0, 'catalog/search/engine', 'elasticsearch7'),
('default', 0, 'catalog/search/elasticsearch7_server_hostname', 'localhost'),
('default', 0, 'catalog/search/elasticsearch7_server_port', '9200'),
('default', 0, 'catalog/search/elasticsearch7_index_prefix', 'magento2'),
('default', 0, 'catalog/search/elasticsearch7_enable_auth', '0'),
('default', 0, 'catalog/search/elasticsearch7_server_timeout', '15');
EOF

echo "Database import complete, shutting down MySQL..."
if ! mysqladmin -uroot -p1234567890 shutdown; then
    echo "Normal shutdown failed, using killall"
    killall mysqld mysqld_safe
    sleep 5
fi

# Wait for all MySQL processes to end
while pgrep -x mysqld > /dev/null; do
    echo "Waiting for MySQL to shutdown..."
    sleep 1
done

echo "Saving golden state..."
cp -R /var/lib/mysql /var/lib/mysql.golden

echo "MySQL initialization complete!"