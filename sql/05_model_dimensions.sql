-- Dimension tables that Power BI will connect to

-- dim_season_type

CREATE TABLE IF NOT EXISTS model.dim_season_type (
    season_type_key int,
    season_type     text
);

INSERT INTO model.dim_season_type (season_type_key, season_type) VALUES
(1, 'Regular Season'),
(2, 'Playoffs');

-- dim_seasons 

CREATE TABLE IF NOT EXISTS model.dim_seasons AS
SELECT DISTINCT
    CAST(LEFT("Season", 4) AS INT) AS year,
    "Season" AS season
FROM raw.team_boxscores
ORDER BY year;

-- dim_teams

CREATE TABLE IF NOT EXISTS model.dim_teams AS
SELECT DISTINCT
	b.team_id,
	b.team_abbreviation,
	b.team_name,
	l.year,
	CAST(b.team_id AS VARCHAR) || '|' || CAST(l.year AS VARCHAR) AS team_year_key,
	l.logo AS logo_by_year
FROM staging.v_team_boxscores AS b
JOIN model.team_logos_by_year AS l
	ON b.team_name = l.team
	AND CAST(LEFT(b.season, 4) AS INT) = l.year;