## Running


## Summary of changes

* In the container the `shopping_extracted/magento2/pub/media/catalog/product/cache` is 20GB and unnecessary. This is removed.
* In the container the `/var/www/magento2/pub/media/catalog` is 5.6GB with 195,360 JPGs. After compressing at 30% quality this shrinks to 3.2GB.
* Elasticsearch upgraded from 6.4.3 to 7.17.0 with reindexed catalog (104k products, 1.1GB)
* Other misc directories are ignored to optimize space (see `./shopping_base_image/.dockerignore`)

## First time setup

Download https://drive.usercontent.google.com/download?id=1gxXalk9O0p9eu1YkIJcmZta1nvvyAJpA&export=download&authuser=0

```
docker load --input shopping_final_0712.tar
docker run --name shopping -p 7770:80 -d shopping_final_0712
docker exec shopping /var/www/magento2/bin/magento setup:store-config:set --base-url="http://localhost:7770"
docker exec shopping mysql -u magentouser -pMyPassword magentodb -e 'UPDATE core_config_data SET value="http://localhost:7770/" WHERE path = "web/secure/base_url";'
docker exec shopping /var/www/magento2/bin/magento cache:flush
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
docker exec shopping rm -r /var/www/magento2/pub/media/catalog/product/cache

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

Setup Elasticsearch 7 data
```
# Start fresh upstream container
docker run -d --name shopping_upstream_fresh -p 7780:80 shopping_final_0712
sleep 30  # Wait for services to start

# Copy ES7 data (original v4 index, 850MB, ES7 format)
# Elasticsearch 7.17.0 is installed from official tar in Dockerfile
docker cp shopping_upstream_fresh:/usr/share/java/elasticsearch/data shopping_base_image/elasticsearch_data_upstream

# Clean up
docker stop shopping_upstream_fresh
docker rm shopping_upstream_fresh
```

Note: Elasticsearch 7.17.0 is now installed from the official tar archive instead of using Alpine packages and copying binaries.

## Pushing
```
./build-and-push.sh
./build-and-push.sh --push --tag v1.0.0

```

```
rclone copy shopping_docker_rebuild/magento_dump.sql.xz r2:the-zoo/onestopshop
```