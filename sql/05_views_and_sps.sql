-- =============================================================
-- NYC Motor Vehicle Collision Views and Stored Procedures
-- =============================================================


-- =============================================================
-- VIEWS
-- =============================================================
-- Creates a View for a time-series analysis of monthly crash volumes
CREATE OR REPLACE VIEW vw_monthly_summary AS
WITH monthly AS (
	-- Aggregates data into groups based on years and months
    SELECT
        crash_year,
        crash_month,
        COUNT(DISTINCT collision_id) AS monthly_crashes
    FROM collisions
    GROUP BY crash_year, crash_month
)
SELECT
    crash_year,
    crash_month,
    -- Creats a sortable string and cleaner labeling 
    CONCAT(crash_year, '-', LPAD(crash_month, 2, '0')) AS year_and_month,
    monthly_crashes,
    -- Analyzes changed based on a 3 month window
    ROUND(AVG(monthly_crashes) OVER (
        ORDER BY crash_year, crash_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 1) AS rolling_3mo_avg,
    -- Total monthly crashes compared to previous month
    monthly_crashes
        - LAG(monthly_crashes, 1)
          OVER (ORDER BY crash_year, crash_month) AS mom_change,
    -- Compares percentage of monthly change
    ROUND(
        (monthly_crashes
            - LAG(monthly_crashes, 1)
              OVER (ORDER BY crash_year, crash_month))
        * 100.0
        / NULLIF(
            LAG(monthly_crashes, 1)
            OVER (ORDER BY crash_year, crash_month), 0
        ), 1) AS mom_change_pct
FROM monthly;


-- Calls view Above
SELECT * FROM vw_monthly_summary;



-- Aggregates crash volume for each hour and day for peak zone identification
CREATE OR REPLACE VIEW vw_hourly_heatmap AS
WITH raw AS (
	-- Groups unique collisions by the day of the week and hour
    SELECT
        crash_day_of_week,
        crash_hour,
        COUNT(DISTINCT collision_id) AS crashes
    FROM collisions
    GROUP BY crash_day_of_week, crash_hour
)
SELECT
    CASE crash_day_of_week
        WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday'
        WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
    END AS day_of_week,
    crash_day_of_week,
    crash_hour,
    crashes,
    -- Normalizes data so the highest volume is equal to 100. It compares every other day and hour to this value
    ROUND(
        crashes * 100.0 / MAX(crashes) OVER()
    , 1) AS intensity_score
FROM raw;

-- Simple view call
SELECT * FROM vw_hourly_heatmap;



-- Identifies the top 5 primary causes for collisions each year
CREATE OR REPLACE VIEW vw_top_factors_by_year AS
WITH ranked AS (
	-- Ranks occurences for each year
    SELECT
        c.crash_year,
        cf.factor_description,
        COUNT(*) AS occurrences,
        RANK() OVER (
            PARTITION BY c.crash_year
            ORDER BY COUNT(*) DESC
        ) AS factor_rank
    FROM contributing_factors cf
    JOIN collisions c USING (collision_id)
    -- Excludes columes that could be unspecified for quality
    WHERE cf.factor_description NOT LIKE '%nspecified%'
    GROUP BY c.crash_year, cf.factor_description
)
SELECT
    crash_year,
    factor_rank,
    factor_description,
    occurrences,
    -- Calculates the percentage each factor in the top 5 represents 
    ROUND(occurrences * 100.0 / SUM(occurrences) OVER(
        PARTITION BY crash_year
    ), 2) AS pct_of_year
FROM ranked
WHERE factor_rank <= 5;

-- Simple select to run view above
SELECT * FROM vw_top_factors_by_year;



-- Year-over-Year dashboard showcasing essential information
CREATE OR REPLACE VIEW vw_yoy_dashboard AS
WITH
base AS (
	-- Foundation for metrics that will be used in the rest of the query
    SELECT
        c.crash_year,
        c.crash_hour,
        COUNT(DISTINCT c.collision_id)  AS crashes,
        COUNT(DISTINCT v.vehicle_id)    AS vehicles_involved
    FROM collisions c
    LEFT JOIN vehicles v USING (collision_id)
    GROUP BY c.crash_year, c.crash_hour
),
top_factors AS (
	-- Ranks factors to isolate the leading contributing factor each year
    SELECT
        c.crash_year,
        cf.factor_description,
        COUNT(*) AS factor_count,
        ROW_NUMBER() OVER(
            PARTITION BY c.crash_year
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM contributing_factors cf
    JOIN collisions c USING (collision_id)
    WHERE cf.factor_description NOT LIKE '%nspecified%'
    GROUP BY c.crash_year, cf.factor_description
),

unlicensed_rate AS (
	-- Identifies unlicensed driver involvment for comparison
    SELECT
        c.crash_year,
        ROUND(
            SUM(CASE WHEN d.license_status = "Unlicensed" THEN 1 ELSE 0 END)
            * 100.0 / NULLIF(COUNT(d.driver_id), 0),
        2) AS unlicensed_pct
    FROM drivers d
    JOIN vehicles v  USING (vehicle_id)
    JOIN collisions c USING (collision_id)
    GROUP BY c.crash_year
),

peak_hours AS (
	-- Extracts the hours with highest crash volume for each year
    SELECT
        crash_year,
        crash_hour  AS peak_hour,
        crashes     AS peak_hour_crashes,
        ROW_NUMBER() OVER(
            PARTITION BY crash_year
            ORDER BY crashes DESC
        ) AS rn
    FROM base
)
SELECT
    b.crash_year,
    SUM(b.crashes)                          AS total_crashes,
    SUM(b.vehicles_involved)                AS total_vehicles,
    -- Calculates the number of vehicles per crash on average for the year
    ROUND(SUM(b.vehicles_involved)
          / NULLIF(SUM(b.crashes), 0), 2)   AS avg_vehicles_per_crash,
    ph.peak_hour,
    ph.peak_hour_crashes,
    tf.factor_description                   AS top_contributing_factor,
    ur.unlicensed_pct,
    -- Displays the number for total crashes of the previous year for comparison
    LAG(SUM(b.crashes)) OVER (ORDER BY b.crash_year)   AS prev_year_crashes,
    -- Calculates YOY percentage change based on total volumne
    ROUND(
        (SUM(b.crashes) - LAG(SUM(b.crashes)) OVER(ORDER BY b.crash_year))
        * 100.0 / NULLIF(LAG(SUM(b.crashes)) OVER(ORDER BY b.crash_year), 0),
    1)                                      AS yoy_change_pct
FROM base b
JOIN top_factors tf
    ON  tf.crash_year = b.crash_year
    AND tf.rn = 1
JOIN unlicensed_rate ur
    ON  ur.crash_year = b.crash_year
JOIN peak_hours ph
    ON  ph.crash_year = b.crash_year
    AND ph.rn = 1
GROUP BY
    b.crash_year,
    ph.peak_hour,
    ph.peak_hour_crashes,
    tf.factor_description,
    ur.unlicensed_pct
ORDER BY b.crash_year;


SELECT * FROM vw_yoy_dashboard;



-- =============================================================
-- STORED PROCEDURES
-- =============================================================
DELIMITER $$
-- Full annual report for year inserted into SP
DROP PROCEDURE IF EXISTS sp_annual_report$$
CREATE PROCEDURE sp_annual_report(
    IN in_year INT
)
BEGIN
	-- 0. Ensures year being inputed into SP falls in bounds of the dataset
    IF in_year NOT BETWEEN 2012 AND 2023 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Year out of expected range (2012 – 2023).';
    END IF;
    
    -- 1. Calculates annual totals and concentration for peak hours
    WITH rush_hour AS (
		SELECT
			collision_id,
            crash_year,
            -- Hours below are considered peak driving times
            CASE
		          WHEN crash_hour BETWEEN 7 AND 9
                  OR crash_hour BETWEEN 16 AND 18
                  THEN 1 ELSE 0
			END AS is_rush_hour
            FROM collisions
            WHERE crash_year = in_year
	)
    SELECT
        crash_year,
        COUNT(DISTINCT collision_id) AS total_collisions,
        SUM(is_rush_hour) as rush_hour_collisions,
        -- Calculates percentage of crashes in rush hour compared to total crashes for the year
        ROUND(SUM(is_rush_hour) * 100.0 / COUNT(DISTINCT collision_id), 1) as rush_hour_pct
    FROM rush_hour
    GROUP BY crash_year;
    
    -- 2. Ranks top 10 contributing factors based on frequency
    SELECT
        cf.factor_description,
        COUNT(*) AS occurrences,
        -- Window function ranks all factors 
        RANK() OVER(ORDER BY COUNT(*) DESC) AS factor_rank
    FROM contributing_factors cf
    JOIN collisions c USING (collision_id)
    WHERE c.crash_year = in_year
      AND cf.factor_description NOT LIKE '%nspecified%'
    GROUP BY cf.factor_description
    ORDER BY occurrences DESC
    LIMIT 10;

	-- 3. Breaksdown incidents based on different vehicle types
    SELECT
        v.vehicle_type,
        COUNT(DISTINCT v.vehicle_id) AS vehicles,
        COUNT(DISTINCT v.collision_id) AS collisions
    FROM vehicles v
    JOIN collisions c USING (collision_id)
    WHERE c.crash_year = in_year
      AND v.vehicle_type IS NOT NULL
    GROUP BY v.vehicle_type
    ORDER BY vehicles DESC
    LIMIT 10;

	-- 4. Analyzes license status distribution for drivers involved
    SELECT
        d.license_status,
        COUNT(DISTINCT d.vehicle_id) AS driver_count,
        -- Calculates percentage of drivers based on their licensure
        ROUND(
            COUNT(DISTINCT d.vehicle_id) * 100.0
            / SUM(COUNT(DISTINCT d.vehicle_id)) OVER()
        , 2) AS pct_of_total
    FROM drivers d
    JOIN vehicles v  USING (vehicle_id)
    JOIN collisions c USING (collision_id)
    WHERE c.crash_year = in_year
      AND d.license_status IS NOT NULL
    GROUP BY d.license_status
    ORDER BY driver_count DESC;
END$$

-- Call example for SP (pick from 2012-2017)
CALL sp_annual_report(2016);



DELIMITER $$
-- Comparison on major categories for two chosen years
DROP PROCEDURE IF EXISTS sp_compare_years$$
CREATE PROCEDURE sp_compare_years(
    IN in_year_a INT,
    IN in_year_b INT
)
BEGIN
	-- Obtains results for two years into a usable result set
    WITH year_metrics AS (
        SELECT
            c.crash_year,
            COUNT(DISTINCT c.collision_id) AS total_crashes,
            -- Calculates average vehicles involved in the crash for each year
            ROUND(COUNT(DISTINCT v.vehicle_id)
                / NULLIF(COUNT(DISTINCT c.collision_id), 0), 2) AS avg_vehicles,
           -- Calculates unlicensed driver percentage involved in crashes for the year
           ROUND(
                SUM(CASE WHEN d.license_status = "Unlicensed"
                         THEN 1 ELSE 0 END)
                * 100.0 / NULLIF(COUNT(d.driver_id), 0)
            , 2) AS unlicensed_pct,
            -- Calculates the percentage of crashes happening each weeknd compared to the full week
            ROUND(
                COUNT(DISTINCT CASE WHEN c.crash_day_of_week IN (1,7)
                                    THEN c.collision_id END)
                * 100.0 / COUNT(DISTINCT c.collision_id)
            , 1) AS weekend_pct
        FROM collisions c
        LEFT JOIN vehicles v USING (collision_id)
        LEFT JOIN drivers d  ON d.vehicle_id = v.vehicle_id
        WHERE c.crash_year IN (in_year_a, in_year_b)
        GROUP BY c.crash_year
    )
    -- Stacks metrics for an easier report to observe
    SELECT 'Total Crashes' AS Metric, a.total_crashes AS Year_A, b.total_crashes AS Year_B, 
           CONCAT(ROUND((b.total_crashes - a.total_crashes) * 100.0 / a.total_crashes, 1), '%') AS pct_changed
    FROM year_metrics a, year_metrics b WHERE a.crash_year = in_year_a AND b.crash_year = in_year_b
    UNION ALL
    SELECT 'Avg Vehicles/Crash', a.avg_vehicles, b.avg_vehicles, CONCAT(ROUND(b.avg_vehicles - a.avg_vehicles, 2), '%')
    FROM year_metrics a, year_metrics b WHERE a.crash_year = in_year_a AND b.crash_year = in_year_b
    UNION ALL
    SELECT 'Unlicensed Driver %', a.unlicensed_pct, b.unlicensed_pct, CONCAT(ROUND(b.unlicensed_pct - a.unlicensed_pct, 2), '%')
    FROM year_metrics a, year_metrics b WHERE a.crash_year = in_year_a AND b.crash_year = in_year_b
    UNION ALL
    SELECT 'Weekend Crash %', a.weekend_pct, b.weekend_pct, CONCAT(ROUND(b.weekend_pct - a.weekend_pct, 2), '%')
    FROM year_metrics a, year_metrics b WHERE a.crash_year = in_year_a AND b.crash_year = in_year_b;

END$$

-- To call function pick two years between 2012-2023 (results may vary)
CALL sp_compare_years(2016,2015);