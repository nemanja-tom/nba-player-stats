/* Steps to update the dataset with fresh data.
This will be done daily, or however often the current season boxscores are scraped via NBA API. */

-- 1. Remove current season records from all raw tables before loading the current season data, to avoid duplicate entries:

DELETE FROM raw.player_boxscores
WHERE "Season" = '2025-26'; -- edit manually to the current season, e.g. '2026-27'

DELETE FROM raw.team_boxscores
WHERE "Season" = '2025-26'; -- edit manually to the current season, e.g. '2026-27'

-- 2. Load current season CSVs into raw.player_boxscores and raw.team_boxscores, which is done manually in DBeaver

-- 2b. Before rebuilding, ensure model.team_logos_by_year has rows for the new season (add current-season team/logo rows manually)

-- 3. Rebuild the tables from the model schema (staging schema only contains views, so no need to touch that):

-- Drop tables first, in the order of dependency - most dependent one first and so on:

DROP TABLE IF EXISTS model.dim_players;

DROP TABLE IF EXISTS model.career_percentiles;

DROP TABLE IF EXISTS model.player_signature_team;

DROP TABLE IF EXISTS model.team_boxscores;

DROP TABLE IF EXISTS model.team_boxscores_agg;

DROP TABLE IF EXISTS model.team_boxscores_agg_team_only;

DROP TABLE IF EXISTS model.team_boxscores_base;

DROP TABLE IF EXISTS model.player_boxscores;

DROP TABLE IF EXISTS model.dim_seasons;

DROP TABLE IF EXISTS model.dim_teams;

-- Recreate tables in the same order as in 06_model_facts.sql and 07_model_derived.sql:

CREATE TABLE IF NOT EXISTS model.dim_seasons AS
SELECT DISTINCT
    CAST(LEFT("Season", 4) AS INT) AS year,
    "Season" AS season
FROM raw.team_boxscores
ORDER BY year;

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

CREATE TABLE IF NOT EXISTS model.player_boxscores AS
SELECT
	bs.player_id,
	bs.team_id,
	opp.team_id AS opponent_id,
	CAST(LEFT(bs.season, 4) AS INT) AS year,
	CASE bs.season_type
		WHEN 'Regular Season' THEN 1
		WHEN 'Playoffs' THEN 2
		END AS season_type_key,
	CAST(bs.team_id AS VARCHAR) || '|' || LEFT(bs.season, 4) AS team_year_key,
	LEFT(bs.season, 4) ||
		'|' || 
		CASE bs.season_type
			WHEN 'Regular Season' THEN '1'
			WHEN 'Playoffs' THEN '2'
			END ||
		'|' ||
		CAST(bs.team_id AS VARCHAR) AS year_type_team_key,
	bs.game_id,
	bs.game_date,
	EXTRACT(YEAR FROM AGE(bs.game_date, bios.birthdate)) AS age,
	CASE WHEN bs.matchup LIKE '%vs%' THEN 'Home'
		WHEN bs.matchup LIKE '%@%' THEN 'Away'
		END AS home_away,
	bs.wl,
	bs.min,
	bs.fgm,
	bs.fga,
	bs.fg3m,
	bs.fg3a,
	bs.ftm,
	bs.fta,
	bs.oreb,
	bs.dreb,
	bs.reb,
	bs.ast,
	bs.stl,
	bs.blk,
	bs.tov,
	bs.pf,
	bs.pts,
	CASE WHEN
	    (CASE WHEN bs.pts>= 10 THEN 1 ELSE 0 END +
	    CASE WHEN bs.ast>= 10 THEN 1 ELSE 0 END +
	    CASE WHEN bs.reb>= 10 THEN 1 ELSE 0 END +
	    CASE WHEN bs.stl>= 10 THEN 1 ELSE 0 END +
	    CASE WHEN bs.blk>= 10 THEN 1 ELSE 0 END)
	    >=2 THEN 1 ELSE 0 END AS dd2,
	CASE WHEN
	    (CASE WHEN bs.pts>= 10 THEN 1 ELSE 0 END +
	    CASE WHEN bs.ast>= 10 THEN 1 ELSE 0 END +
	    CASE WHEN bs.reb>= 10 THEN 1 ELSE 0 END +
	    CASE WHEN bs.stl>= 10 THEN 1 ELSE 0 END +
	    CASE WHEN bs.blk>= 10 THEN 1 ELSE 0 END)
	    >=3 THEN 1 ELSE 0 END AS td3
FROM staging.v_player_boxscores AS bs
INNER JOIN staging.v_bios AS bios -- to make sure that inner join is safe, always check whether any boxscore player_id is missing from bios (see 09_checks.sql)
USING(player_id)
INNER JOIN staging.v_team_boxscores AS opp
	ON bs.game_id = opp.game_id
    AND bs.team_id <> opp.team_id;

