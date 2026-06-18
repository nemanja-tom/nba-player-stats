/* Staging layer: cleaned, typed views over the raw tables (mainly 1:1 with raw, with some columns not selected).
Goals: cast text to proper types (int, date), trim whitespace, convert blanks to NULL, and standardize column names to snake_case.
Views (not tables), so they always reflect current raw with no rebuild. */

-- Player bios view:

CREATE OR REPLACE VIEW staging.v_bios AS
SELECT
	CAST(NULLIF(TRIM("PLAYER_ID"), '') AS BIGINT) AS player_id,
	UNACCENT(NULLIF(TRIM("FIRST_NAME"), '')) AS first_name, -- Ran "CREATE EXTENSION IF NOT EXISTS unaccent" to enable the unaccent extension to make the names easier to search later in Power BI
	UNACCENT(NULLIF(TRIM("LAST_NAME"), '')) AS last_name,
	UNACCENT(NULLIF(TRIM("DISPLAY_FIRST_LAST"), '')) AS display_first_last,
	NULLIF(TRIM("PLAYER_SLUG"), '') AS player_slug,
	CAST(NULLIF(TRIM("BIRTHDATE"), '') AS DATE) AS birthdate,
	NULLIF(TRIM("SCHOOL"), '') AS school,
        CASE NULLIF(TRIM("COUNTRY"), '')
            WHEN 'México' THEN 'Mexico'
            WHEN 'DRC' THEN 'Democratic Republic of the Congo'
            WHEN 'Macedonia' THEN 'North Macedonia'
            ELSE NULLIF(TRIM("COUNTRY"), '')
        END AS country, -- this is needed for joining to model.country_codes later, when creating the model.dim_players table
	NULLIF(TRIM("LAST_AFFILIATION"), '') AS last_affiliation,
	NULLIF(TRIM("HEIGHT"), '') AS height,
	CAST(NULLIF(TRIM("WEIGHT"), '') AS INT) AS weight,
	CAST(NULLIF(TRIM("SEASON_EXP"), '') AS INT) AS season_exp,
	NULLIF(REPLACE(TRIM("JERSEY"), '-', ', '), '') AS jersey,
	NULLIF(TRIM("POSITION"), '') AS position,
	CAST(NULLIF(TRIM("FROM_YEAR"), '') AS INT) AS from_year,
	CAST(NULLIF(TRIM("TO_YEAR"), '') AS INT) AS to_year,
	NULLIF(TRIM("DRAFT_YEAR"), '') AS draft_year,
	NULLIF(TRIM("DRAFT_ROUND"), '') AS draft_round,
	NULLIF(TRIM("DRAFT_NUMBER"), '') AS draft_number,
	NULLIF(TRIM("GREATEST_75_FLAG"), '') AS greatest_75_flag
FROM raw.bios;

-- Player boxscores view:

