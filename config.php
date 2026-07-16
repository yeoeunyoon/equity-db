<?php
// config.php — database connection settings
// Update these to match your JHU class database credentials.

define('DB_HOST', '');
define('DB_USER', '');
define('DB_PASS', '');
define('DB_NAME', '');

function get_db(): mysqli {
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
    if ($conn->connect_error) {
        die('<p style="color:red">Database connection failed: ' . htmlspecialchars($conn->connect_error) . '</p>');
    }
    return $conn;
}