# NBA Stats Analytics - SQL-First Data Pipeline & Power BI Presentation

This is an end-to-end basketball analytics project covering the full history of the NBA (1946–47 season to present).
Data was transformed in **PostgreSQL** and loaded to **Power BI**, where the relationships were built, DAX measures written and visualization designed.
 
**The purpose of this project?**

It was built to demonstrate Power BI and especially SQL skills needed for transition into data analytics / BI development.
Hopefully, it will prove skills beyond just dashboard design, including schema design, data-quality checking, data transformation,
creation of advanced metrics and finally creating visually compelling presentation in Power BI.

**Live report (no Power BI account needed to view):** [View the interactive report](https://app.powerbi.com/view?r=eyJrIjoiNzQ1YjFhMTMtY2QwMS00OTE3LWJkNjItOWU2ZmM5YThkNDQ4IiwidCI6ImUzYmY3OWFhLTExZTktNDkwOS1hYzI4LTA1N2IzOGY3YmUyOSIsImMiOjl9)

**Author:** Nemanja Tomić - [LinkedIn](https://www.linkedin.com/in/nemanja-tomic-data/)


## Overview

- **Full league history** - every season from 1946–47 onward, with the report hiding advanced visuals where the historical data does not support advanced metrics (more below).
- **Three-layer PostgreSQL setup** - `raw` -> `staging` -> `model`, from importing raw data, staging it into properly typed tables and modeling into tables ready for Power BI.
- **Highly advanced metrics calculated from imported data in Power BI** - Player Efficiency Rating (PER), Win Shares, True Shooting %, Four Factors, usage and pace - calculated by chaining complex measures and validated against Basketball-Reference and NBA.com.
- **A documented data-quality checks and corrections** - a 90%-missing-data problem in the 1983–85 team box scores, solved with a COALESCE-based reconstruction (more details below).
- **Audience-centric design** - fan-friendly player career overview page with a deliberate column selection and intuitive visuals.


## Architecture

The main idea: **PostgreSQL does the heavy-lifting; Power BI does the presentation.**

raw schema -> staging schema -> model schema -> Power BI
(unchanged)  (cleaned & typed)  (star schema)(DAX & visuals)

### raw schema
All source CSVs are loaded here into **tables**. All columns are **VARCHAR** data type to avoid any uncontrolled changes and remain 100% true to the original data.
This keeps any potential source data changes or issues within this layer, while staging layer and beyond is not affected.

### staging schema
This schema only contains **views** ('v_' prefix), not tables. Each view casts raw VARCHAR strings to proper types and applies cleaning logic.
Since these are views, they automatically pull data from the raw tables, so there is no risk of them showing old data.
Column typing is done by 'CAST()' rather than the :: PostgreSQL shorthand, since I try to develop a habit of using universal and portable SQL syntax where possible.

### model schema
This layer is a **star schema**, materialized as **tables** (not views) to achieve better query performance in Power BI.
The tables include fact and dimension tables ready to be loaded to Power BI with minimal changes in Power Query (such as renaming columns and changing data type from decimal to whole number).

1. model.player_boxscores (PostgreSQL) -> FactPlayerBoxScore(Power BI) - one row per player per game
2. model.team_boxscores (PostgreSQL) -> FactTeamBoxScore(Power BI) - one row per team per game
3. model.dim_players (PostgreSQL) -> DimPlayer (Power BI) - one row per player - career percentile stats joined in to avoid 1-to-1 relationship between two tables in Power BI (more below)
4. model.dim_teams (PostgreSQL) -> DimTeam (Power BI) - one row per team **per year** (team-year grain was needed to allow matching to era-correct team names & logos)
5. model.dim_seasons (PostgreSQL) -> DimSeason (Power BI) - one row per season - "2025-26" style Season column for display, '2025' style Year column as a key
6. model.dim_season_types (PostgreSQL) -> DimSeasonType (Power BI) - same principle as DimSeasons - "Regular Season"/"Playoffs" for display, '1'/'2' as keys
7. DimDate - created in Power BI using CALENDAR() function - standard date dimension, marked as the date table to ensure time intelligence functions if needed

Original source keys (`PLAYER_ID`, `TEAM_ID`) are used throughout. Additional keys created by concatenating 2 or more columns as needed, e.g. model.dim_teams.team_year_key.


## Case study: the 1983–85 data-quality fix

**Issue:**
Advanced metrics for the 1983–84 and 1984–85 seasons seemed very inaccurate - Larry Bird's Net Rating was showing between -40 and -50, which is impossible for an MVP-caliber player.

**Investigation:**
The team box-score source was missing roughly 90% of its OREB / DREB / STL / BLK / TOV values for those two seasons.
Since PER and team ratings depend on those fields, the DAX measures were returning very inaccurate results.
A useful diagnostic clue: eFG% was unaffected, and since it depends only on made/attempted shots (not on the missing categories), this identified the rebounding/defensive columns as the cause.

**Potential solution:**
The player box scores (as opposed to team box scores) for the same seasons were far more complete (~1.5% data missing).
The team totals could therefore be **reconstructed by aggregating the player rows** for each team-game.

**Fix:**
A five-table chain of dependency within the model layer:

1. player_boxscores - the more-complete player grain chosen as the source
2. team_boxscores_base - the less-complete, official team box scores
3. team_boxscores_agg_team_only - built by aggregating player_boxscores to team-game grain
4. team_boxscores_agg - a self-join that adds opponent ('opp_' prefix) columns
5. team_boxscores - final team boxscores table, achieved by using COALESCE for each stat (if value exists in base team_boxscores_base, take it; if not, take it from team_boxscores_agg if it exists there)

After the fix, Larry Bird's ratings returned to realistic values, matching the Basketball-Reference numbers.

This is the part of the project I'm proudest of, because it's the kind of unglamorous data-engineering judgment that determines whether the numbers in the visuals will be correct or not.


## Stat completeness cutoff & era adjusted display

Not all stats exist since the 1946-47 season.
Steals and blocks weren't recorded before 1973–74; the three-point line didn't exist before 1979–80.
But even for a few more years after that, some stats were not gathered consistently (as mentioned above for years 1984-86).
By running a few deliberate SELECT queries, I determined that the data becomes complete from season 1983-84.

Rather than either (a) restricting the whole report to the modern era, or (b) showing visibly broken visuals for old-timers, the report degrades gracefully:

- A 'StatsCompleteFromYear = 1983' DAX constant filters most advanced metrics to seasons starting from 1983-84.
- It is integrated in these measures via 'CALCULATE(expression, KEEPFILTERS(DimSeason[Year] >= StatsCompleteFromYear))'.
- Simple counting stats (PTS, GP, Wins, and their derivatives) remain available for all seasons back to 1946.
- The "stats by season" table self-regulates - for a pre-1983 player, PTS/GP populate normally while most other columns simply read blank - understood naturally by users as "not available."
- Advanced panels (e.g. the radar chart) are hidden for players without 1983+ data (by using a measure that changes the color and opacity of a shape placed over the visuals). That way, Bill Russell shows a clean bio and a semi-filled table with no broken radar; MJ or Jokic show the full page.

A one-line note ("Advanced metrics and complete columns are available for seasons from 1983–84 onward, when the NBA's box-score data became complete.") appears in place of the hidden visuals once a pre 1983 player is selected and the visuals gone.
This solution demonstrates handling real-world data that isn't uniform or even available across all range.


## Dimensional modeling decisions

### Many-to-many relationship between FactPlayerBoxScore & FactTeamBoxScore
A player can appear for multiple teams within a single season (mid-season trades).
Filtering independently by season and team and season-type over-counts traded players.
This is because the dimension filters yield every season-team combination rather than just the games that the player actually played.

The fix is a concatenated composite key Year_Type_Team_Key (year & season-type & team), which make sure to connect without over-counting player rows.

### Bidirectional cross-filtering and a `CROSSFILTER` fix
The model uses bidirectional cross-filtering on most relationships, deliberately, so that slicers cross-filter one another (selecting a team narrows the player slicer to that team's players, and so on).
This makes filtering much more convenient and logical to report users.

Bidirectionality is always a risk, so in this case too, filters were filtering backward into certain complex measures.
The 'Current Team' measure was written to find the latest season league-wide, but was instead returning the selected player's last season, because selecting a player propagated backward through the facts into DimSeason.

To fix this, I kept bidirectionality globally for the slicer UX, but blocked only the backward path inside the specific measure with 'CROSSFILTER(DimSeason[Year], FactTeamBoxScore[Year], OneWay_LeftFiltersRight)'.
Lesson learned going forward - bidirectional relationships are OK, but always validate measure logic and results and apply CROSSFILTER to force one-direction relationship as needed.

### Team identity via a composite key
DimTeam uses keys per team-year combination, so that era-correct names and logos are used (the Lakers franchise spans both "Minneapolis Lakers" and "Los Angeles Lakers" under one TEAM_ID).

## The percentile radar ("Career Strengths")
The player page's radar is a career style/strengths profile - each axis is a 0–100 percentile rather than a raw stat, so every axis reads "higher = better" and players are comparable across eras.

The data needed for this radar chart was acquired by creating the table 'model.career_percentiles', which was created in these steps:
1. Per player-season totals and per-game rates, with a 1,000-minute season minimum to qualify, so to remove small-sample extremes
2. 'PERCENT_RANK() OVER (PARTITION BY year ORDER BY stat)' ranks each player against his contemporaries that season, which is crucial due to era-level differences.
3. Simple AVG() of the per-season percentiles per player gives the career figure.
	(a plain average is used rather than minutes-weighting: the minutes floor already removes noise, and the radar shape is effectively identical - weighting would add complexity for negligible gain)

**Axes (deliberately chosen):**
PTS, FG2M, FG3M, TS%, AST, REB, STL, BLK.
The 2PM/3PM split conveys shooting profile.
TS% conveys scoring efficiency (chosen over eFG% because it includes free throws and is more recognized by the fans).
AST/TOV was considered and dropped - a raw turnover figure conflates skill with usage and is archetype-ambiguous, so it fails the "higher = always better" requirement a radar axis needs.

The table is then joined into DimPlayer via a LEFT JOIN in SQL (as explained earlier, 1:1 relationship is more effective merged rather than connected as a separate table)
LEFT JOIN ensures that the pre-1983 and non-qualifying (low-minute) players keep their row with null percentiles rather than being lost from the crucial DimPlayer table.


## Audience-centric visuals

The player page is built around the idea that different audiences need different views of the same model.

1. **The season table** is curated to a fan-readable stats selection.
	It includes Season, team (logo & name), GP, MIN, PTS, AST, REB, STL, BLK, TS%, WS/48, PER - most columns understood at a glance, except the advanced TS%, PER, and WS/48.
	The advanced ones were included as they bring great value for the users who are aware of them.
	Deeper stats (USG%, raw TOV, FT splits, the full %-of-team family) are deliberately ignored here, rather than cluttering the visible table.
	They will be added to the report in later stages, as I add more pages.
2. **A single season-type control** achieved via three bookmark buttons (All Games, Regular Season and Playoffs) controls both the table and the trend combo chart together.
	That way, the two visuals always show same season type, instead of for instance one showing playoff stats and the other all games.
3. **Three registers, three jobs:** the table is the season detail, the radar is the career playing style/strengths, and the combo chart is the career development over time.
	Nothing overlaps, everything brings some different insight to the user.

More pages will be added to make good use of the advanced stats (Four Factors, %-of-team metrics, Win Shares components, usage, rates)
and stats that were not crucial to show on the quick career overview page (such as free-throw related stats, fouls, turnovers and other stats deliberately omitted from the career overview page).


## Data sourcing & ethics

- Data is scraped from the NBA.com stats API ('leaguegamelog' endpoint) via a Python scraper with daily updates.
- NBA stats scraping is widely accepted, but not formally licensed; that is why the NBA website is attributed on the sidebar and the NBA.com link and logo will be present on every report page.
- The project is only made for learning and portfolio-building purposes and won't be monetized in any way.
- Python is kept intentionally minimal (CSV/scrape only) - all transformation are done in SQL, consistent with the SQL-first approach.


## Tech stack

- **PostgreSQL** (DBeaver)
- **Power BI** (data model, DAX, visuals)
- **Python** (scraping/CSV utilities only)
- **CDN** (hosting logo images)


## Repository structure

- pbi/
	- example_measures.md
	- PBI_model.png
	- PBI_relationships.png
- sql/
	- 01_create_schemas.sql     			the 3 schemas
	- 02_raw_load.sql		      			raw tables and load raw data
	- 03_staging.sql			  			staging views (cleaned and typed)
	- 04_model_reference_tables.sql       reference tables such as name fixes and country codes
	- 05_model_dimensions.sql				dimension tables
	- 06_model_facts.sql                  fact tables
	- 07_model_derived.sql                model tables derived by joining other tables
	- 08_refresh_current_season.sql       steps to drop and recreate after getting updated source files
	- 09_checks.sql                       various checks to perform after rebuilding
	
	
**Note:** build/drop order matters - 'career_percentiles' must be built before 'dim_players', since the percentiles table is joined into the player dimension.


*Built as a portfolio project. Not affiliated with or endorsed by the NBA. Data used for educational purposes.*
