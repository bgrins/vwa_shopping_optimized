# Debian Migration Notes

## Major Changes from Alpine to Debian 12

### Dockerfile Changes
- Base image: `alpine:3.16` → `debian:12-slim`
- Package manager: `apk` → `apt-get`
- PHP version: `php81` → `php8.2`
- Java version: `openjdk11` → `openjdk-17-jre-headless`
- User/group commands: `adduser -D` → `useradd -m`
- Removed Alpine-specific iconv hacks (not needed on Debian)

### Path Changes
- PHP-FPM config: `/etc/php81/php-fpm.d/www.conf` → `/etc/php/8.2/fpm/pool.d/www.conf`
- Supervisor config: `/etc/supervisor.d/` → `/etc/supervisor/conf.d/`
- Supervisor main: `/etc/supervisord.conf` → `/etc/supervisor/supervisord.conf`
- Nginx sites: `/etc/nginx/http.d/` → `/etc/nginx/sites-available/` + `/etc/nginx/sites-enabled/`
- MySQL config: `/etc/my.cnf` → `/etc/mysql/conf.d/custom.cnf`

### User Changes
- Web server user: `nginx` → `www-data`
- Elasticsearch user: `elastico` (unchanged)

### Services Fixed
- ✅ Elasticsearch (native glibc support)
- ✅ Mailcatcher (Ruby gems with native extensions work)
- ✅ Cron (standard glibc binaries)

### Configuration Changes Made
1. ✅ Updated supervisor service definitions:
   - supervisord.conf: `/etc/supervisor.d/` → `/etc/supervisor/conf.d/`
   - php-fpm.ini: `php-fpm81` → `php-fpm8.2`
   - cron.ini: `crond -f` → `cron -f`
   - elasticsearch.ini: Added environment variable for ES_JAVA_HOME
2. ✅ Updated entrypoint scripts:
   - Supervisor paths: `/etc/supervisor.d/` → `/etc/supervisor/conf.d/`
   - User/group: `nginx:nginx` → `www-data:www-data`
   - PHP command: `php81` → `php` (generic command)
3. ✅ Removed php8.2-sodium from package list (built into core php8.2)
4. ✅ PHP-FPM configured to use TCP on 127.0.0.1:9000
5. ✅ Elasticsearch fixes (CRITICAL):
   - Created JDK symlink: `/usr/share/java/elasticsearch/jdk` → `/usr/lib/jvm/java-17-openjdk-arm64`
   - Limited memory: Created `jvm.options.d/memory.options` with `-Xms1024m -Xmx1024m` (default was 4GB)
   - Root cause: ES expects bundled JDK which doesn't exist when using system Java

### Testing Results
- ✅ Elasticsearch 7.17.0 starts successfully on Debian 12 with glibc
- ✅ Port 9200 responds correctly
- ✅ Search functionality works (tested with query for "tea")
- ✅ All services running: MySQL, Nginx, PHP-FPM, Redis, Cron, Mailcatcher, Supervisor
