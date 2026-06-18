-- Tables derived from previously created tables and views.

-- Player signature table - sums points scored and minutes played for each player on a team and logo-era level, to determine which team and logo best represent the player's career:

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

-- Per-player career style profile for the radar chart: each stat as a 0-100 percentile (ranked within each season vs. contemporaries).
-- Averaged across the player's 1000+ minute seasons. One row per player:

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

-- Players dimension table - dependent on the above two tables, as well as on country_codes and name_overrides, so that is why only created at this stage:

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