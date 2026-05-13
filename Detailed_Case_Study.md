# 🛒 Olist E-Commerce Customer Analytics
### End-to-End Business Intelligence Project | SQL · Python · Power BI

---

## 📌 Project Overview

This project is a full end-to-end business analytics case study on the **Brazilian E-Commerce Public Dataset by Olist** (Kaggle). The goal is not just to describe data — but to diagnose **why** the business behaves the way it does, and deliver **actionable, data-backed recommendations** that a real company could implement.

The analysis is structured in 5 layers, moving from raw data engineering to customer segmentation to executive-ready business recommendations.

---

## 📂 Project Structure

```
olist-ecommerce-analysis/
│
├── layer1_data_prep.sql              # Data exploration, indexes, master table
├── layer2_business_metrics.sql       # 12 business metric queries + RJ/RS deep dive
├── layer3_rfm_segmentation.ipynb     # Python RFM customer segmentation
├── layer4_powerbi_dashboard.pbix     # Interactive Power BI dashboard (coming)
└── README.md                         # You are here
```

---

## 🗃️ Dataset

| Property | Detail |
|---|---|
| Source | [Brazilian E-Commerce Public Dataset by Olist — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) |
| Total Orders | 99,441 |
| Tables | 9 relational tables |
| Time Period | September 2016 – October 2018 |
| Language | Portuguese (categories translated to English via join) |

### Schema Overview

```
orders (spine)
├── order_items      → product_id, seller_id, price, freight
├── order_payments   → payment_type, payment_value
├── order_reviews    → review_score (1-5)
├── customers        → city, state
├── products         → category (Portuguese)
│   └── category_translation → category (English)
└── sellers          → city, state
```

`orders` is the central spine. Every analysis flows through `order_id` or `customer_id`.

---

## ⚙️ Layer 1 — Data Preparation & Master Table

### Objective
Build a single, clean, analysis-ready table from 9 raw CSVs.

### Key Steps

**1. Data Quality Checks**
- 99,441 total orders spanning Sep 2016 – Oct 2018
- **97.02% delivered** — strong fulfillment health
- 2,965 orders (3%) have no delivery date — all correspond to non-delivered statuses (cancelled, unavailable). Consistent and expected.
- Sep/Oct 2018 flagged as incomplete (only 4 orders in October with NULL revenue) — excluded from all trend analysis.

**2. Performance Optimization**
All ID columns imported as `TEXT` type by pandas. Added 50-char prefix indexes on all join keys to enable fast queries on 100k+ rows. Without this, queries timed out and disconnected.

```sql
ALTER TABLE orders ADD INDEX idx_order_id (order_id(50));
-- repeated for all 7 tables
```

**3. Master Table — `master_orders`**

Built a physical MySQL table (not a view) by joining all 9 tables into one flat structure. Views re-run all JOINs on every query, causing 30+ second timeouts. A physical table stores data once and queries run instantly.

**Key design decisions:**
| Decision | Reason |
|---|---|
| `order_items` pre-aggregated by order_id | Prevents row multiplication (1 order × 6 items = 6 duplicate rows) |
| `order_payments` pre-aggregated by order_id | Handles installment payments (multiple rows per order) |
| `COALESCE(freight_value, 0)` | Replaces NULL freight with 0 so revenue math doesn't break |
| `review_score` NULLs → 3 (neutral) | Customers who didn't review treated as neither happy nor unhappy |
| `DATEDIFF` with NULL guard | Delivery date before purchase date = impossible = NULL |
| 5 status flag columns | `is_delivered`, `is_shipped` etc. for fast filtering |
| NULL `seller_state` → 'Unknown' | Makes ghost sellers identifiable in GROUP BY |

**Result:** `master_orders` — 99,992 rows, one per order, all analysis runs on this table.

---

## 📊 Layer 2 — Business Metrics & Root Cause Analysis

### Objective
Answer 12 business questions using `master_orders`. Move beyond "what happened" to "why it happened."

---

### Metric 1 — Revenue by Product Category

**Top 10 categories by revenue:**

| Category | Revenue (R$) | Orders | Avg Review |
|---|---|---|---|
| health_beauty | 1,444,105 | 7,974 | 4.18 |
| watches_gifts | 1,306,097 | 5,600 | 4.06 |
| bed_bath_table | 1,261,345 | 9,333 | 3.97 |
| sports_leisure | 1,165,411 | 7,688 | 4.16 |
| computers_accessories | 1,069,003 | 6,668 | 4.02 |
| furniture_decor | 909,968 | 6,342 | 4.01 |
| housewares | 781,348 | 5,822 | 4.15 |
| cool_stuff | 723,656 | 3,607 | 4.17 |
| auto | 687,338 | 3,880 | 4.09 |
| garden_tools | 581,959 | 3,465 | 4.15 |

