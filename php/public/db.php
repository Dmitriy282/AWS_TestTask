<?php
$dsn = sprintf('mysql:host=%s;dbname=%s', getenv('DB_HOST'), getenv('DB_NAME'));

try {
    $pdo = new PDO($dsn, getenv('DB_USER'), getenv('DB_PASSWORD'));
    $version = $pdo->query('SELECT VERSION()')->fetchColumn();
    echo "<p>Connected to MySQL {$version}</p>";
} catch (PDOException $e) {
    http_response_code(500);
    echo '<p>MySQL connection failed: ' . htmlspecialchars($e->getMessage()) . '</p>';
}
?>
