FROM bgrins/vwa-shopping-optimized-base:latest AS base

WORKDIR /var/www/magento2

COPY nginx-default.conf /etc/nginx/http.d/magento.conf
COPY entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

FROM base AS with-mysql
# Store MySQL data as template to be restored on first run
# Todo: Import from db dump instead of copying from live image
COPY --from=shopping_final_0712 /var/lib/mysql /var/lib/mysql.template
ENV DISABLE=""
EXPOSE 80 3306 9200 6379 88 25

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["supervisord", "-n", "-j", "/supervisord.pid"]

FROM base AS without-mysql
ENV DISABLE="mysql"
ENV MYSQL_HOST=mysql \
    MYSQL_PORT=3306

EXPOSE 80 9200 6379 88 25

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["supervisord", "-n", "-j", "/supervisord.pid"]