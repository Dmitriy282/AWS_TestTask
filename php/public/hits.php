<?php
// Shared hit counters (the hit for this request is already counted by counter.php)
header('Content-Type: application/json');

try {
    $redis = new Redis();
    $redis->pconnect(getenv('REDIS_HOST') ?: '127.0.0.1', (int) (getenv('REDIS_PORT') ?: 6379), 0.5);
    if ($password = getenv('REDIS_PASSWORD')) {
        $redis->auth($password);
    }
    $apps = ['php', 'python', 'node'];
    $values = $redis->mGet(array_merge(['hits:total'], array_map(fn ($a) => "hits:$a", $apps)));
    $counts = array_combine(array_merge(['total'], $apps), array_map('intval', $values));
    echo json_encode($counts + ['ttl_seconds' => $redis->ttl('hits:total'), 'served_by' => 'php']);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Redis: ' . $e->getMessage()]);
}