CREATE TABLE IF NOT EXISTS model.team_boxscores_base AS
SELECT
	t.team_id,
	o.team_id AS opponent_id,
	t.game_id,
	t.game_date,
	CAST(LEFT(t.season, 4) AS INT) AS year,
	CASE t.season_type
		WHEN 'Regular Season' THEN 1
		WHEN 'Playoffs' THEN 2
		END AS season_type_key,
	CAST(t.team_id AS VARCHAR) || '|' || LEFT(t.season, 4) AS team_year_key,
	LEFT(t.season, 4) ||
		'|' || 
		CASE t.season_type
			WHEN 'Regular Season' THEN '1'
			WHEN 'Playoffs' THEN '2'
			END ||
		'|' ||
		CAST(t.team_id AS VARCHAR) AS year_type_team_key,
	CASE WHEN t.matchup LIKE '%vs%' THEN 'Home'
		WHEN t.matchup LIKE '%@%' THEN 'Away'
		END AS home_away,
	t.wl,
	t.min,
	t.fgm,
	t.fga,
	t.fg3m,
	t.fg3a,
	t.ftm,
	t.fta,
	t.oreb,
	t.dreb,
	t.reb,
	t.ast,
	t.stl,
	t.blk,
	t.tov,
	t.pf,
	t.pts,
	o.fgm AS opp_fgm,
	o.fga AS opp_fga,
	o.fg3m AS opp_fg3m,
	o.fg3a AS opp_fg3a,
	o.ftm AS opp_ftm,
	o.fta AS opp_fta,
	o.oreb AS opp_oreb,
	o.dreb AS opp_dreb,
	o.reb AS opp_reb,
	o.ast AS opp_ast,
	o.stl AS opp_stl,
	o.blk AS opp_blk,
	o.tov AS opp_tov,
	o.pf AS opp_pf,
	o.pts AS opp_pts
FROM staging.v_team_boxscores AS t
INNER JOIN staging.v_team_boxscores AS o
ON t.game_id = o.game_id
	AND t.team_id <> o.team_id
WHERE t.game_id <> '0021201214'; -- Celtics - Pacers game from 2013-04-16. It was cancelled due to Boston Marathon bombing, so all stats were captured as zeroes.

-- Create team stats table by aggregating the player stats from model.player_boxscores on team-game level, as explained above.
-- These are just team stats. Opponent stats will be added in the next table after this one:

CREATE TABLE IF NOT EXISTS model.team_boxscores_agg_team_only AS
SELECT
	team_id,
	game_id,
	SUM(min) AS min,
	SUM(fgm) AS fgm,
	SUM(fga) AS fga,
	SUM(fg3m) AS fg3m,
	SUM(fg3a) AS fg3a,
	SUM(ftm) AS ftm,
	SUM(fta) AS fta,
	SUM(oreb) AS oreb,
	SUM(dreb) AS dreb,
	SUM(reb) AS reb,
	SUM(ast) AS ast,
	SUM(stl) AS stl,
	SUM(blk) AS blk,
	SUM(tov) AS tov,
	SUM(pf) AS pf,
	SUM(pts) AS pts
FROM model.player_boxscores
GROUP BY team_id, game_id;

-- Expand the above model.team_boxscores_agg_team_only table via self join to get the opposing team stats:

CREATE TABLE IF NOT EXISTS model.team_boxscores_agg AS
SELECT
	t.team_id,
	t.game_id,
	t.min,
	t.fgm,
	t.fga,
	t.fg3m,
	t.fg3a,
	t.ftm,
	t.fta,
	t.oreb,
	t.dreb,
	t.reb,
	t.ast,
	t.stl,
	t.blk,
	t.tov,
	t.pf,
	t.pts,
	o.fgm AS opp_fgm,
	o.fga AS opp_fga,
	o.fg3m AS opp_fg3m,
	o.fg3a AS opp_fg3a,
	o.ftm AS opp_ftm,
	o.fta AS opp_fta,
	o.oreb AS opp_oreb,
	o.dreb AS opp_dreb,
	o.reb AS opp_reb,
	o.ast AS opp_ast,
	o.stl AS opp_stl,
	o.blk AS opp_blk,
	o.tov AS opp_tov,
	o.pf AS opp_pf,
	o.pts AS opp_pts
FROM model.team_boxscores_agg_team_only AS t
INNER JOIN model.team_boxscores_agg_team_only AS o
ON t.game_id = o.game_id
	AND t.team_id <> o.team_id;

-- Create definite team boxscores fact table, by coalescing from tables model.team_boxscores_base and model.team_boxscores_agg, as explained above:

