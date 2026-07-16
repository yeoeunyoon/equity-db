<?php
// config.php — database connection settings.
// Credentials are read from the environment (see .env.example / docker-compose.yml).
// No secrets are stored in this file.

define('DB_HOST', getenv('DB_HOST') ?: 'db');
define('DB_NAME', getenv('DB_NAME') ?: 'equity_db');
define('DB_USER', getenv('DB_USER') ?: 'equity');
define('DB_PASS', getenv('DB_PASS') ?: 'equity');

function get_db(): mysqli {
    // Don't let mysqli throw — we want to emit a clean JSON error instead.
    mysqli_report(MYSQLI_REPORT_OFF);

    $conn = @new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    if ($conn->connect_error) {
        http_response_code(500);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'Database connection failed: ' . $conn->connect_error]);
        exit;
    }

    $conn->set_charset('utf8mb4');
    return $conn;
}