> **Finding:** `office_furniture` flagged for investigation — lowest review score (3.62) among top revenue categories despite R$342k in sales.

**Office Furniture Deep Dive:**
- Avg delivery: **21 days** vs overall average of **12.5 days** (68% slower)
- Root cause: logistics, not product quality. Almost all sellers based in SP state shipping long distances.

---

### Metric 2 — Revenue by State

| State | Revenue (R$) | Orders | Avg Review | Avg Delivery Days |
|---|---|---|---|---|
| SP | 5,799,284 | 40,501 | 4.24 | 8.70 |
| RJ | 2,063,594 | 12,350 | 3.95 | 15.25 |
| MG | 1,826,487 | 11,354 | 4.19 | 11.95 |
| RS | 865,877 | 5,345 | 4.18 | 15.27 |
| PR | 785,095 | 4,923 | 4.23 | 11.95 |
| BA | 593,408 | 3,256 | 3.92 | 19.30 |

> **Finding:** SP dominates because most sellers are located there — short last-mile = fast delivery = better reviews. BA is the worst performer with 19.3 day average delivery.

---

### Metric 3 — Delivery Speed vs Review Score

The strongest and most provable finding in the entire project:

| Delivery Bucket | Avg Review | Orders |
|---|---|---|
| 1–7 days | **4.41** | 30,694 |
| 8–14 days | 4.29 | 37,979 |
| 15–21 days | 4.11 | 16,170 |
| 22–28 days | 3.61 | 6,366 |
| 29+ days | **2.38** | 5,261 |

> **Finding:** Perfect inverse correlation. Every bucket drops consistently. Orders taking 29+ days average a **46% drop in satisfaction** compared to 1–7 day deliveries. 5,261 orders are in the danger zone.

---

### Metric 4 — Monthly Revenue Trend

Revenue grew **8x** from R$138k/month (Jan 2017) to R$1.16M/month (Apr 2018). Growth rate slowed in 2018 but absolute revenue remained stable above R$1M/month — market maturation, not decline.

> **Analytical decision:** Sep/Oct 2018 excluded from trend analysis — only 4 orders in October with NULL revenue confirms incomplete data capture.

---

### Metric 5 — Seller Performance

- SP sellers handle **70% of all volume** (69,975 orders)
- 775 orders with unknown seller state — avg review score of **1.76** — data quality issue
- AM (Amazonas) averages **48 days delivery** — geographic isolation in remote jungle region

---

### Advanced Investigation — The RJ vs RS Anomaly

**The puzzle:** RJ and RS have identical average delivery times (~15 days) but very different satisfaction scores (3.95 vs 4.18). Why?

Three hypotheses tested and eliminated:

**Hypothesis 1 — Delivery Distribution (Partially Confirmed)**
RJ has 13.96% of orders in the 29+ day bucket vs RS's 9.73%. But more importantly, RJ penalizes the **same delay far more aggressively** than RS:
- 22–28 days in RS → 4.04 stars
- 22–28 days in RJ → 3.45 stars
- 29+ days in RS → 2.43 stars
- 29+ days in RJ → **1.86 stars**

**Hypothesis 2 — Freight Cost (Disproved)**
RS has a higher freight-to-price ratio (17.99%) than RJ (16.67%). Cost is not the culprit.

**Hypothesis 3 — Product Mix (Disproved)**
Even comparing the **exact same categories**, RJ rates consistently lower. For `sports_leisure`: RJ gets it in 15.5 days → 3.87 stars. RS gets it in 14.6 days → 4.28 stars.

> **Conclusion:** After eliminating delivery time, freight cost, and product mix, the data points to a **Last-Mile Quality Defect** localized to Rio de Janeiro — likely related to final-mile courier partner quality (damaged packages, missed deliveries, poor driver professionalism). This is an unmeasured operational variable not present in this dataset.

---

## 🐍 Layer 3 — RFM Customer Segmentation

### What is RFM?

RFM is a customer segmentation framework used by every serious e-commerce company. Each customer gets scored 1–4 on three dimensions:

