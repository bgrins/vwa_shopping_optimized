FROM bgrins/vwa-shopping-optimized-base:latest AS extractor
# Extract data from the bloated image without including the runtime layers
COPY --from=shopping_final_0712 /var/www/magento2 /var/www/magento2
COPY --from=shopping_final_0712 /var/lib/mysql /var/lib/mysql

FROM bgrins/vwa-shopping-optimized-base:latest AS base

RUN mkdir -p /var/www/magento2 && \
    chown -R www-data:www-data /var/www/magento2

WORKDIR /var/www/magento2

# Copy only the application files, not runtime data
COPY --from=extractor /var/www/magento2 /var/www/magento2
# Store MySQL data as template to be restored on first run
COPY --from=extractor /var/lib/mysql /var/lib/mysql.template

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