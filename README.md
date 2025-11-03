
Download https://drive.usercontent.google.com/download?id=1gxXalk9O0p9eu1YkIJcmZta1nvvyAJpA&export=download&authuser=0

```

docker load --input shopping_final_0712.tar
docker run --name shopping -p 7770:80 -d shopping_final_0712
docker exec shopping /var/www/magento2/bin/magento setup:store-config:set --base-url="http://localhost:7770"
docker exec shopping mysql -u magentouser -pMyPassword magentodb -e 'UPDATE core_config_data SET value="http://localhost:7770/" WHERE path = "web/secure/base_url";'
docker exec shopping /var/www/magento2/bin/magento cache:flush

# Todo - move these into docker entrypoint and/or db seed data
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_product
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalogrule_rule
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalogsearch_fulltext
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalog_category_product
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule customer_grid
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule design_config_grid
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule inventory
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_category
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_attribute
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule catalog_product_price
docker exec shopping /var/www/magento2/bin/magento indexer:set-mode schedule cataloginventory_stock
```

Copy files from base image
```
docker exec shopping mysqldump --no-tablespaces -u root -p1234567890 magentodb > shopping_docker_rebuild/mysql-baked/magento_dump.sql
xz -9 -k shopping_docker_rebuild/mysql-baked/magento_dump.sql

# Remove enormous & unnecessary cache dir before copying
docker exec shopping rm -r /var/www/magento2/pub

docker cp shopping:/etc/supervisord.conf shopping_base_image/supervisord.conf
docker cp shopping:/etc/nginx/conf.d/default.conf shopping_base_image/nginx-default.conf
docker cp shopping:/var/www/magento2 shopping_base_image/shopping_extracted/

cp -r shopping_base_image/shopping_extracted/magento2/pub/media/catalog/product shopping_extracted_backup
rm -r shopping_base_image/shopping_extracted/magento2/pub/media/catalog/product
rm -r shopping_base_image/shopping_extracted/magento2/dev
```

Optimize images
```
./scripts/optimize_jpeg_quality.sh 30
find shopping_extracted_jpg30 -name "*.done" -delete
cp -r shopping_extracted_jpg30/* shopping_base_image/shopping_extracted/magento2/pub/media/catalog/product/
```


