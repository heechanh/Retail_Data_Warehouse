-- ============================================================
-- Script: gold/ddl_gold_views.sql
-- View: gold.dim_customers
-- Mục đích: Thông tin mô tả về khách hàng
-- ============================================================

USE DataWarehouse;
GO

CREATE OR ALTER VIEW gold.dim_customers AS
SELECT
    -- Surrogate Key: khóa thay thế nội bộ DWH
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,

    customer_id,
    gender,
    age,

    -- Tạo nhóm tuổi – logic kinh doanh đặc trưng của lớp Gold
    CASE
        WHEN age BETWEEN 18 AND 25 THEN '18–25'
        WHEN age BETWEEN 26 AND 35 THEN '26–35'
        WHEN age BETWEEN 36 AND 45 THEN '36–45'
        WHEN age BETWEEN 46 AND 55 THEN '46–55'
        WHEN age BETWEEN 56 AND 64 THEN '56–64'
        ELSE 'Unknown'
    END AS age_group

FROM (
    -- Lấy profile mới nhất của mỗi khách hàng
    -- (loại bỏ trùng lặp nếu cùng customer_id có nhiều dòng)
    SELECT
        customer_id,
        gender,
        age,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY sale_date DESC    -- Ưu tiên giao dịch gần nhất
        ) AS rn
    FROM silver.retail_sales
    WHERE customer_id IS NOT NULL
) ranked
WHERE rn = 1;
GO

-- View: gold.dim_products
-- Mục đích: Danh mục sản phẩm bán hàng
CREATE OR ALTER VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY product_category) AS product_key,
    product_category
FROM (
    SELECT DISTINCT product_category
    FROM silver.retail_sales
    WHERE product_category IS NOT NULL
) unique_products;
GO


-- View: gold.dim_date
-- Mục đích: Bảng thời gian phục vụ phân tích theo kỳ
CREATE OR ALTER VIEW gold.dim_date AS
SELECT
    ROW_NUMBER() OVER (ORDER BY sale_date)  AS date_key,
    sale_date                               AS full_date,
    YEAR(sale_date)                         AS year,
    DATEPART(QUARTER, sale_date)            AS quarter,
    MONTH(sale_date)                        AS month,
    DATENAME(MONTH, sale_date)              AS month_name,
    DAY(sale_date)                          AS day,
    DATENAME(WEEKDAY, sale_date)            AS day_of_week,
    -- Nhãn quý cho báo cáo
    'Q' + CAST(DATEPART(QUARTER, sale_date) AS NVARCHAR)
    + '-' + CAST(YEAR(sale_date) AS NVARCHAR) AS quarter_label
FROM (
    SELECT DISTINCT sale_date
    FROM silver.retail_sales
    WHERE sale_date IS NOT NULL
) unique_dates;
GO


-- View: gold.fact_sales
-- Mục đích: Bảng giao dịch trung tâm của Star Schema
-- Thực hiện Data Lookup: thay ID nguồn bằng Surrogate Keys từ Dimension
CREATE OR ALTER VIEW gold.fact_sales AS
SELECT
    s.transaction_id,

    -- Thay thế ID gốc bằng Surrogate Keys từ các Dimension
    dc.customer_key,
    dp.product_key,
    dd.date_key,

    -- Giữ lại các giá trị đo lường (metrics)
    s.quantity,
    s.price_per_unit,
    s.total_amount,

    -- Thêm metric tính toán
    s.quantity * s.price_per_unit       AS calculated_revenue  -- Doanh thu tính lại để đảm bảo

FROM silver.retail_sales s

-- LEFT JOIN để không mất dữ liệu giao dịch nếu chưa khớp với dimension
LEFT JOIN gold.dim_customers dc ON s.customer_id = dc.customer_id
LEFT JOIN gold.dim_products  dp ON s.product_category = dp.product_category
LEFT JOIN gold.dim_date      dd ON s.sale_date = dd.full_date;
GO

