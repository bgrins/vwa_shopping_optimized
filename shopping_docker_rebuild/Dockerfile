FROM bgrins/vwa-shopping-optimized-base:latest AS base

ARG MAGENTO_VERSION=2.4.6
ARG SAMPLE_DATA=true

RUN mkdir -p /var/www/magento2 && \
    chown -R www-data:www-data /var/www/magento2

WORKDIR /var/www/magento2

COPY --from=shopping_final_0712 /var/www/magento2 /var/www/magento2
COPY --from=shopping_final_0712 /var/lib/mysql /var/lib/mysql.template

COPY nginx-default.conf /etc/nginx/conf.d/default.conf
COPY entrypoint-optimized.sh /docker-entrypoint-optimized.sh
RUN chmod +x /docker-entrypoint-optimized.sh

FROM base AS with-mysql
ENV DISABLE=""
EXPOSE 80 3306 9200 6379 88 25

ENTRYPOINT ["/docker-entrypoint-optimized.sh"]
CMD ["supervisord", "-n", "-j", "/supervisord.pid"]

FROM base AS without-mysql
ENV DISABLE="mysql"
ENV MYSQL_HOST=mysql \
    MYSQL_PORT=3306

EXPOSE 80 9200 6379 88 25

ENTRYPOINT ["/docker-entrypoint-optimized.sh"]
CMD ["supervisord", "-n", "-j", "/supervisord.pid"]