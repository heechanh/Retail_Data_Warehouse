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
