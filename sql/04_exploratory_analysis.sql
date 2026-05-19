-- =============================================================
-- NYC Motor Vehicle Collision Analysis
-- =============================================================
USE nyc_collisions;

-- Query calculates crashes per year and the percent distribution for all data
WITH annual_counts AS (
SELECT
	crash_year,
    COUNT(DISTINCT collision_id) AS yearly_total
    FROM collisions
    GROUP BY crash_year
)
SELECT 
	crash_year,
    yearly_total,
    -- Window function to calculate percentage of overall crashes for each year
    ROUND(yearly_total * 100.0 / SUM(yearly_total) OVER(), 1) AS pct_of_total
FROM annual_counts
ORDER BY crash_year;



-- Crash volume by hour for each day to identify peak periods
WITH crashes AS (
	SELECT
		crash_hour,
		COUNT(DISTINCT collision_id) AS total_crashes
	FROM collisions
    GROUP BY crash_hour
)
SELECT 
	crash_hour,
    total_crashes,
    -- Window function calculates percentage of crashes compared to total daily value
    ROUND(total_crashes * 100.0 / SUM(total_crashes) OVER(), 1) AS pct_crashes
    FROM crashes
    ORDER BY crash_hour;



-- Identifies crash volume by day of week compared to daily average
WITH daily_counts AS (
	SELECT 
		crash_day_of_week,
        COUNT(DISTINCT collision_id) as total_crashes
	FROM collisions
    GROUP BY crash_day_of_week
),
day_of_week_comp AS (
	SELECT
		total_crashes,
		crash_day_of_week,
        -- Calculates daily average as baseline for variance comparison
        ROUND(AVG(total_crashes) OVER(), 0) AS avg_daily_crashes
	FROM daily_counts
)
SELECT
	-- Maps day of week to descriptive naming (numbers can be ambiguous) 
    CASE crash_day_of_week
        WHEN 1 THEN 'Sunday'
        WHEN 2 THEN 'Monday'
        WHEN 3 THEN 'Tuesday'
        WHEN 4 THEN 'Wednesday'
        WHEN 5 THEN 'Thursday'
        WHEN 6 THEN 'Friday'
        WHEN 7 THEN 'Saturday'
    END AS day_of_week,
    total_crashes,
    avg_daily_crashes,
    -- Calculates percentage variance from average daily crashes
	ROUND(
    ((total_crashes - avg_daily_crashes) / avg_daily_crashes ) * 100.0,
    2) as variance
FROM day_of_week_comp
ORDER BY crash_day_of_week;



-- Ranking 15 top contributing factors leading to conclusions except for those unspecified
SELECT
    factor_description,
    COUNT(*) AS occurrences,
    -- Calculates the percentage impact of each factor compared to relative total
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct,
    -- Window function that assigns rank based on frequency for most prevalent causes
    RANK() OVER (ORDER BY COUNT(*) DESC)AS factor_rank
FROM contributing_factors
WHERE factor_description NOT LIKE '%nspecified%'
GROUP BY factor_description
ORDER BY occurrences DESC
LIMIT 15;



-- Identifies top contributing factor leading to collisions for each year
WITH yearly_factors AS (
    SELECT
        c.crash_year,
        cf.factor_description,
        COUNT(*) AS occurrences,
        -- Parition by is used to find the top rank for each contributing factor per year
        RANK() OVER (PARTITION BY c.crash_year ORDER BY COUNT(*) DESC
        ) AS rnk
    FROM contributing_factors cf
    JOIN collisions c ON cf.collision_id = c.collision_id
    WHERE cf.factor_description NOT LIKE '%nspecified%'
    GROUP BY c.crash_year, cf.factor_description
)
SELECT 
	crash_year, 
    factor_description, 
    occurrences
FROM yearly_factors
WHERE rnk = 1
ORDER BY crash_year;



-- Identifies most common combinations of contributing factors when multiple factors are present in each crash
WITH factor_pairs AS (
    SELECT
        a.collision_id,
        a.factor_description AS factor_a,
        b.factor_description AS factor_b
    FROM contributing_factors a
    JOIN contributing_factors b
        ON  a.collision_id = b.collision_id
        -- Join ensures primary factor (1) is paired with secondary factor(2) from the same crash
        AND a.factor_number < b.factor_number
    WHERE a.factor_description NOT LIKE '%nspecified%'
      AND b.factor_description NOT LIKE '%nspecified%'
)
SELECT
    factor_a,
    factor_b,
    COUNT(*) AS co_occurrences
FROM factor_pairs
GROUP BY factor_a, factor_b
ORDER BY co_occurrences DESC
LIMIT 20;



-- Out-of-state vehicle involvement in collisions per year
SELECT 
    c.crash_year,
    -- Counts NY cars involved in collisions
    COUNT(CASE
        WHEN v.state_registration = 'NY' THEN 1
    END) AS ny_vehicles,
    -- Counts all other state vehicles while excluding Nulls
    COUNT(CASE
        WHEN
            v.state_registration != 'NY'
                AND v.state_registration IS NOT NULL
        THEN
            1
    END) AS oos_vehicles,
    -- Calculates OOS percentage compared to the entire crash population
    ROUND(COUNT(CASE
                WHEN
                    v.state_registration != 'NY'
                        AND v.state_registration IS NOT NULL
                THEN
                    1
            END) * 100.0 / NULLIF(COUNT(v.vehicle_id), 0),
            1) AS oos_pct
FROM
    vehicles v
        JOIN
    collisions c USING (collision_id)
GROUP BY c.crash_year
ORDER BY c.crash_year;



