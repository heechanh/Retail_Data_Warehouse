# Hướng Dẫn Xây Dựng Data Warehouse - Retail Sales Dataset

> **Tác giả:** Dự án học tập Data Engineering  
> **Dataset:** Retail Sales Dataset (1.000 giao dịch, 2023–2024)  
> **Công nghệ:** SQL Server Express + SSMS  
> **Kiến trúc:** Medallion Architecture (Bronze → Silver → Gold)

---

## Mục Lục

1. [Tổng quan dự án](#1-tổng-quan-dự-án)
2. [Phân tích yêu cầu](#2-phân-tích-yêu-cầu)
3. [Thiết kế kiến trúc](#3-thiết-kế-kiến-trúc)
4. [Khởi tạo dự án](#4-khởi-tạo-dự-án)
5. [Xây dựng lớp Bronze](#5-xây-dựng-lớp-bronze)
6. [Xây dựng lớp Silver](#6-xây-dựng-lớp-silver)
7. [Xây dựng lớp Gold](#7-xây-dựng-lớp-gold)
8. [Tài liệu hóa & Data Catalog](#8-tài-liệu-hóa--data-catalog)

---

## 1. Tổng Quan Dự Án

### 1.1. Giới thiệu Dataset

File `retail_sales_dataset.csv` chứa **1.000 giao dịch bán lẻ** với các trường sau:

| Cột gốc | Kiểu dữ liệu | Mô tả | Ví dụ |
|---|---|---|---|
| `Transaction ID` | INT | Mã giao dịch duy nhất | 1, 2, 3... |
| `Date` | STRING | Ngày giao dịch (YYYY-MM-DD) | 2023-11-24 |
| `Customer ID` | STRING | Mã khách hàng | CUST001 |
| `Gender` | STRING | Giới tính khách hàng | Male, Female |
| `Age` | INT | Tuổi khách hàng (18–64) | 34 |
| `Product Category` | STRING | Danh mục sản phẩm | Beauty, Clothing, Electronics |
| `Quantity` | INT | Số lượng mua (1–4) | 3 |
| `Price per Unit` | INT | Giá mỗi sản phẩm (25–500) | 50 |
| `Total Amount` | INT | Tổng tiền | 150 |

### 1.2. Tại sao cần Data Warehouse?

Với dữ liệu bán lẻ này, nếu doanh nghiệp muốn trả lời các câu hỏi như:
- *"Danh mục nào mang lại doanh thu cao nhất theo từng quý?"*
- *"Nhóm tuổi nào mua sắm nhiều nhất?"*
- *"Xu hướng doanh số thay đổi như thế nào từ 2023 đến 2024?"*

...thì cần một Data Warehouse được tổ chức tốt thay vì truy vấn trực tiếp file CSV thô.

**Data Warehouse** đóng vai trò là *"Single Point of Truth"* (Điểm tin cậy duy nhất): dữ liệu đã được làm sạch, chuẩn hóa và sẵn sàng cho phân tích, đảm bảo toàn bộ đội ngũ sử dụng cùng một nguồn dữ liệu nhất quán.

---

## 2. Phân Tích Yêu Cầu

> **Lý do quan trọng:** Đây là bước đầu tiên và quan trọng nhất. Hơn 50% dự án Data Warehouse thất bại do thiếu giai đoạn phân tích yêu cầu rõ ràng.

### 2.1. Mục tiêu dự án

- Xây dựng Data Warehouse từ file CSV bán lẻ bằng SQL Server
- Hỗ trợ báo cáo phân tích doanh số, hành vi khách hàng và danh mục sản phẩm
- Cung cấp nền tảng dữ liệu cho Power BI / Tableau / SQL queries

### 2.2. Nguồn dữ liệu

- **Hệ thống nguồn:** Một file CSV duy nhất (mô phỏng hệ thống POS/CRM đơn giản)
- **Tên file:** `retail_sales_dataset.csv`
- **Phương thức nạp:** BULK INSERT (Full Load)
- **Tần suất nạp:** Thủ công (có thể mở rộng sang batch định kỳ)

### 2.3. Yêu cầu chất lượng dữ liệu

Sau khi khám phá dữ liệu, ta xác định các điểm cần xử lý ở lớp Silver:

| Vấn đề | Cột liên quan | Cách xử lý |
|---|---|---|
| Cột `Date` là kiểu STRING | `Date` | Chuyển sang kiểu DATE |
| Tên cột có khoảng trắng | Tất cả | Đổi tên theo snake_case |
| Kiểm tra logic doanh số | `Total Amount` = `Quantity × Price per Unit` | Validate & tính lại nếu sai |
| Tách thông tin khách hàng | `Gender`, `Age` | Đưa vào Dimension riêng |

### 2.4. Phạm vi & giới hạn

- Chỉ tập trung vào bộ dữ liệu hiện tại, không yêu cầu historization
- Không cần lưu lịch sử thay đổi giá (Slowly Changing Dimensions)
- Mô hình Gold Layer sử dụng Views (không nạp vật lý)

---

## 3. Thiết Kế Kiến Trúc

### 3.1. Lựa chọn kiến trúc: Medallion Architecture

Dự án sử dụng **Medallion Architecture** vì tính đơn giản, dễ triển khai và phù hợp với người học Data Engineering.

```
[SOURCE]              [DATA WAREHOUSE]                    [CONSUME]
                  ┌──────────────────────────┐
retail_sales  ──► │  BRONZE  │ SILVER │ GOLD │ ──►  Power BI
    .csv           │  (Thô)   │(Sạch)  │(KD) │      Tableau
                  └──────────────────────────┘      SQL Queries
```

### 3.2. Chi tiết từng lớp

| Đặc tính | Bronze (Đồng) | Silver (Bạc) | Gold (Vàng) |
|---|---|---|---|
| **Mục tiêu** | Lưu dữ liệu thô, nguyên bản | Dữ liệu đã làm sạch, chuẩn hóa | Dữ liệu sẵn sàng cho kinh doanh |
| **Loại đối tượng** | Table | Table | View (bảng ảo) |
| **Phương thức nạp** | TRUNCATE → BULK INSERT | TRUNCATE → INSERT (từ Bronze) | Không nạp, truy vấn trực tiếp |
| **Biến đổi** | Không chỉnh sửa gì | Làm sạch, đổi tên cột, chuyển kiểu | Logic kinh doanh, Star Schema |
| **Người dùng** | Data Engineer | Data Engineer, Data Analyst | Analyst, Business User |

### 3.3. Mô hình dữ liệu Gold Layer (Star Schema)

```
                    ┌─────────────────┐
                    │  dim_customers  │
                    │─────────────────│
                    │ customer_key PK │
                    │ customer_id     │
                    │ gender          │
                    │ age             │
                    │ age_group       │
                    └────────┬────────┘
                             │ 1
                             │
┌──────────────────┐    ┌────┴───────────────┐    ┌──────────────────┐
│  dim_products    │    │    fact_sales       │    │   dim_date       │
│──────────────────│    │────────────────────│    │──────────────────│
│ product_key   PK │◄───┤ product_key     FK │    │ date_key      PK │
│ product_category │    │ customer_key    FK ├───►│ full_date        │
└──────────────────┘    │ date_key        FK │    │ year             │
                    ┌───┤ transaction_id     │    │ quarter          │
                    │   │ quantity           │    │ month            │
                    │   │ price_per_unit     │    │ month_name       │
                    │   │ total_amount       │    │ day_of_week      │
                    │   └────────────────────┘    └──────────────────┘
                    │              ▲ N
                    └─── nhiều giao dịch có thể
                         cùng khách hàng/sản phẩm/ngày
```

---

## 4. Khởi Tạo Dự Án

### 4.1. Chuẩn bị công cụ

Cài đặt các công cụ sau trước khi bắt đầu:
- **SQL Server Express** – Máy chủ cơ sở dữ liệu (miễn phí)
- **SQL Server Management Studio (SSMS)** – Giao diện viết và chạy SQL
- **Git + GitHub** – Quản lý mã nguồn, xây dựng portfolio

### 4.2. Quy tắc đặt tên (Naming Conventions)

> Thiết lập sớm để tránh hỗn loạn khi mở rộng dự án.

**Định dạng chung:** `snake_case` – tất cả chữ thường, ngăn cách bằng dấu gạch dưới

| Đối tượng | Quy tắc | Ví dụ |
|---|---|---|
| Bảng Bronze | `bronze.<source>_<entity>` | `bronze.retail_sales` |
| Bảng Silver | `silver.<source>_<entity>` | `silver.retail_sales` |
| Dimension (Gold) | `gold.dim_<entity>` | `gold.dim_customers` |
| Fact Table (Gold) | `gold.fact_<entity>` | `gold.fact_sales` |
| Surrogate Key | `<entity>_key` | `customer_key`, `product_key` |
| Metadata columns | `dw_<name>` | `dw_create_date` |
| Stored Procedure | `load_<layer>` | `load_bronze`, `load_silver` |

### 4.3. Cấu trúc thư mục Git

```
retail-data-warehouse/
├── README.md
├── datasets/
│   └── retail_sales_dataset.csv
├── docs/
│   ├── architecture_diagram.png
│   ├── data_flow.png
│   └── data_catalog.md
├── scripts/
│   ├── init_database.sql
│   ├── bronze/
│   │   ├── ddl_bronze.sql
│   │   └── proc_load_bronze.sql
│   ├── silver/
│   │   ├── ddl_silver.sql
│   │   └── proc_load_silver.sql
│   └── gold/
│       └── ddl_gold_views.sql
└── tests/
    └── quality_checks.sql
```

### 4.4. Tạo Database & Schemas

```sql
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
```

> **Giải thích lệnh `GO`:** Trong SQL Server, `GO` là lệnh báo hiệu SSMS thực thi tất cả câu lệnh trước đó như một batch. Cần thiết giữa `CREATE DATABASE` và `USE`, vì SQL Server phải tạo xong database trước khi chuyển sang dùng nó.

---

## 5. Xây Dựng Lớp Bronze

> **Nguyên tắc vàng của lớp Bronze:** Không chỉnh sửa bất kỳ dữ liệu nào. Copy nguyên trạng từ nguồn vào.

### 5.1. Tạo bảng DDL cho Bronze

```sql
-- ============================================================
-- Script: ddl_bronze.sql
-- Mục đích: Tạo bảng thô lớp Bronze cho retail_sales_dataset
-- Lớp Bronze giữ nguyên cấu trúc 1:1 so với file CSV nguồn
-- ============================================================

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
```

> **Tại sao `date` là `NVARCHAR` ở Bronze?** Lớp Bronze lưu nguyên trạng dữ liệu từ CSV. File CSV lưu ngày dạng chuỗi text `"2023-11-24"`, vậy ta giữ nguyên kiểu chuỗi ở đây. Việc chuyển sang kiểu `DATE` thực sự sẽ được thực hiện ở lớp Silver – nơi có trách nhiệm làm sạch và chuẩn hóa.

### 5.2. Stored Procedure nạp Bronze

```sql
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
        FROM 'C:\DataWarehouse\datasets\retail_sales_dataset.csv'  -- Thay đường dẫn thực tế
        WITH (
            FIRSTROW        = 2,            -- Bỏ qua dòng tiêu đề (header)
            FIELDTERMINATOR = ',',          -- Dấu phẩy ngăn cách các cột
            ROWTERMINATOR   = '\n',         -- Xuống dòng ngăn cách các bản ghi
            TABLOCK                         -- Khóa bảng để tăng tốc độ nạp
        );

        @end_time = GETDATE();
        @duration = DATEDIFF(SECOND, @start_time, @end_time);

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
```

> **Giải thích các thành phần trong Stored Procedure:**
> - **`TRUNCATE TABLE`:** Xóa toàn bộ dữ liệu cũ nhanh hơn `DELETE` (không ghi log từng dòng). Đây là phần của chiến lược **Full Load** – mỗi lần chạy là nạp lại toàn bộ.
> - **`FIRSTROW = 2`:** Bỏ qua dòng đầu tiên vì đó là header (`Transaction ID, Date, Customer ID,...`).
> - **`BEGIN TRY...CATCH`:** Bắt lỗi SQL thay vì để ứng dụng bị crash đột ngột, in ra thông tin lỗi chi tiết để debug.
> - **`DATEDIFF`:** Đo thời gian thực thi để theo dõi hiệu suất – cực kỳ hữu ích khi dữ liệu lớn hơn.

### 5.3. Kiểm tra Bronze

```sql
-- Xem nhanh dữ liệu đã nạp
SELECT TOP 10 * FROM bronze.retail_sales;

-- Kiểm tra tổng số dòng (phải = 1000)
SELECT COUNT(*) AS total_rows FROM bronze.retail_sales;
```

---

## 6. Xây Dựng Lớp Silver

> **Nguyên tắc của lớp Silver:** Làm sạch và chuẩn hóa – nhưng không áp dụng logic kinh doanh phức tạp. Đó là việc của lớp Gold.

### 6.1. Khám phá dữ liệu trước khi làm sạch

```sql
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
```

### 6.2. Tạo bảng DDL cho Silver

```sql
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
```

### 6.3. Stored Procedure nạp Silver

```sql
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
```

> **Giải thích các kỹ thuật làm sạch:**
> - **`TRY_CONVERT(DATE, date, 23)`:** Chuyển string `"2023-11-24"` sang kiểu DATE. `TRY_CONVERT` an toàn hơn `CONVERT` vì nếu giá trị không hợp lệ, nó trả về `NULL` thay vì gây lỗi toàn bộ câu lệnh.
> - **`TRIM()`:** Xóa khoảng trắng đầu và cuối chuỗi – lỗi ẩn rất phổ biến trong dữ liệu thực tế.
> - **Kiểm tra logic doanh số:** Rule `total_amount = quantity × price_per_unit` là quy tắc kinh doanh cơ bản nhất. Nếu không khớp, ta tính lại để đảm bảo độ chính xác.

### 6.4. Kiểm tra Silver

```sql
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
```

---

## 7. Xây Dựng Lớp Gold

> **Nguyên tắc của lớp Gold:** Áp dụng logic kinh doanh, tích hợp dữ liệu thành Star Schema phục vụ báo cáo. Sử dụng **Views** thay vì bảng vật lý để đảm bảo linh hoạt.

### 7.1. Tại sao dùng Views ở lớp Gold?

- **Không tốn bộ nhớ lưu trữ thêm** – Views là câu truy vấn ảo, chạy trực tiếp từ Silver
- **Tự động cập nhật** – Khi Silver có dữ liệu mới, Gold phản chiếu ngay lập tức
- **Linh hoạt** – Dễ thay đổi logic mà không cần ETL lại

### 7.2. Dimension: dim_customers

```sql
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
```

> **Surrogate Key là gì?** Thay vì dùng `customer_id` gốc như `"CUST001"` làm khóa liên kết (vì ID từ hệ thống nguồn có thể thay đổi định dạng theo thời gian), ta tạo một khóa số tự tăng nội bộ (`customer_key = 1, 2, 3...`). Điều này giúp DWH kiểm soát độc lập với hệ thống nguồn.

### 7.3. Dimension: dim_products

```sql
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
```

### 7.4. Dimension: dim_date

```sql
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
```

### 7.5. Fact Table: fact_sales

```sql
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
```

> **Tại sao LEFT JOIN?** Nếu dùng INNER JOIN, bất kỳ giao dịch nào không khớp được với Dimension sẽ bị mất hoàn toàn. LEFT JOIN đảm bảo **tất cả giao dịch đều được giữ lại** trong Fact Table, dù giá trị dimension có thể là NULL – an toàn hơn cho báo cáo.

### 7.6. Kiểm tra Gold Layer

```sql
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
```

---

## 8. Tài Liệu Hóa & Data Catalog

### 8.1. Data Flow (Dòng chảy dữ liệu)

```
CSV File
    │
    │  BULK INSERT
    ▼
bronze.retail_sales          ← Dữ liệu thô, giữ nguyên cấu trúc CSV
    │
    │  TRUNCATE → INSERT (làm sạch)
    ▼
silver.retail_sales          ← Dữ liệu sạch, đúng kiểu, chuẩn hóa
    │
    │  Views (truy vấn trực tiếp, không nạp vật lý)
    ▼
gold.dim_customers           ← Dimension: Khách hàng
gold.dim_products            ← Dimension: Sản phẩm
gold.dim_date                ← Dimension: Thời gian
gold.fact_sales              ← Fact: Giao dịch bán hàng
    │
    │  Kết nối BI Tools
    ▼
Power BI / Tableau / SQL Queries
```

### 8.2. Data Catalog

#### Bảng: `gold.dim_customers`

| Cột | Kiểu | Mô tả | Ví dụ |
|---|---|---|---|
| `customer_key` | INT | Surrogate key nội bộ DWH | 1, 2, 3... |
| `customer_id` | NVARCHAR | Mã khách hàng gốc từ nguồn | CUST001 |
| `gender` | NVARCHAR | Giới tính | Male, Female |
| `age` | INT | Tuổi tại thời điểm giao dịch gần nhất | 34 |
| `age_group` | NVARCHAR | Nhóm tuổi phân tích | 26–35 |

#### Bảng: `gold.dim_products`

| Cột | Kiểu | Mô tả | Ví dụ |
|---|---|---|---|
| `product_key` | INT | Surrogate key nội bộ DWH | 1, 2, 3 |
| `product_category` | NVARCHAR | Danh mục sản phẩm | Beauty, Clothing, Electronics |

#### Bảng: `gold.dim_date`

| Cột | Kiểu | Mô tả | Ví dụ |
|---|---|---|---|
| `date_key` | INT | Surrogate key nội bộ DWH | 1, 2... |
| `full_date` | DATE | Ngày đầy đủ | 2023-01-01 |
| `year` | INT | Năm | 2023 |
| `quarter` | INT | Quý (1–4) | 1 |
| `quarter_label` | NVARCHAR | Nhãn quý | Q1-2023 |
| `month` | INT | Tháng (1–12) | 3 |
| `month_name` | NVARCHAR | Tên tháng | March |
| `day` | INT | Ngày trong tháng | 15 |
| `day_of_week` | NVARCHAR | Tên ngày trong tuần | Monday |

#### Bảng: `gold.fact_sales`

| Cột | Kiểu | Mô tả | Ví dụ |
|---|---|---|---|
| `transaction_id` | INT | Mã giao dịch (từ nguồn) | 1 |
| `customer_key` | INT | FK → dim_customers | 5 |
| `product_key` | INT | FK → dim_products | 2 |
| `date_key` | INT | FK → dim_date | 128 |
| `quantity` | INT | Số lượng mua | 3 |
| `price_per_unit` | INT | Giá mỗi sản phẩm (VND/USD) | 50 |
| `total_amount` | INT | Tổng tiền thanh toán | 150 |
| `calculated_revenue` | INT | Doanh thu tính lại (kiểm soát) | 150 |

### 8.3. Quy trình chạy toàn bộ pipeline

```sql
-- Chạy lần lượt theo thứ tự
EXEC bronze.load_bronze;   -- Bước 1: Nạp dữ liệu thô
EXEC silver.load_silver;   -- Bước 2: Làm sạch dữ liệu

-- Lớp Gold là Views, tự động cập nhật
-- Không cần chạy thêm gì
SELECT TOP 5 * FROM gold.fact_sales;  -- Bước 3: Verify Gold Layer
```

---

## Phụ Lục: Câu Hỏi Phân Tích Mẫu

Sau khi hoàn thành Data Warehouse, đây là các câu SQL bạn có thể chạy trực tiếp để trả lời các câu hỏi kinh doanh:

```sql
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
```

---

*Tài liệu này được xây dựng dựa trên phương pháp luận Medallion Architecture và các best practices của Data Engineering, áp dụng trực tiếp cho Retail Sales Dataset.*