| Dimension | Question | Scoring |
|---|---|---|
| **Recency** | How recently did they buy? | Fewer days = Higher score |
| **Frequency** | How many times did they buy? | More orders = Higher score |
| **Monetary** | How much did they spend total? | More spend = Higher score |

### Implementation

Built in Python (pandas) connected to MySQL via SQLAlchemy. Pulled `master_orders`, calculated R/F/M scores using `groupby()` + `qcut()`, assigned segments, and pushed the final table back to MySQL as `customer_rfm_segments`.

### Results

| Segment | Customers | Description |
|---|---|---|
| Recent New Customers | 48,118 | Bought recently, only once |
| Lost/One-Time Low Spenders | 47,835 | Bought long ago, never returned |
| At Risk | 343 | Were loyal, going quiet |
| Loyal Customers | 163 | Frequent buyers |
| Champions | 19 | Recent, frequent, high spend |

> **Critical Finding:** Over **99% of Olist's entire customer base has purchased exactly once.** With only 19 Champions from nearly 100k orders, Olist is operating as a pure acquisition machine — constantly paying to find new customers because existing ones never return. This is a **customer retention crisis** hiding behind healthy revenue numbers.

---

## 💡 Business Recommendations

### Recommendation 1 — Fix Last-Mile Logistics in Key States
**Data:** BA averages 19.3 days delivery (54% above average). 5,261 orders take 29+ days and average 2.38 stars — a 46% satisfaction collapse.

**Action:** Audit and replace final-mile courier partners in BA and RJ. Build regional fulfillment centers outside SP. Priority: reduce the 29+ day bucket to under 14 days. Every day reduction in delivery time correlates with measurable review score improvement.

---

### Recommendation 2 — Office Furniture: Fix Logistics, Don't Cut Inventory
**Data:** Office furniture generates R$342k revenue but has the lowest review score (3.62) in the top 10 categories. Average delivery is 21 days vs 12.5 overall (68% slower).

**Action:** Do not reduce office furniture inventory — the product quality is not the issue. Require office furniture sellers to maintain regional stock outside SP. Partner with furniture-specialist logistics providers who handle large-item last-mile delivery.

---

### Recommendation 3 — Reduce the 29+ Day Order Bucket
**Data:** 5,261 orders (5.4%) take 29+ days and average 2.38 stars. These are the customers most likely to never return.

**Action:** Proactively identify orders approaching 20+ days in transit. Trigger automated customer communication with compensation vouchers before the customer feels abandoned. Prevention is cheaper than win-back.

---

### Recommendation 4 — Build a Second Purchase Pipeline
**Data:** 48,118 "Recent New Customers" completed one successful order and went silent. Only 19 Champions exist in the entire dataset.

**Action:** Shift marketing budget from pure acquisition to retention. If a customer receives delivery in under 14 days (proven satisfaction threshold), automatically trigger a 15% discount code valid for 30 days. Converting even 5% of single-purchase users to two-time buyers would generate high-margin revenue without the cost of new customer acquisition.

---

## 🔬 Analytical Decisions & Limitations

### Decisions Made
- All analysis filtered to `order_status = 'delivered'` only — cancelled/processing orders excluded to ensure metrics reflect real completed transactions
- Sep/Oct 2018 excluded from trend analysis — incomplete month data confirmed by only 4 orders in October with NULL revenue
- Revenue defined as `price + freight_value` — not `payment_value` (a financial reconciliation metric not linked to product categories)
- `review_score` NULLs defaulted to 3 (neutral) — customers who chose not to review treated as neither satisfied nor dissatisfied

### Limitations
- The RJ anomaly could not be fully explained with available data — last-mile courier quality, package damage rates, and driver behavior are unmeasured variables
- No customer demographic data (age, gender, income) available
- Text reviews in Portuguese — not analyzed (most are NULL anyway)
- 775 orders with unknown seller state — possible data pipeline issue at source
- Dataset ends October 2018 — long-term trend conclusions require more recent data

---

## 🛠️ Technologies Used

| Tool | Purpose |
|---|---|
| MySQL Workbench | SQL querying and master table creation |
| Python (pandas) | RFM segmentation and data pipeline |
| SQLAlchemy + PyMySQL | Jupyter ↔ MySQL connection bridge |
| Jupyter Notebook | Python analysis environment |
| Power BI | Interactive dashboard (Layer 4 — coming) |

---

## 👤 Author

**AAKASH SAINI[BTech Student] — Business Analytics Project**
Dataset: [Brazilian E-Commerce by Olist on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