-- Number of vehicles involved in crashes based on percentage
WITH vehicles_per_crash AS (
    SELECT
        collision_id,
        COUNT(*) AS vehicle_count
    FROM vehicles
    GROUP BY collision_id
)
SELECT
    vehicle_count AS vehicles_in_crash,
    COUNT(*) AS num_collisions,
    -- Calculates percentage of total crashes for each vehicle count compared to total
    ROUND(COUNT(*) * 100.0  / SUM(COUNT(*)) OVER(), 2) AS pct
FROM vehicles_per_crash
GROUP BY vehicle_count
ORDER BY vehicle_count;



-- Analyzing relationship between license status and factors per driver
SELECT 
    d.license_status,
    -- Counting unique drivers to ensure accuracy
    COUNT(DISTINCT d.vehicle_id) AS drivers,
    -- Unique factor mentions for accuracy
    COUNT(DISTINCT cf.factor_id) AS factor_mentions,
    -- Calculating average factors per driver 
    ROUND(COUNT(DISTINCT cf.factor_id) * 1.0 / NULLIF(COUNT(DISTINCT d.vehicle_id), 0),
            2) AS factors_per_driver
FROM
    drivers d
        JOIN
    vehicles v USING (vehicle_id)
        LEFT JOIN
    contributing_factors cf ON cf.collision_id = v.collision_id
WHERE
    d.license_status IS NOT NULL
GROUP BY d.license_status
ORDER BY drivers DESC;



-- Comparison of the distribution for each contributing factors between Licensed and unlicensed drivers
WITH factor_counts AS (
    SELECT 
        cf.factor_description,
        -- Counting unique vehicles per license type
        COUNT(DISTINCT CASE WHEN d.license_status = 'Licensed' THEN v.vehicle_id END) AS licensed_count,
        COUNT(DISTINCT CASE WHEN d.license_status = 'Unlicensed' THEN v.vehicle_id END) AS unlicensed_count
    FROM drivers d
    JOIN vehicles v USING (vehicle_id)
    JOIN contributing_factors cf ON v.collision_id = cf.collision_id
    GROUP BY 1
),
license_totals AS (
    -- Calculates total mentions of factors for each license group
    SELECT 
        SUM(licensed_count) AS total_licensed,
        SUM(unlicensed_count) AS total_unlicensed
    FROM factor_counts
)
SELECT 
    f.factor_description,
    -- Calculates frequency for each factor as percentage of total factors for each of the license groups
    ROUND(f.licensed_count * 100.0 / lt.total_licensed, 2) AS licensed_pct,
    ROUND(f.unlicensed_count * 100.0 / lt.total_unlicensed, 2) AS unlicensed_pct
FROM factor_counts f, license_totals lt
ORDER BY unlicensed_pct DESC;



-- 3-Month Rolling average and Month-over-Month change analysis
WITH monthly AS (
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
    monthly_crashes,
    -- Calculates 3-month moving average to compare seasonality
    ROUND(AVG(monthly_crashes) OVER(
        ORDER BY crash_year, crash_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 1) AS rolling_3mo_avg,
    -- Calculates the absolute difference in volume from the previous month
    monthly_crashes - LAG(monthly_crashes, 1)
        OVER (ORDER BY crash_year, crash_month) AS mom_change
FROM monthly
ORDER BY crash_year, crash_month;



-- Comparing Year-over-Year change by hour based on volume recorded for each year and previous year
WITH hourly_by_year AS (
    SELECT
        crash_year,
        crash_hour,
        COUNT(DISTINCT collision_id) AS crashes
    FROM collisions
    GROUP BY crash_year, crash_hour
)
SELECT
    crash_year,
    crash_hour,
    crashes,
    -- Obtains the crash count for the same hour but from the previous year
    LAG(crashes) OVER (PARTITION BY crash_hour ORDER BY crash_year) AS prev_year_crashes,
    -- Calculates percentage change to compare volume from previous year to current 
    ROUND(
        (crashes - LAG(crashes) OVER (PARTITION BY crash_hour ORDER BY crash_year))
        * 100.0
        / NULLIF(LAG(crashes) OVER (PARTITION BY crash_hour ORDER BY crash_year), 0),
    1) AS yoy_pct_change
FROM hourly_by_year
ORDER BY crash_year, crash_hour;



-- Year-over-Year crash performance and risk profiling
WITH
base AS (
	-- Foundation for metrics that will be used in the rest of the query
    SELECT
        c.crash_year,
        c.crash_hour,
        COUNT(DISTINCT c.collision_id) AS crashes,
        COUNT(DISTINCT v.vehicle_id) AS vehicles_involved
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
        ROW_NUMBER() OVER (
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
        crash_hour AS peak_hour,
        crashes AS peak_hour_crashes,
        ROW_NUMBER() OVER (
            PARTITION BY crash_year
            ORDER BY crashes DESC
        ) AS rn
    FROM base
)
SELECT
    b.crash_year,
    SUM(b.crashes) AS total_crashes,
    SUM(b.vehicles_involved) AS total_vehicles,
    -- Calculates the number of vehicles per crash on average for the year
    ROUND(SUM(b.vehicles_involved)
          / NULLIF(SUM(b.crashes), 0), 2) AS avg_vehicles_per_crash,
    ph.peak_hour,
    ph.peak_hour_crashes,
    tf.factor_description AS top_contributing_factor,
    ur.unlicensed_pct,
    -- Displays the number for total crashes of the previous year for comparison
    LAG(SUM(b.crashes)) OVER (ORDER BY b.crash_year) AS prev_year_crashes,
    -- Calculates YOY percentage change based on total volumne
    ROUND(
        (SUM(b.crashes) - LAG(SUM(b.crashes)) OVER (ORDER BY b.crash_year))
        * 100.0 / NULLIF(LAG(SUM(b.crashes)) OVER (ORDER BY b.crash_year), 0),
    1) AS yoy_change_pct
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
