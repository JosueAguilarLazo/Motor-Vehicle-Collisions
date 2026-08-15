# NYC Motor Vehicle Collision Analysis
**MySQL · Window Functions · CTEs · Views · Stored Procedures**

An end-to-end SQL analytics project exploring NYC motor vehicle collision records originally from the NYC Open Data Portal for a course assignment. This repository is an independent and significantly expanded upon version of that work.

---

## Repository Structure

```
nyc-collisions-analysis/
├── README.md
├── data/
│   ├──MVC.xlsx                     # Raw data source with collision records
├── py/
│   ├── 02_data_processing.ipnyb    # Python script that cleans data by standardization and null handling
│   ├── 03_etl.ipynb                # Migrates Clean Data to SQL from python
├── sql/
│   ├── 01_schema.sql               # Creates relational table structures in SQL
│   ├── 04_exploratory_analysis.sql # Executes advanced analytical queries
│   └── 05_views_and_sps.sql        # Creates reusable views and stored procedures

```
---

## Dataset

| Detail | Value |
|---|---|
| Source | NYC Open Data — Motor Vehicle Collisions |
| Rows | ~1 million collision records |
| Date Range | 2012 – 2017 |
| Tables | `collisions`, `vehicles`, `drivers`, `contributing_factors` |
| Database | MySQL 8.0+ |

---

## Key Findings

### Dashboard Preview

<img width="1365" height="767" alt="Dashboard" src="https://github.com/user-attachments/assets/25b70f4a-491e-48d3-bc4f-0eafebbedaa1" />


>  **View the dashboard on Tableau Public**
 https://public.tableau.com/views/MotorVehicleCollisions_17790630612730/Dashboard1?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link

   **Dashboard Power BI Version**
[Download .pbix File] https://github.com/JosueAguilarLazo/Motor-Vehicle-Collisions/blob/main/data/Motor%20Vehicle%20Collisions%20Risk%20Analysis.pbix
---

### 1. Crash Volume Trends

The dataset shows strong year-over-year growth from 2012 through 2016, with annual totals rising from **~24,800 in the beginning of 2012** to nearly **98,200 by the end of 2016** which is nearly a 4 times increase over the course of 5 years. The 3-month rolling average query showcases this trajectory with seasonal dips each winter and peaks consistently found in the summer.


---

### 2. Collisions Based on Time of Day

Evening commute is the most dangerous time of day:

| Hour | Total Crashes | % of All Crashes |
|---|---|---|
| 2 PM (14:00) | 21,433 | 6.9% |
| 3 PM (15:00) | 19,636 | 6.3% |
| **4 PM (16:00)** | **23,542** | **7.5%** |
| **5 PM (17:00)** | **22,849** | **7.3%** |
| 6 PM (18:00) | 19,995 | 6.4% |

 Overnight hours (1–5 AM) are the safest time of day, with each hour contributing only 1–1.3% of daily crashes.

---

### 3. Collisions Based on Day of Week

**Friday** stands out clearly as the highest-crash day, running at **12.1% above the daily crash average**. Weekends are the safest period, with Sunday being the safest day at **18.1% below average**.

---

### 4. Common Contributing Factors in Collisions:

| Rank | Factor | Occurrences | % Share |
|---|---|---|---|
| 1 | Driver Inattention/Distraction | 105,745 | 27.3% |
| 2 | Failure to Yield Right-of-Way | 33,135 | 8.6% |
| 3 | Fatigued/Drowsy | 32,422 | 8.4% |
| 4 | Other Vehicular | 30,161 | 7.8% |
| 5 | Backing Unsafely | 20,424 | 5.3% |


**Driver Inattention/Distraction** alone accounts for more than **1/4** of all specified contributing factors. Further SQL analysis into factor co-occurence reveals that **Driver Inattention/Distraction** is commonly found as the main partner to all other factors. An example of this is it's pairing with **Following Too Closely** over 4000 times.

---

## Stored Procedures example calls

CALL sp_annual_report(2016);          -- Full report and documentation for crash year

CALL sp_compare_years(2016,2015);     -- Two crash years comparison

---

## SQL Techniques Used

- Window functions (`RANK`, `DENSE_RANK`, `ROW_NUMBER`, `LAG`, `AVG OVER`) 
- Recursive-style CTEs and multi-step CTE chains 
- Statistical anomaly detection (z-score via `STDDEV`) and self-joins
- Development of stored procedures with input validation and parameters
- Use of `NULLIF` for safe division throughout 
- Rolling 3 month averages (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`)
- Views for reusability of complex joins and calculations
