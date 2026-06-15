-- Xem nhanh dữ liệu đã nạp
SELECT TOP 10 * FROM bronze.retail_sales;

-- Kiểm tra tổng số dòng (phải = 1000)
SELECT COUNT(*) AS total_rows FROM bronze.retail_sales;

-- Xem cấu trúc dữ liệu
SELECT TOP 1000 * FROM bronze.retail_sales;

-- Kiểm tra giá trị null
SELECT
    SUM(CASE WHEN transaction_id   IS NULL THEN 1 ELSE 0 END) AS null_transaction_id,
    SUM(CASE WHEN date             IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN customer_id      IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN total_amount     IS NULL THEN 1 ELSE 0 END) AS null_total_amount
FROM bronze.retail_sales;

-- Kiểm tra bản ghi trùng lặp theo transaction_id
SELECT transaction_id, COUNT(*) AS cnt
FROM bronze.retail_sales
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- Kiểm tra logic: total_amount có = quantity * price_per_unit không?
SELECT *
FROM bronze.retail_sales
WHERE total_amount <> quantity * price_per_unit;

-- Khám phá giá trị duy nhất
SELECT DISTINCT gender           FROM bronze.retail_sales;
SELECT DISTINCT product_category FROM bronze.retail_sales;
SELECT MIN(date), MAX(date)      FROM bronze.retail_sales;

-- Xem dữ liệu đã làm sạch
SELECT TOP 10 * FROM silver.retail_sales;

-- Xác nhận kiểu dữ liệu đã đúng
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'silver' AND TABLE_NAME = 'retail_sales';

-- Kiểm tra không còn lỗi logic doanh số
SELECT COUNT(*) AS logic_errors
FROM silver.retail_sales
WHERE total_amount <> quantity * price_per_unit;
-- Kết quả phải = 0

-- Kiểm tra 3 views đã hoạt động
SELECT TOP 5 * FROM gold.dim_customers;
SELECT TOP 5 * FROM gold.dim_products;
SELECT TOP 5 * FROM gold.dim_date;
SELECT TOP 5 * FROM gold.fact_sales;

-- Kiểm tra tổng doanh thu
SELECT SUM(total_amount) AS total_revenue FROM gold.fact_sales;

-- Báo cáo mẫu 1: Doanh thu theo danh mục sản phẩm
SELECT
    p.product_category,
    SUM(f.total_amount)     AS total_revenue,
    COUNT(f.transaction_id) AS num_transactions,
    AVG(f.total_amount)     AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_category
ORDER BY total_revenue DESC;

-- Báo cáo mẫu 2: Doanh thu theo quý
SELECT
    d.year,
    d.quarter_label,
    SUM(f.total_amount) AS quarterly_revenue
FROM gold.fact_sales f
JOIN gold.dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.quarter_label, d.quarter
ORDER BY d.year, d.quarter;

-- Báo cáo mẫu 3: Doanh thu theo nhóm tuổi và giới tính
SELECT
    c.age_group,
    c.gender,
    SUM(f.total_amount)     AS total_revenue,
    COUNT(f.transaction_id) AS num_purchases
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.age_group, c.gender
ORDER BY c.age_group, c.gender;



-- Q1: Top danh mục bán chạy nhất theo doanh thu
SELECT p.product_category, SUM(f.total_amount) AS revenue
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_category ORDER BY revenue DESC;

-- Q2: Doanh thu theo từng tháng năm 2023
SELECT d.month_name, d.month, SUM(f.total_amount) AS monthly_revenue
FROM gold.fact_sales f
JOIN gold.dim_date d ON f.date_key = d.date_key
WHERE d.year = 2023
GROUP BY d.month, d.month_name ORDER BY d.month;

-- Q3: Nhóm tuổi nào có tổng chi tiêu cao nhất?
SELECT c.age_group, SUM(f.total_amount) AS total_spent,
       COUNT(*) AS num_transactions, AVG(f.total_amount) AS avg_spend
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.age_group ORDER BY total_spent DESC;

-- Q4: So sánh hành vi mua sắm giữa Nam và Nữ
SELECT c.gender, p.product_category,
       COUNT(*) AS purchases, SUM(f.total_amount) AS revenue
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY c.gender, p.product_category
ORDER BY c.gender, revenue DESC;