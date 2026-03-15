-- ============================================================
-- setup.sql
-- Run this once to create the database and users table.
-- Command: mysql -u root -p < setup.sql
-- ============================================================

-- Create database if it doesn't already exist
CREATE DATABASE IF NOT EXISTS auth_db;
USE auth_db;

-- Users table
-- Passwords are NEVER stored as plain text — only bcrypt hashes
CREATE TABLE IF NOT EXISTS users (
    id         INT          AUTO_INCREMENT PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(255) NOT NULL UNIQUE,   -- Unique constraint prevents duplicate accounts
    password   VARCHAR(255) NOT NULL,          -- Stores bcrypt hash
    created_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Index on email column for faster login lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);