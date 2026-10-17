-- Task 4: Analyze consecutive Good, Average, and Poor sessions to understand performance consistency and streak patterns.

with prev_sessions_cte as (
    select
        session_id,
        session_quality,
        session_duration_min,
        kills,
        deaths,
        headshots,
        -- Get previous session quality category for comparison
        lag(session_quality) over (order by session_id asc) as prev_session
    from {{ ref('sessions') }}
),

streak_start_cte as (
    select *, case when prev_session is null or session_quality <> prev_session then 1 else 0 end as is_streak_start
    from prev_sessions_cte
),

-- Use cummulative sum technique to assign streak IDs
streak_ids_cte as (
    select *, sum(is_streak_start) over (order by session_id asc) as streak_id
    from streak_start_cte
),

streaks_level_cte as (
    select
        streak_id,
        max(session_quality) as session_quality_category,
        count(*) as streak_length,
        sum(kills) as streak_kills,
        sum(deaths) as streak_deaths,
        sum(headshots) as streak_headshots,
        sum(session_duration_min) as streak_playtime_min
    from streak_ids_cte
    group by 1
)

select
    session_quality_category as session_quality,

    -- Calculate key metrics to assess streak consistency
    count(streak_id) as streaks_count,
    count(case when streak_length >= 3 then 1 else null end) as multi_session_streaks,

    round(avg(streak_length),2) as avg_streaks_lenght,
    min(streak_length) as min_streaks_lenght,
    max(streak_length) as max_streaks_lenght,

    round(safe_divide(sum(streak_playtime_min), 60),2) as playtime_hr,
    round(safe_divide(sum(streak_playtime_min) , count(streak_id)),2) as avg_playtime_min,

    round(safe_divide(sum(streak_kills), sum(streak_deaths)), 2) as avg_kdr,
    coalesce(round(safe_divide(sum(streak_headshots), sum(streak_kills)) * 100,2), 0) as avg_hs_pct,
    round(safe_divide(sum(streak_kills), sum(streak_playtime_min)), 2) as avg_kills_per_min
    
from streaks_level_cte
group by 1
order by streaks_count desc


-- RESULTS:

-- STREAK ANALYSIS
-- Average streaks are most common: 31, followed by Poor (25) and Good (20).
-- Poor streaks have the most multi-session runs (4) and longest run (5 sessions).
-- Good streaks are shortest on average (1.20 sessions), with a maximum of 3.
-- Average streaks have the most playtime per streak (46.65 min), compared with Good (30.50 min) and Poor (21.78 min).
-- Good streaks: KDR 2.22 | HS 79.50% | KPM 1.43.
-- Poor streaks: KDR 0.94 | HS 78.25% | KPM 0.82.

-- KEY TAKEAWAY
-- Poor performance persists across more consecutive sessions, while Good streaks are less frequent and shorter.
-- Similar HS% in Good and Poor groups contrasts with large KDR and KPM differences.
