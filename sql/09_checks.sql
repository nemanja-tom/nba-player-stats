/* Queries used to check the integrity of the data after an update */

-- Check whether any boxscore player_id is missing from bios:

SELECT DISTINCT bs.player_id
FROM staging.v_player_boxscores bs
LEFT JOIN staging.v_bios bios USING (player_id)
WHERE bios.player_id IS NULL;

-- Check for duplicates in boxscore views:

SELECT player_id, game_id, team_id, COUNT(*)
FROM staging.v_player_boxscores
GROUP BY player_id, game_id, team_id
HAVING COUNT(*) > 1;

SELECT game_id, team_id, COUNT(*)
FROM staging.v_team_boxscores
GROUP BY game_id, team_id
HAVING COUNT(*) > 1;


-- Check after updating model.team_logos_by_year (it should be no results, meaning no team-season will be missing a logo):

SELECT DISTINCT b.team_name, CAST(LEFT(b.season,4) AS INT) AS year
FROM staging.v_team_boxscores b
LEFT JOIN model.team_logos_by_year l
  ON b.team_name = l.team AND CAST(LEFT(b.season,4) AS INT) = l.year
WHERE l.team IS NULL;

-- Check that building model.player_boxscores preserved the row count (the joins to bios and team_boxscores didn't add or drop rows - both counts should match):

SELECT COUNT(*) FROM model.player_boxscores
UNION ALL
SELECT COUNT(*) FROM staging.v_player_boxscores;

-- Check if self-join when creating model.team_boxscores is safe (both rows should show same count):

SELECT COUNT(*)
FROM staging.v_team_boxscores AS t
INNER JOIN staging.v_team_boxscores AS o
ON t.game_id = o.game_id
	AND t.team_id <> o.team_id
UNION ALL
SELECT COUNT(*)
FROM staging.v_team_boxscores;

-- Check if you have any players with identical names (if so, INSERT INTO model.name_overrides, see 04_model_reference_tables.sql):

WITH base AS (
	SELECT player_name, COUNT(*)
	FROM model.dim_players
	GROUP BY player_name
	ORDER BY player_name),
dupes AS (
	SELECT *
	FROM base
	WHERE count > 1)
SELECT player_name, player_id, birthdate
FROM model.dim_players
WHERE player_name IN (SELECT player_name FROM dupes);

-- Check for duplicate player_id in dim_players:
SELECT player_id, COUNT(*)
FROM model.dim_players
GROUP BY player_id
HAVING COUNT(*) > 1;

-- Data completeness check by season - the query behind the "missing data" finding in the README.
-- Counts what % of team-game rows are missing each stat, per season.
-- This is how the ~90% gap in 1983-84 / 1984-85 team box scores (OREB/DREB/STL/BLK/TOV) was discovered,
-- It motivated the COALESCE reconstruction in 06_model_facts.sql.

SELECT
	CAST(LEFT(season, 4) AS INT) AS year,
	COUNT(*) AS games,
	ROUND(100.0 * COUNT(*) FILTER (WHERE oreb IS NULL) / COUNT(*), 1) AS pct_missing_oreb,
	ROUND(100.0 * COUNT(*) FILTER (WHERE dreb IS NULL) / COUNT(*), 1) AS pct_missing_dreb,
	ROUND(100.0 * COUNT(*) FILTER (WHERE stl  IS NULL) / COUNT(*), 1) AS pct_missing_stl,
	ROUND(100.0 * COUNT(*) FILTER (WHERE blk  IS NULL) / COUNT(*), 1) AS pct_missing_blk,
	ROUND(100.0 * COUNT(*) FILTER (WHERE tov  IS NULL) / COUNT(*), 1) AS pct_missing_tov
FROM staging.v_team_boxscores
GROUP BY year
ORDER BY year;

-- Confirm that no players were lost building dim_players (both counts should match ):
SELECT COUNT(*) FROM model.dim_players
UNION ALL
SELECT COUNT(*) FROM staging.v_bios;