CREATE OR REPLACE VIEW staging.v_player_boxscores AS
SELECT
	CAST(NULLIF(TRIM("PLAYER_ID"), '') AS BIGINT) AS player_id,
	CAST(NULLIF(TRIM("TEAM_ID"), '') AS BIGINT) AS team_id,
	NULLIF(TRIM("GAME_ID"), '') AS game_id,
	CAST(NULLIF(TRIM("GAME_DATE"), '') AS DATE) AS game_date,
	NULLIF(TRIM("MATCHUP"), '') AS matchup,
	NULLIF(TRIM("WL"), '') AS wl,
	CAST(NULLIF(TRIM("MIN"), '') AS DECIMAL(10,0)) AS min,
	CAST(NULLIF(TRIM("FGM"), '') AS DECIMAL(10,0)) AS fgm,
	CAST(NULLIF(TRIM("FGA"), '') AS DECIMAL(10,0)) AS fga,
	CAST(NULLIF(TRIM("FG3M"), '') AS DECIMAL(10,0)) AS fg3m,
	CAST(NULLIF(TRIM("FG3A"), '') AS DECIMAL(10,0)) AS fg3a,
	CAST(NULLIF(TRIM("FTM"), '') AS DECIMAL(10,0)) AS ftm,
	CAST(NULLIF(TRIM("FTA"), '') AS DECIMAL(10,0)) AS fta,
    	CAST(NULLIF(TRIM("OREB"), '') AS DECIMAL(10,0)) AS oreb,
   	CAST(NULLIF(TRIM("DREB"), '') AS DECIMAL(10,0)) AS dreb,
    	CAST(NULLIF(TRIM("REB"), '') AS DECIMAL(10,0)) AS reb,
    	CAST(NULLIF(TRIM("AST"), '') AS DECIMAL(10,0)) AS ast,
    	CAST(NULLIF(TRIM("STL"), '') AS DECIMAL(10,0)) AS stl,
    	CAST(NULLIF(TRIM("BLK"), '') AS DECIMAL(10,0)) AS blk,
    	CAST(NULLIF(TRIM("TOV"), '') AS DECIMAL(10,0)) AS tov,
    	CAST(NULLIF(TRIM("PF"), '') AS DECIMAL(10,0)) AS pf,
	CAST(NULLIF(TRIM("PTS"), '') AS DECIMAL(10,0)) AS pts,
	CAST(NULLIF(TRIM("PLUS_MINUS"), '') AS DECIMAL(10,0)) AS plus_minus,
	NULLIF(TRIM("Season"), '') AS season,
	NULLIF(TRIM("SeasonType"), '') AS season_type
FROM raw.player_boxscores;

-- Team boxscores view:

CREATE OR REPLACE VIEW staging.v_team_boxscores AS
SELECT
	CAST(NULLIF(TRIM("TEAM_ID"), '') AS BIGINT) AS team_id,
        NULLIF(TRIM("TEAM_ABBREVIATION"), '') AS team_abbreviation,
        NULLIF(TRIM("TEAM_NAME"), '') AS team_name,
	NULLIF(TRIM("GAME_ID"), '') AS game_id,
	CAST(NULLIF(TRIM("GAME_DATE"), '') AS DATE) AS game_date,
	NULLIF(TRIM("MATCHUP"), '') AS matchup,
	NULLIF(TRIM("WL"), '') AS wl,
	CAST(NULLIF(TRIM("MIN"), '') AS DECIMAL(10,0)) AS min,
	CAST(NULLIF(TRIM("FGM"), '') AS DECIMAL(10,0)) AS fgm,
	CAST(NULLIF(TRIM("FGA"), '') AS DECIMAL(10,0)) AS fga,
	CAST(NULLIF(TRIM("FG3M"), '') AS DECIMAL(10,0)) AS fg3m,
	CAST(NULLIF(TRIM("FG3A"), '') AS DECIMAL(10,0)) AS fg3a,
	CAST(NULLIF(TRIM("FTM"), '') AS DECIMAL(10,0)) AS ftm,
	CAST(NULLIF(TRIM("FTA"), '') AS DECIMAL(10,0)) AS fta,
        CAST(NULLIF(TRIM("OREB"), '') AS DECIMAL(10,0)) AS oreb,
   	CAST(NULLIF(TRIM("DREB"), '') AS DECIMAL(10,0)) AS dreb,
        CAST(NULLIF(TRIM("REB"), '') AS DECIMAL(10,0)) AS reb,
        CAST(NULLIF(TRIM("AST"), '') AS DECIMAL(10,0)) AS ast,
        CAST(NULLIF(TRIM("STL"), '') AS DECIMAL(10,0)) AS stl,
        CAST(NULLIF(TRIM("BLK"), '') AS DECIMAL(10,0)) AS blk,
        CAST(NULLIF(TRIM("TOV"), '') AS DECIMAL(10,0)) AS tov,
        CAST(NULLIF(TRIM("PF"), '') AS DECIMAL(10,0)) AS pf,
	CAST(NULLIF(TRIM("PTS"), '') AS DECIMAL(10,0)) AS pts,
	NULLIF(TRIM("Season"), '') AS season,
	NULLIF(TRIM("SeasonType"), '') AS season_type
FROM raw.team_boxscores;