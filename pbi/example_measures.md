# Example DAX measures used in the 'NBA Player Stats.pbix' report

## 1. Foundational measures

tm_gp = COUNTROWS(FactTeamBoxScore)

mov = DIVIDE([tm_pts] - [opp_pts], [tm_gp])


## 2. The advanced metrics - PER chain

PER implemented as a multi-measure chain following Hollinger's formula; validated against Basketball-Reference within ~0.1

per = 
VAR Cutoff = [StatsCompleteFromYear]
VAR MpgFloor = [PER_MPG_Minimum]            -- minimum minutes per game to make displaying PER make sense
VAR TeamGames = [tm_gp]                     -- games that the player's team played in current filter context
VAR MinutesFloor = MpgFloor * TeamGames
RETURN
CALCULATE(
    IF([p_min] >= MinutesFloor, [a_per] * DIVIDE(15, [lga_per])),
    KEEPFILTERS(DimSeason[Year] >= Cutoff)
)

a_per = 
VAR Cutoff = [StatsCompleteFromYear]
RETURN
CALCULATE(
    CALCULATE(
    [u_per] * DIVIDE([lg_pace], [pace])
    ),
    KEEPFILTERS(DimSeason[Year] >= Cutoff)
)

lga_per = 
VAR Cutoff = [StatsCompleteFromYear]
RETURN
CALCULATE(
    CALCULATE(
    DIVIDE(
        CALCULATE(
            [a_per] * [p_min],
            REMOVEFILTERS(DimPlayer),
            REMOVEFILTERS(FactPlayerBoxScore),
            REMOVEFILTERS(FactTeamBoxScore),
            KEEPFILTERS(VALUES(FactTeamBoxScore[Season_Type_Key])),
            KEEPFILTERS(VALUES(FactTeamBoxScore[Year]))
        ),
        CALCULATE (
            [p_min],
            REMOVEFILTERS(DimPlayer),
            REMOVEFILTERS(FactPlayerBoxScore),
            REMOVEFILTERS(FactTeamBoxScore),
            KEEPFILTERS(VALUES(FactTeamBoxScore[Season_Type_Key])),
            KEEPFILTERS(VALUES(FactTeamBoxScore[Year]))
        )
    )
    ),
    KEEPFILTERS(DimSeason[Year] >= Cutoff)
)

u_per = 
VAR Cutoff = [StatsCompleteFromYear]
RETURN
CALCULATE(
    VAR _factor =
    CALCULATE(
        [factor],
        REMOVEFILTERS(FactPlayerBoxScore),
        REMOVEFILTERS(FactTeamBoxScore),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Season_Type_Key])),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Year]))
    )

VAR _vop =
    CALCULATE(
        [vop],
        REMOVEFILTERS(FactPlayerBoxScore),
        REMOVEFILTERS(FactTeamBoxScore),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Season_Type_Key])),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Year]))
    )

VAR _lg_dreb =
    CALCULATE(
        [lg_dreb%],
        REMOVEFILTERS(FactPlayerBoxScore),
        REMOVEFILTERS(FactTeamBoxScore),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Season_Type_Key])),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Year]))
    )

VAR _lg_ftm_pf =
    CALCULATE(
        DIVIDE([lg_ftm], [lg_pf]),
        REMOVEFILTERS(FactPlayerBoxScore),
        REMOVEFILTERS(FactTeamBoxScore),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Season_Type_Key])),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Year]))
    )

VAR _lg_fta_pf =
    CALCULATE(
        DIVIDE([lg_fta], [lg_pf]),
        REMOVEFILTERS(FactPlayerBoxScore),
        REMOVEFILTERS(FactTeamBoxScore),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Season_Type_Key])),
        KEEPFILTERS(VALUES(FactTeamBoxScore[Year]))
    )

