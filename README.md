## Running


## Summary of changes

* Migrated from Alpine Linux to Debian 12-slim for better glibc compatibility with Elasticsearch
* In the container the `shopping_extracted/magento2/pub/media/catalog/product/cache` is 20GB and unnecessary. This is removed.
* In the container the `/var/www/magento2/pub/media/catalog` is 5.6GB with 195,360 JPGs. After compressing at 30% quality this shrinks to 3.2GB.
* Elasticsearch 7.17.0 installed from official tar archive with JDK symlink and 1GB memory limit
* Elasticsearch index pre-built with `best_compression` codec (676MB, saves 21% vs default compression)
* Pre-indexed search catalog with 104,368 products - instant search on startup
* PHP upgraded to 8.2, Java upgraded to OpenJDK 17
* Other misc directories are ignored to optimize space (see `./shopping_base_image/.dockerignore`)

## Usage

### Quick Start

```bash
# Build the image
./build-and-push.sh

# Run the container
docker compose up -d

# The application will be available at http://localhost:7771
# Wait for Elasticsearch to start (~30 seconds)
# Search is pre-indexed and ready to use immediately!
```

### Environment Variables

- `BASE_URL`: Base URL for the application (default: `http://localhost:7770`)
- `DISABLE`: Comma-separated list of services to disable (e.g., `mysql,redis`)
- `RESET_DB_ON_START`: Reset database to golden state on startup (default: `false`)
- `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`: External Redis configuration (optional)
- `MYSQL_HOST`, `MYSQL_PORT`: External MySQL configuration (optional)

### Architecture

**Base Image** (`shopping_base_image/`):
- Debian 12-slim base
- Elasticsearch 7.17.0 (official tar, multi-arch support) with `best_compression` codec
- Pre-built search index (104k products, 676MB with 21% compression savings)
- PHP 8.2 with all required extensions
- MariaDB, Redis, Nginx, Supervisor
- Mailcatcher for email testing
- Pre-extracted Magento 2.4.6 with optimized images

**Rebuild Image** (`shopping_docker_rebuild/`):
- Extends base image
- Two build targets: `with-mysql` (bundled DB) and `without-mysql` (external DB)
- Runtime URL configuration via entrypoint
- Optional MySQL golden state for fast resets


## Building and Publishing

```bash
# Build locally
./build-and-push.sh

# Build and push to registry with version tag
./build-and-push.sh --push --tag v2.0.0
```

## Reproducing the Elasticsearch Index

To regenerate the compressed search index from scratch:

```bash
# Start container and reindex (6-12 minutes)
docker compose up -d
docker exec vwa-shopping-optimized-shopping-1 php -d memory_limit=2G \
  /var/www/magento2/bin/magento indexer:reindex catalogsearch_fulltext

# Extract compressed data
docker cp vwa-shopping-optimized-shopping-1:/usr/share/java/elasticsearch/data \
  shopping_base_image/elasticsearch_data_upstream
```

The index uses `best_compression` codec (configured in Dockerfile) for 21% disk space savings (676MB vs 856MB).

## Migration Notes

See `DEBIAN_MIGRATION_NOTES.md` for details on the Alpine to Debian 12 migration, including:
- Elasticsearch JDK symlink requirement
- Memory limit configuration
- Package and path differences
- Testing results