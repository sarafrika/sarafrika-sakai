-- Create Sakai database if it doesn't exist
CREATE DATABASE IF NOT EXISTS sakai DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user if it doesn't exist and grant privileges
CREATE USER IF NOT EXISTS 'sakai'@'%' IDENTIFIED BY 'sakaipassword';
GRANT ALL PRIVILEGES ON sakai.* TO 'sakai'@'%';
FLUSH PRIVILEGES;