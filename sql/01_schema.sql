-- Create and switch to NYC collisions database
CREATE DATABASE IF NOT EXISTS nyc_collisions;
USE nyc_collisions;

-- Primary table for unique collision events
CREATE TABLE IF NOT EXISTS collisions (
    collision_id        INT             NOT NULL,
    crash_date          DATE            NOT NULL,
    crash_time          TIME            NOT NULL,
    # Column computation below for optimized time-series analysis
    crash_hour          TINYINT UNSIGNED GENERATED ALWAYS AS (HOUR(crash_time)) STORED,
    crash_day_of_week   TINYINT UNSIGNED GENERATED ALWAYS AS (DAYOFWEEK(crash_date)) STORED,
    crash_year          SMALLINT UNSIGNED GENERATED ALWAYS AS (YEAR(crash_date)) STORED,
    crash_month         TINYINT UNSIGNED GENERATED ALWAYS AS (MONTH(crash_date)) STORED,
    PRIMARY KEY (collision_id)
) ENGINE=INNODB DEFAULT CHARSET=UTF8MB4;

CREATE TABLE IF NOT EXISTS vehicles (
    vehicle_id INT NOT NULL AUTO_INCREMENT,
    collision_id INT NOT NULL,
    state_registration VARCHAR(10) NULL,
    vehicle_type VARCHAR(80) NULL,
    vehicle_make VARCHAR(60) NULL,
    vehicle_year SMALLINT NULL,
    travel_direction VARCHAR(20) NULL,
    vehicle_occupants TINYINT UNSIGNED NULL,
    pre_crash VARCHAR(100) NULL,
    point_of_impact VARCHAR(80) NULL,
    vehicle_damage VARCHAR(100) NULL,
    public_property_damage TINYINT(1) NULL,
    PRIMARY KEY (vehicle_id)
)  ENGINE=INNODB DEFAULT CHARSET=UTF8MB4;

CREATE TABLE IF NOT EXISTS drivers (
    driver_id INT NOT NULL AUTO_INCREMENT,
    vehicle_id INT NOT NULL,
    driver_sex CHAR(1) NULL,
    license_status VARCHAR(30) NULL,
    license_jurisdiction VARCHAR(30) NULL,
    PRIMARY KEY (driver_id)
)  ENGINE=INNODB DEFAULT CHARSET=UTF8MB4;

-- Factor table for multiple entries per collision
CREATE TABLE IF NOT EXISTS contributing_factors (
    factor_id INT NOT NULL AUTO_INCREMENT,
    collision_id INT NOT NULL,
    factor_number TINYINT NOT NULL,
    factor_description VARCHAR(120) NOT NULL,
    PRIMARY KEY (factor_id)
)  ENGINE=INNODB DEFAULT CHARSET=UTF8MB4;




