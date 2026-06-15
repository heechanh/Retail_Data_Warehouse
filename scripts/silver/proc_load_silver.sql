-- ============================================================
-- Script: proc_load_silver.sql
-- Mục đích: Làm sạch dữ liệu từ Bronze và nạp vào Silver
-- ============================================================

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @end_time   DATETIME2;

    BEGIN TRY
        PRINT '============================================';
        PRINT 'BẮT ĐẦU NẠP DỮ LIỆU LỚP SILVER';
        PRINT '============================================';

        PRINT '>> Đang làm trống bảng silver.retail_sales...';
        TRUNCATE TABLE silver.retail_sales;

        PRINT '>> Đang làm sạch và nạp dữ liệu...';

        INSERT INTO silver.retail_sales (
            transaction_id,
            sale_date,
            customer_id,
            gender,
            product_category,
            quantity,
            price_per_unit,
            total_amount
        )
        SELECT
            -- 1. Giữ nguyên transaction_id
            transaction_id,

            -- 2. Chuyển đổi kiểu dữ liệu: STRING → DATE
            --    Xử lý trường hợp date không đúng định dạng bằng TRY_CONVERT
            TRY_CONVERT(DATE, date, 23)     AS sale_date,

            -- 3. Chuẩn hóa customer_id: xóa khoảng trắng thừa
            TRIM(customer_id)               AS customer_id,

            -- 4. Chuẩn hóa gender: chỉ lấy 'Male' hoặc 'Female', còn lại → NULL
            CASE
                WHEN TRIM(gender) IN ('Male', 'Female') THEN TRIM(gender)
                ELSE NULL
            END                             AS gender,

            -- 5. Chuẩn hóa age: loại bỏ giá trị vô lý (< 0 hoặc > 120)
            CASE
                WHEN age BETWEEN 0 AND 120 THEN age
                ELSE NULL
            END                             AS age,

            -- 6. Chuẩn hóa product_category
            TRIM(product_category)          AS product_category,

            -- 7. Giữ nguyên quantity (đã hợp lệ: 1–4)
            quantity,

            -- 8. Giữ nguyên price_per_unit
            price_per_unit,

            -- 9. Áp dụng quy tắc kinh doanh:
            --    Nếu total_amount không khớp quantity * price_per_unit → tính lại
            CASE
                WHEN total_amount = quantity * price_per_unit THEN total_amount
                ELSE quantity * price_per_unit
            END                             AS total_amount

        FROM bronze.retail_sales
        -- Loại bỏ bản ghi có transaction_id null (không hợp lệ)
        WHERE transaction_id IS NOT NULL;

        SET @end_time = GETDATE();

        PRINT '>> Nạp dữ liệu Silver THÀNH CÔNG!';
        PRINT '>> Thời gian: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' giây';

    END TRY
    BEGIN CATCH
        PRINT '>> LỖI: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

-- Thực thi
EXEC silver.load_silver;