CREATE TABLE IF NOT EXISTS model.team_boxscores AS
SELECT
	b.team_id,
	b.opponent_id,
	b.game_id,
	b.game_date,	
	b.year,
	b.season_type_key,
	b.team_year_key,
	b.year_type_team_key,
	b.home_away,
	b.wl,
	COALESCE(b.min, a.min) AS min,
	COALESCE(b.fgm, a.fgm) AS fgm,
	COALESCE(b.fga, a.fga) AS fga,
	COALESCE(b.fg3m, a.fg3m) AS fg3m,
	COALESCE(b.fg3a, a.fg3a) AS fg3a,
	COALESCE(b.ftm, a.ftm) AS ftm,
	COALESCE(b.fta, a.fta) AS fta,
	COALESCE(b.oreb, a.oreb) AS oreb,
	COALESCE(b.dreb, a.dreb) AS dreb,
	COALESCE(b.reb, a.reb) AS reb,
	COALESCE(b.ast, a.ast) AS ast,
	COALESCE(b.stl, a.stl) AS stl,
	COALESCE(b.blk, a.blk) AS blk,
	COALESCE(b.tov, a.tov) AS tov,
	COALESCE(b.pf, a.pf) AS pf,
	COALESCE(b.pts, a.pts) AS pts,
	COALESCE(b.opp_fgm, a.opp_fgm) AS opp_fgm,
	COALESCE(b.opp_fga, a.opp_fga) AS opp_fga,
	COALESCE(b.opp_fg3m, a.opp_fg3m) AS opp_fg3m,
	COALESCE(b.opp_fg3a, a.opp_fg3a) AS opp_fg3a,
	COALESCE(b.opp_ftm, a.opp_ftm) AS opp_ftm,
	COALESCE(b.opp_fta, a.opp_fta) AS opp_fta,
	COALESCE(b.opp_oreb, a.opp_oreb) AS opp_oreb,
	COALESCE(b.opp_dreb, a.opp_dreb) AS opp_dreb,
	COALESCE(b.opp_reb, a.opp_reb) AS opp_reb,
	COALESCE(b.opp_ast, a.opp_ast) AS opp_ast,
	COALESCE(b.opp_stl, a.opp_stl) AS opp_stl,
	COALESCE(b.opp_blk, a.opp_blk) AS opp_blk,
	COALESCE(b.opp_tov, a.opp_tov) AS opp_tov,
	COALESCE(b.opp_pf, a.opp_pf) AS opp_pf,
	COALESCE(b.opp_pts, a.opp_pts) AS opp_pts
FROM model.team_boxscores_base AS b
LEFT JOIN model.team_boxscores_agg AS a
USING(game_id, team_id);

CREATE TABLE IF NOT EXISTS model.player_signature_team AS
WITH impact_by_logo AS (
    SELECT
        b.player_id,
        b.team_id,
        dt.team_name,
        dt.logo_by_year AS logo,
        SUM(COALESCE(b.pts,0) + COALESCE(b.min,0)) AS impact
    FROM model.player_boxscores AS b
    INNER JOIN model.dim_teams AS dt USING (year, team_id)
    GROUP BY b.player_id, b.team_id, dt.team_name, dt.logo_by_year
),
impact_by_team AS (
    SELECT
        player_id,
        team_id,
        SUM(impact) AS team_impact,
        ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY SUM(impact) DESC) AS team_rank
    FROM impact_by_logo
    GROUP BY player_id, team_id
),
top_logo AS (
    SELECT
        il.player_id,
        il.team_id,
        il.team_name,
        il.logo,
        ROW_NUMBER() OVER (PARTITION BY il.player_id ORDER BY il.impact DESC) AS logo_rank
    FROM impact_by_logo AS il
    INNER JOIN impact_by_team AS it USING (player_id, team_id)
    WHERE it.team_rank = 1  -- only logo-eras within the player's signature franchise
)
SELECT
    player_id,
    team_id    AS main_team_id,
    team_name  AS main_team_name,
    logo       AS main_logo
FROM top_logo
WHERE logo_rank = 1;

