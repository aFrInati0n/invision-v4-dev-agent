#!/bin/sh
# IC4 dev php-fpm entrypoint: wait for MariaDB + Redis, then run FPM in
# the foreground (docker-managed lifecycle; no daemonize).
set -e

echo "Waiting for database at ${DB_HOST:-db}..."
php -r '
$host = getenv("DB_HOST") ?: "db";
$port = getenv("DB_PORT") ?: "3306";
$tries = 60;
for ($i = 1; $i <= $tries; $i++) {
    $c = @stream_socket_client("tcp://$host:$port", $errno, $errstr, 2);
    if ($c) { fclose($c); exit(0); }
    usleep(1000000);
    if ($i === $tries) { fwrite(STDERR, "db unreachable: $errstr\n"); exit(1); }
}'

echo "Waiting for redis at ${REDIS_HOST:-redis}..."
php -r '
$host = getenv("REDIS_HOST") ?: "redis";
$port = getenv("REDIS_PORT") ?: "6379";
$tries = 60;
for ($i = 1; $i <= $tries; $i++) {
    $c = @stream_socket_client("tcp://$host:$port", $errno, $errstr, 2);
    if ($c) { fclose($c); exit(0); }
    usleep(1000000);
    if ($i === $tries) { fwrite(STDERR, "redis unreachable: $errstr\n"); exit(1); }
}'

echo "Starting php-fpm..."
# No -D: the base image sets `daemonize = no`, so php-fpm runs in the
# foreground and the container's lifecycle stays with it.
exec php-fpm
