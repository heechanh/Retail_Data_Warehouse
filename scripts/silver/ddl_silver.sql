-- ============================================================
-- Script: ddl_silver.sql
-- Mục đích: Tạo bảng sạch lớp Silver
-- Thay đổi so với Bronze:
--   - Đổi tên cột theo snake_case chuẩn
--   - Cột 'date' chuyển từ NVARCHAR → DATE
--   - Thêm cột metadata dw_create_date
-- ============================================================

USE DataWarehouse;
GO

IF OBJECT_ID('silver.retail_sales', 'U') IS NOT NULL
    DROP TABLE silver.retail_sales;
GO

CREATE TABLE silver.retail_sales (
    transaction_id      INT,
    sale_date           DATE,               -- Đã chuyển sang kiểu DATE thực sự
    customer_id         NVARCHAR(20),
    gender              NVARCHAR(10),
    age                 INT,
    product_category    NVARCHAR(50),
    quantity            INT,
    price_per_unit      INT,
    total_amount        INT,
    dw_create_date      DATETIME2 DEFAULT GETDATE()  -- Metadata: thời điểm nạp vào DWH
);
GO

PRINT 'Bảng silver.retail_sales đã được tạo.';