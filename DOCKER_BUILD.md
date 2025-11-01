# VWA Shopping Docker Build

This repository contains optimized Docker builds for the VWA Shopping (Magento) environment.

## Architecture

- **Base Image**: Alpine Linux 3.16 with PHP 8.1, MySQL, Nginx, Redis, Elasticsearch
- **Bundled Version**: Includes MySQL database (all-in-one container)
- **Standalone Version**: External MySQL database support

## Building

```bash
# Build and push all variants
./build-and-push.sh
```

## Usage

### Bundled Version (with MySQL)
```bash
docker run -d \
  --name vwa-shopping \
  -p 7770:80 \
  -p 3306:3306 \
  -e BASE_URL=http://localhost:7770 \
  ghcr.io/bgrins/vwa-shopping-optimized-bundled:latest
```

### Standalone Version (external MySQL)
```bash
docker run -d \
  --name vwa-shopping \
  -p 7770:80 \
  -e BASE_URL=http://localhost:7770 \
  -e MYSQL_HOST=mysql.example.com \
  -e MYSQL_PORT=3306 \
  -e MYSQL_USER=magentouser \
  -e MYSQL_PASSWORD=MyPassword \
  -e MYSQL_DATABASE=magentodb \
  ghcr.io/bgrins/vwa-shopping-optimized-standalone:latest
```

## Environment Variables

- `BASE_URL`: Magento base URL (default: http://localhost:7770)
- `MYSQL_HOST`: MySQL host (standalone only)
- `MYSQL_PORT`: MySQL port (standalone only, default: 3306)
- `MYSQL_USER`: MySQL user (default: magentouser)
- `MYSQL_PASSWORD`: MySQL password (default: MyPassword)
- `MYSQL_DATABASE`: MySQL database (default: magentodb)
- `MYSQL_ROOT_PASSWORD`: MySQL root password (bundled only, default: 1234567890)

## Services

The container includes:
- Nginx (port 80)
- PHP-FPM 8.1
- MySQL/MariaDB (port 3306, bundled version only)
- Redis (port 6379)
- Elasticsearch (port 9200)
- Mailcatcher (port 88 for web UI, port 25 for SMTP)

## Notes

- Initial startup takes ~1 minute for all services to initialize
- Magento configuration is automatically applied on first run
- Product re-indexing is disabled by default for better performance