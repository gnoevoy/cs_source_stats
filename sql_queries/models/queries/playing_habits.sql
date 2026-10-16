-- Task 3: Analyze playing habits and performance patterns across weekdays and times of day to identify when I play most frequently and perform best.

-- Creating matrix (day of week x time of day) with aggregated values
with source_df as (
    select *
    from (select day_of_week, is_weekend, day_part, session_id, kills, deaths, headshots, session_duration_min from {{ ref('sessions') }})
    pivot (
        count(session_id) as sessions_count,
        sum(kills) as total_kills,
        sum(deaths) as total_deaths,
        sum(headshots) as total_headshots,
        sum(session_duration_min) as playtime_min
        for day_part in ( "Morning" , "Afternoon" , "Evening" , "Night")
    )
),

-- Table with focus on sessions volumes and playtime
playing_frequency as (
    select
        day_of_week,
        is_weekend,

        -- Calculation for each part of the day
        sessions_count_Morning,
        round(safe_divide(playtime_min_Morning, 60),2) as playtime_hr_Morning,
        round(safe_divide(playtime_min_Morning, sessions_count_Morning),2) as avg_duration_min_Morning,

        sessions_count_Afternoon,
        round(safe_divide(playtime_min_Afternoon, 60),2) as playtime_hr_Afternoon,
        round(safe_divide(playtime_min_Afternoon, sessions_count_Afternoon),2) as avg_duration_min_Afternoon,

        sessions_count_Evening,
        round(safe_divide(playtime_min_Evening, 60),2) as playtime_hr_Evening,
        round(safe_divide(playtime_min_Evening, sessions_count_Evening),2) as avg_duration_min_Evening,

        sessions_count_Night,
        round(safe_divide(playtime_min_Night, 60),2) as playtime_hr_Night,
        round(safe_divide(playtime_min_Night, sessions_count_Night),2) as avg_duration_min_Night,

    from source_df
),

playing_performance as (
    select
        day_of_week,
        is_weekend,

        round(safe_divide(total_kills_Morning, total_deaths_Morning),2) as kdr_Morning,
        round(safe_divide(total_kills_Morning, playtime_min_Morning),2) as kills_per_min_Morning,

        round(safe_divide(total_kills_Afternoon, total_deaths_Afternoon),2) as kdr_Afternoon,
        round(safe_divide(total_kills_Afternoon, playtime_min_Afternoon),2) as kills_per_min_Afternoon,

        round(safe_divide(total_kills_Evening, total_deaths_Evening),2) as kdr_Evening,
        round(safe_divide(total_kills_Evening, playtime_min_Evening),2) as kills_per_min_Evening,

        round(safe_divide(total_kills_Night, total_deaths_Night),2) as kdr_Night,
        round(safe_divide(total_kills_Night, playtime_min_Night),2) as kills_per_min_Night,

    from source_df
)

select *
from playing_performance
order by 1 asc


-- Results:

-- PLAYING HABITS & PERFORMANCE
-- Evening dominates activity: 125 sessions (~73%).
-- Saturday leads with 51 sessions, followed by Friday (32).
-- Weekend sessions account for ~46% of total activity.
-- Friday and Saturday are the most active days.

-- PERFORMANCE INSIGHTS
-- Saturday afternoon: strong KDR (2.49) and KPM (1.47).
-- Friday afternoon: KDR 1.64 | KPM 1.44.
-- Saturday evening: 35 sessions, but lower KDR (1.38).
-- Thursday evening: weaker KDR (1.24) and KPM (1.04).
-- Night KDR peaks on Tuesday (4.0) and Monday (3.27).
-- Both night peaks are based on only 1 session.

-- KEY TAKEAWAY
-- Activity is concentrated on weekend evenings.
-- Higher activity does not guarantee better performance.
-- Afternoons generally show stronger combat efficiency.
