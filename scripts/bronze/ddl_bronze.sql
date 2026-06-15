USE DataWarehouse;
GO

-- Xóa bảng cũ nếu tồn tại (để có thể chạy lại script)
IF OBJECT_ID('bronze.retail_sales', 'U') IS NOT NULL
    DROP TABLE bronze.retail_sales;
GO

CREATE TABLE bronze.retail_sales (
    transaction_id      INT,
    date                NVARCHAR(20),       -- Giữ nguyên dạng string như trong CSV
    customer_id         NVARCHAR(20),
    gender              NVARCHAR(10),
    age                 INT,
    product_category    NVARCHAR(50),
    quantity            INT,
    price_per_unit      INT,
    total_amount        INT
);
GO

PRINT 'Bảng bronze.retail_sales đã được tạo.';