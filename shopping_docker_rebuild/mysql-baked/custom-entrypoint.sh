#!/bin/bash
# Reset database to golden state on container start if RESET_DB=true
if [ "$RESET_DB" == "true" ] && [ -d "/var/lib/mysql-golden" ]; then
    echo "Resetting database to golden state..."
    rm -rf /var/lib/mysql/*
    cp -R /var/lib/mysql-golden/* /var/lib/mysql/
    chown -R mysql:mysql /var/lib/mysql
fi

# Call the original entrypoint
exec docker-entrypoint.sh "$@"