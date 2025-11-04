FROM mysql:5.7 AS builder

ENV MYSQL_ROOT_PASSWORD=1234567890
ENV MYSQL_DATABASE=magentodb
ENV MYSQL_USER=magentouser
ENV MYSQL_PASSWORD=MyPassword

# Copy SQL dump to temp directory
COPY magento_dump.sql /tmp/sql/

# Initialize and populate database
RUN mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql && \
    mysqld --user=mysql --datadir=/var/lib/mysql --socket=/tmp/mysql.sock & \
    pid="$!" && \
    echo "Waiting for MySQL to start..." && \
    for i in {60..0}; do \
        if mysql -u root --socket=/tmp/mysql.sock -e "SELECT 1" &> /dev/null; then \
            break; \
        fi; \
        sleep 1; \
    done && \
    if [ "$i" = 0 ]; then \
        echo "MySQL failed to start"; \
        exit 1; \
    fi && \
    echo "MySQL started, creating database and user..." && \
    mysql -u root --socket=/tmp/mysql.sock -e "CREATE DATABASE IF NOT EXISTS magentodb;" && \
    mysql -u root --socket=/tmp/mysql.sock -e "CREATE USER IF NOT EXISTS 'magentouser'@'%' IDENTIFIED BY 'MyPassword';" && \
    mysql -u root --socket=/tmp/mysql.sock -e "GRANT ALL PRIVILEGES ON magentodb.* TO 'magentouser'@'%';" && \
    mysql -u root --socket=/tmp/mysql.sock -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '1234567890';" && \
    mysql -u root --socket=/tmp/mysql.sock -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;" && \
    echo "Loading data..." && \
    mysql -u root --socket=/tmp/mysql.sock magentodb < /tmp/sql/magento_dump.sql && \
    mysql -u root --socket=/tmp/mysql.sock -e "FLUSH PRIVILEGES;" && \
    echo "Data loaded, shutting down MySQL..." && \
    mysqladmin -u root --socket=/tmp/mysql.sock shutdown && \
    wait "$pid"

FROM mysql:5.7

# Copy the golden state to a separate directory
COPY --from=builder /var/lib/mysql /var/lib/mysql-golden
# Also copy it to the working directory for first start
COPY --from=builder /var/lib/mysql /var/lib/mysql

ENV MYSQL_ROOT_PASSWORD=1234567890
ENV MYSQL_DATABASE=magentodb
ENV MYSQL_USER=magentouser
ENV MYSQL_PASSWORD=MyPassword

# Add custom entrypoint that can reset data on every start if needed
COPY custom-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

ENTRYPOINT ["custom-entrypoint.sh"]
CMD ["mysqld"]

# Add healthcheck to ensure MySQL is ready
HEALTHCHECK --interval=1s --timeout=3s --start-period=10s --retries=30 \
  CMD mysqladmin ping -h localhost -u root -p1234567890 || exit 1