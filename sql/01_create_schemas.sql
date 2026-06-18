/* Creates the three-layer schema structure for the NBA analytics project.
1. raw = untouched CSV loads (all columns are varchar type)
2. staging = cleaned + typed, column names normalized to snake_case
3. model = star schema (dimensions + facts) that Power BI connects to */

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS model;