RETURN
CALCULATE(
    DIVIDE(1, [p_min]) *
        (
            [p_3pm]
            + (2/3) * [p_ast]
            + ( 2 - _factor * DIVIDE([tm_ast], [tm_fgm]) ) * [p_fgm]
            +
            (
                [p_ftm] * 0.5 *
                (
                    1
                    + (1 - DIVIDE([tm_ast], [tm_fgm]))
                    + (2/3) * DIVIDE([tm_ast], [tm_fgm])
                )
            )
            - _vop * [p_tov]
            - _vop * _lg_dreb * ([p_fga] - [p_fgm])
            - _vop *
                0.44 * (0.44 + 0.56 * _lg_dreb) *
                ([p_fta] - [p_ftm])
            + _vop * (1 - _lg_dreb) * ([p_reb] - [p_oreb])
            + _vop * _lg_dreb * [p_oreb]
            + _vop * [p_stl]
            + _vop * _lg_dreb * [p_blk]
            - [p_pf] *
                (
                    _lg_ftm_pf
                    - 0.44 * _lg_fta_pf * _vop
                )
        )
    ),
    KEEPFILTERS(DimSeason[Year] >= Cutoff)
)


## 3. The CROSSFILTER fix

Current Team = 
VAR LastYear = SELECTEDVALUE(DimPlayer[Played To])
VAR CurrentYear =
    CALCULATE(
        MAX(DimSeason[Year]),
        REMOVEFILTERS(DimSeason),
        REMOVEFILTERS(DimDate),
        CROSSFILTER(DimSeason[Year],FactTeamBoxScore[Year],OneWay_LeftFiltersRight)
    )
VAR LastGamePlayedDate =
    CALCULATE(
        MAX(FactPlayerBoxScore[Game Date]),
        REMOVEFILTERS(DimSeason),
        REMOVEFILTERS(DimDate)
    )
VAR LatestTeamYearKey =
    CALCULATE(
        SELECTEDVALUE(FactPlayerBoxScore[Team_Year_Key]),
        FactPlayerBoxScore[Game Date] = LastGamePlayedDate,
        REMOVEFILTERS(DimSeason),
        REMOVEFILTERS(DimDate)
    )
VAR LatestTeam =
    CALCULATE(
        SELECTEDVALUE(DimTeam[Team]),
        DimTeam[Team_Year_Key] = LatestTeamYearKey,
        REMOVEFILTERS(DimSeason),
        REMOVEFILTERS(DimDate)
    )
RETURN
IF(
    LastYear < CurrentYear,
    "Retired",
    LatestTeam
)


## 4. The reliability-cutoff pattern

StatsCompleteFromYear = 1983 -- stats prior to season 1983-84 are often missing; this will be used to filter out older season in most measures

ws_48 = 
VAR Cutoff = [StatsCompleteFromYear]
RETURN
CALCULATE(
    DIVIDE([ws], [p_min]) * 48,
    KEEPFILTERS(DimSeason[Year] >= Cutoff)
)


## 5. Other advanced measures

p_ts% = 
VAR Cutoff = [StatsCompleteFromYear]
RETURN
CALCULATE(
    DIVIDE(
    [p_pts],
    2 * ([p_fga] + 0.44 * [p_fta])),
    KEEPFILTERS(DimSeason[Year] >= Cutoff)
) * 100

tm_poss = 
VAR Cutoff = [StatsCompleteFromYear]
RETURN
CALCULATE(
    0.5 *
    (
    [tm_fga]
    + 0.4 * [tm_fta]
    - 1.07 * DIVIDE([tm_oreb], [tm_oreb] + [opp_dreb]) * ([tm_fga] - [tm_fgm])
    + [tm_tov]
    +
    [opp_fga]
    + 0.4 * [opp_fta]
    - 1.07 * DIVIDE([opp_oreb], [opp_oreb] + [tm_dreb]) * ([opp_fga] - [opp_fgm])
    + [opp_tov]
    ),
    KEEPFILTERS(DimSeason[Year] >= Cutoff)
)


## 6. A display/UX measure

Hide Advanced Stats = 
IF(
    SELECTEDVALUE(DimPlayer[Played To]) < [StatsCompleteFromYear],
    "#DFE3EC",
    "#00000000"
)

Missing Visuals Disclaimer = 
IF(
    SELECTEDVALUE(DimPlayer[Played To]) < [StatsCompleteFromYear],
    "Advanced metrics and complete columns are available for seasons from 1983–84 onward, when the NBA's box-score data became complete.",
    ""
)

Height & Weight Display = 
SELECTEDVALUE(DimPlayer[Height (in)]) & " (" & SELECTEDVALUE(DimPlayer[Height (cm)]) & " cm) • " &
SELECTEDVALUE(DimPlayer[Weight (lbs)]) & " lbs (" & SELECTEDVALUE(DimPlayer[Weight (kg)]) & " kg)"