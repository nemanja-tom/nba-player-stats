-- Fact tables that Power BI will connect to

-- Player Boxscores table with one record for each player-game combination:

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


-- Base Team Boxscores table with one record for each team-game combination.
-- As some team stats entries are missing (especially before the season 1985-86), this will only be a base table.
-- We will also build another table with team stats aggregated from the above model.player_boxscores table and call it model.team_boxscores_agg
-- Lastly, we will build the final model.team_boxscores by coalescing (if value is NOT NULL, take value from model.team_boxscores_base, otherwise take from model.team_boxscores_agg).
-- This doesn't help  fill all missing entries, but will be a considerable improvement in data completeness, especially in seasons 1983-84 and 1984-85.
-- Seasons before 1983-84 miss a lot of data in player boxscores as well, so we will handle that in Power BI by not showing most stats for seasons prior to 1983-84.

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
