-- ===========================================
-- Finareo Database Initialization
-- ===========================================

-- Create database if not exists (handled by Docker, but included for completeness)
CREATE DATABASE IF NOT EXISTS finareo
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE finareo;

-- Grant privileges to application user
-- Note: User creation is handled by Docker environment variables
-- This script runs after the user is created

-- Performance optimizations
SET GLOBAL innodb_buffer_pool_size = 268435456; -- 256MB
SET GLOBAL innodb_log_file_size = 67108864; -- 64MB
SET GLOBAL max_connections = 200;
SET GLOBAL thread_cache_size = 8;

-- Enable slow query log for debugging
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;

-- Output confirmation
SELECT 'Finareo database initialized successfully!' AS message;
