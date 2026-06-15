-- ============================================================
-- Script: init_database.sql
-- Mục đích: Khởi tạo Database và 3 Schema cho Medallion Architecture
-- Cảnh báo: Script này sẽ tạo mới database DataWarehouse.
--           Nếu đã tồn tại, hãy kiểm tra trước khi chạy.
-- ============================================================

USE master;
GO

-- Tạo Database
CREATE DATABASE DataWarehouse;
GO

USE DataWarehouse;
GO

-- Tạo 3 Schema tương ứng với kiến trúc Medallion
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO

PRINT 'Database và 3 Schema đã được tạo thành công!';