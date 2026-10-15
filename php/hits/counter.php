<?php
// Prepended to every PHP request (hits.ini): counts the hit in the shared Redis.
// Errors are only logged — if Redis is down, the site still works.
(function () {
    if (PHP_SAPI === 'cli') {
        return; // `php` run by hand inside the container is not a hit
    }
    $ttl = (int) (getenv('HITS_TTL') ?: 3 * 24 * 3600);
    try {
        $redis = new Redis();
        // persistent connection: reused by the php-fpm worker between requests
        $redis->pconnect(getenv('REDIS_HOST') ?: '127.0.0.1', (int) (getenv('REDIS_PORT') ?: 6379), 0.5);
        if ($password = getenv('REDIS_PASSWORD')) {
            $redis->auth($password);
        }
        // MULTI/EXEC: increment, and start the TTL only when the key is new (NX),
        // so the counter covers a fixed 3-day window and then starts again from 0
        $tx = $redis->multi();
        foreach (['hits:total', 'hits:php'] as $key) {
            $tx->incr($key);
            $tx->expire($key, $ttl, 'NX');
        }
        $tx->exec();
    } catch (Throwable $e) {
        error_log('hit counter: ' . $e->getMessage());
    }
})();
