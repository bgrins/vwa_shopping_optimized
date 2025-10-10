
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

Inspecting

```
docker inspect shopping_final_0712 --format='{{.Config.Cmd}}' && echo "---" && docker inspect shopping_final_0712 --format='{{.Config.Entrypoint}}' && echo "---" && docker inspect shopping_final_0712   --format='{{.Config.ExposedPorts}}'  
docker exec shopping cat /etc/os-release
docker exec shopping ps aux
docker exec shopping php -v
docker exec shopping cat /docker-entrypoint.sh
docker exec shopping find /etc/supervisor.d/ -name "*.ini" -exec basename {} \; | sort
docker exec shopping ls -la /var/www/magento2
docker exec shopping mysql -umagentouser -pMyPassword magentodb -e "SHOW TABLES;"
docker exec shopping cat /etc/supervisord.conf
docker exec shopping cat /etc/nginx/conf.d/default.conf

docker exec shopping sh -c "find /var/www/magento2/pub/media/catalog/product -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.webp' \\)"
docker exec shopping sh -c "ls -1 /var/www/magento2/pub/media/catalog/product/*/* 2>/dev/null | wc -l"

docker exec shopping mysql -umagentouser -pMyPassword magentodb -e "SELECT value FROM catalog_product_entity_media_gallery WHERE value LIKE '%.jpg' LIMIT 5;"
docker exec shopping mysql -umagentouser -pMyPassword magentodb -e "DESCRIBE catalog_product_entity_media_gallery;"
docker exec shopping mysql -umagentouser -pMyPassword magentodb -e "SELECT DISTINCT media_type FROM catalog_product_entity_media_gallery;"


```


```
docker cp shopping:/docker-entrypoint.sh shopping_base_image/docker-entrypoint.sh && docker cp shopping:/etc/supervisor.d shopping_base_image/supervisor.d
docker cp shopping:/etc/supervisord.conf shopping_base_image/supervisord.conf
docker cp shopping:/etc/nginx/conf.d/default.conf shopping_base_image/nginx-default.conf


cp shopping_base_image/nginx-default.conf shopping_docker_rebuild/nginx-default.conf

````



Original instructions from https://github.com/web-arena-x/visualwebarena/tree/89f5af29305c3d1e9f97ce4421462060a70c9a03/environment_docker#shopping-website-onestopshop:

```
docker load --input shopping_final_0712.tar
docker run --name shopping -p 7770:80 -d shopping_final_0712
# wait ~1 min to wait all services to start

docker exec shopping /var/www/magento2/bin/magento setup:store-config:set --base-url="http://<your-server-hostname>:7770" # no trailing slash
docker exec shopping mysql -u magentouser -pMyPassword magentodb -e  'UPDATE core_config_data SET value="http://<your-server-hostname>:7770/" WHERE path = "web/secure/base_url";'
docker exec shopping /var/www/magento2/bin/magento cache:flush
ok, 
# Disable re-indexing of products
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