CREATE TABLE IF NOT EXISTS model.career_percentiles AS
WITH base AS (
SELECT
	player_id,
	year,
	COUNT(*) AS gp,
	SUM(min) AS min,
	CAST(SUM(min) AS DECIMAL) / COUNT(*) AS min_pg,
	CAST(SUM(fgm) AS DECIMAL) / COUNT(*) AS fgm_pg,
	CAST(SUM(fga) AS DECIMAL) / COUNT(*) AS fga_pg,
	CAST(SUM(fgm) - SUM(fg3m) AS DECIMAL) / COUNT(*) AS fg2m_pg,
	CAST(SUM(fga) - SUM(fg3a) AS DECIMAL) / COUNT(*) AS fg2a_pg,
	CAST(SUM(fg3m) AS DECIMAL) / COUNT(*) AS fg3m_pg,
	CAST(SUM(fg3a) AS DECIMAL) / COUNT(*) AS fg3a_pg,
	CAST(SUM(ftm) AS DECIMAL) / COUNT(*) AS ftm_pg,
	CAST(SUM(fta) AS DECIMAL) / COUNT(*) AS fta_pg,
	CAST(SUM(oreb) AS DECIMAL) / COUNT(*) AS oreb_pg,
	CAST(SUM(dreb) AS DECIMAL) / COUNT(*) AS dreb_pg,
	CAST(SUM(reb) AS DECIMAL) / COUNT(*) AS reb_pg,
	CAST(SUM(ast) AS DECIMAL) / COUNT(*) AS ast_pg,
	CAST(SUM(stl) AS DECIMAL) / COUNT(*) AS stl_pg,
	CAST(SUM(blk) AS DECIMAL) / COUNT(*) AS blk_pg,
	CAST(SUM(tov) AS DECIMAL) / COUNT(*) AS tov_pg,
	CAST(SUM(pf) AS DECIMAL) / COUNT(*) AS pf_pg,
	CAST(SUM(pts) AS DECIMAL) / COUNT(*) AS pts_pg,
	CAST(SUM(pts) AS DECIMAL) / NULLIF(2 * (SUM(fga) + 0.44 * SUM(fta)), 0) AS ts,
	SUM(dd2) AS dd2,
	SUM(td3) AS td3
FROM model.player_boxscores
GROUP BY player_id, year
HAVING SUM(min) >= 1000),
percents AS (
SELECT
	*,
	PERCENT_RANK() OVER (PARTITION BY year ORDER BY pts_pg)  * 100 AS pts_pctl,
	PERCENT_RANK() OVER (PARTITION BY year ORDER BY fg2m_pg) * 100 AS fg2m_pctl,
	PERCENT_RANK() OVER (PARTITION BY year ORDER BY fg3m_pg) * 100 AS fg3m_pctl,
	PERCENT_RANK() OVER (PARTITION BY year ORDER BY reb_pg)  * 100 AS reb_pctl,
	PERCENT_RANK() OVER (PARTITION BY year ORDER BY ast_pg)  * 100 AS ast_pctl,
	PERCENT_RANK() OVER (PARTITION BY year ORDER BY stl_pg)  * 100 AS stl_pctl,
	PERCENT_RANK() OVER (PARTITION BY year ORDER BY blk_pg)  * 100 AS blk_pctl,
	PERCENT_RANK() OVER (PARTITION BY year ORDER BY ts)      * 100 AS ts_pctl
FROM base)
SELECT
	player_id,
	AVG(pts_pctl) AS pts_pctl,
	AVG(fg2m_pctl) AS fg2m_pctl,
	AVG(fg3m_pctl) AS fg3m_pctl,
	AVG(ts_pctl) AS ts_pctl,
	AVG(ast_pctl) AS ast_pctl,
	AVG(reb_pctl) AS reb_pctl,
	AVG(stl_pctl) AS stl_pctl,
	AVG(blk_pctl) AS blk_pctl
FROM percents
GROUP BY player_id;

CREATE TABLE IF NOT EXISTS model.dim_players AS
SELECT
	b.player_id,
	COALESCE(ovr.name_override, b.display_first_last) AS player_name,
	b.birthdate,
	b.school,
	b.country,
	b.height,
	CASE 
    WHEN b.height IS NOT NULL THEN
        CAST(CAST(SPLIT_PART(b.height, '-', 1) AS INT) * 30.48 
    	+ CAST(SPLIT_PART(b.height, '-', 2) AS INT) * 2.54 AS INT)
		END AS height_cm,
	b.weight,
	CAST(ROUND(b.weight * 0.45359237) AS INT) AS weight_kg,
	b.season_exp,
	b.jersey,
	b.position,
	b.from_year,
	b.to_year,
	b.draft_year,
	b.draft_round,
	b.draft_number,
	'https://cdn.nba.com/headshots/nba/latest/1040x760/' || b.player_id || '.png' AS player_img,
	'https://flagcdn.com/' || cc.code || '.svg' AS country_flag,
	pst.main_team_id,
	pst.main_team_name,
	pst.main_logo,
	cp.pts_pctl,
	cp.fg2m_pctl,
	cp.fg3m_pctl,
	cp.ts_pctl,
	cp.ast_pctl,
	cp.reb_pctl,
	cp.stl_pctl,
	cp.blk_pctl
FROM staging.v_bios AS b
LEFT JOIN model.country_codes AS cc
ON b.country = cc.country
LEFT JOIN model.player_signature_team AS pst
ON b.player_id = pst.player_id
LEFT JOIN model.name_overrides AS ovr
ON b.player_id = ovr.player_id
LEFT JOIN model.career_percentiles AS cp
ON b.player_id = cp.player_id;
