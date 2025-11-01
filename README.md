
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

Optimize images
```
cp -r shopping_extracted/magento2/pub/media/catalog/product shopping_extracted_backup

# Scripts can be called from anywhere - they auto-detect paths
./scripts/optimize_vips.sh

# Or from the scripts directory
cd scripts && ./optimize_vips.sh

# Other optimization scripts available:
./scripts/optimize_images.sh test      # Test different quality levels
./scripts/optimize_jpg50.sh           # Optimize to 50% quality
./scripts/optimize_avif.sh            # Convert to AVIF format
./scripts/analyze_product.sh "product-slug"  # Analyze product cache
```

