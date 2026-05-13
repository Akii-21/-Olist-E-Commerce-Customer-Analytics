# 🛒 Olist E-Commerce Customer Analytics & Segmentation

**Overview**
This project is an end-to-end data engineering and business analytics case study on the Olist Brazilian E-Commerce dataset (99,441 orders). The analysis moves from raw data pipeline optimization in MySQL to advanced customer segmentation using Python (pandas), uncovering critical operational bottlenecks and customer retention failures.

**Tools Used:** MySQL, Python (pandas, SQLAlchemy), Advanced CTEs & Window Functions

**Key Insights**
* **The "Last-Mile" Logistics Failure:** Customers in Rio de Janeiro (RJ) rated their experience significantly lower than those in Rio Grande do Sul (RS) despite identical average delivery times. Hypothesis testing ruled out product mix and freight cost disparities, isolating the root cause to regional last-mile courier quality.
* **The 99% Churn Crisis:** Advanced RFM (Recency, Frequency, Monetary) segmentation revealed that over 99% of Olist's customer base are one-time buyers. The business operates entirely on acquisition rather than lifetime value, prompting a data-backed recommendation for an automated "Second Purchase" marketing funnel.
* **Logistics vs. Satisfaction Correlation:** The data proved a direct, quantifiable collapse in customer satisfaction when deliveries exceed 21 days, dropping average review scores by 46%.

**Technical Skills Demonstrated**
* **Data Engineering & Optimization:** Consolidated 9 relational tables into a single flat `master_orders` fact table, reducing query execution time from 30+ seconds to under 5 seconds by applying optimized 50-character prefix indexes.
* **Hypothesis Testing in SQL:** Utilized CTEs and Window Functions (`ROW_NUMBER() OVER(PARTITION BY)`) to conduct multivariate testing, comparing regional product mixes side-by-side to eliminate false variables.
* **Automated Python Pipelines:** Built a closed-loop RFM segmentation engine using `pandas` `qcut` logic, utilizing `SQLAlchemy` to automatically ingest and write the segmented dataframe back into the MySQL database for BI tool integration.

**Project Structure**
* **Layer 1: Data Preparation:** Quality checks, indexing, and master table architecture.
* **Layer 2: Business Metrics & Root Cause Analysis:** Geographic revenue, delivery speed correlation, and regional anomaly investigation.
* **Layer 3: Customer Segmentation (RFM):** Python-driven behavioral scoring and retention strategy.



[for detailed case study click this ](Detailed_Case_Study.md)
