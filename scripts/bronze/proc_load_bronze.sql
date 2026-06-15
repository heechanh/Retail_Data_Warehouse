-- ============================================================
-- Script: proc_load_bronze.sql
-- Mục đích: Nạp dữ liệu thô từ CSV vào lớp Bronze
-- Chiến lược: Full Load (TRUNCATE → BULK INSERT)
-- ============================================================

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    DECLARE @start_time DATETIME2 = GETDATE();
    DECLARE @end_time   DATETIME2;
    DECLARE @duration   INT;

    BEGIN TRY
        PRINT '============================================';
        PRINT 'BẮT ĐẦU NẠP DỮ LIỆU LỚP BRONZE';
        PRINT '============================================';

        -- Bước 1: Xóa dữ liệu cũ
        PRINT '>> Đang làm trống bảng bronze.retail_sales...';
        TRUNCATE TABLE bronze.retail_sales;

        -- Bước 2: Nạp dữ liệu từ CSV
        PRINT '>> Đang nạp dữ liệu từ file CSV...';
        BULK INSERT bronze.retail_sales
        FROM 'E:\Retail_Data_Warehouse\datasets\retail_sales_dataset.csv'  -- Thay đường dẫn thực tế
        WITH (
            FIRSTROW        = 2,            -- Bỏ qua dòng tiêu đề (header)
            FIELDTERMINATOR = ',',          -- Dấu phẩy ngăn cách các cột
            ROWTERMINATOR   = '\n',         -- Xuống dòng ngăn cách các bản ghi
            TABLOCK                         -- Khóa bảng để tăng tốc độ nạp
        );

        SET @end_time = GETDATE();
		SET @duration = DATEDIFF(SECOND, @start_time, @end_time);

        PRINT '>> Nạp dữ liệu THÀNH CÔNG!';
        PRINT '>> Thời gian thực thi: ' + CAST(@duration AS NVARCHAR) + ' giây';
        PRINT '============================================';

    END TRY
    BEGIN CATCH
        PRINT '>> LỖI: ' + ERROR_MESSAGE();
        PRINT '>> Mã lỗi: ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        THROW;
    END CATCH
END;
GO

-- Thực thi Stored Procedure
EXEC bronze.load_bronze;