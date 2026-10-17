-- Task 2: Analyze playing activity and performance trends over time, identifying improvements and patterns

with trends_2026 as (
    select
        year,
        month,
        week,

        -- Key metrics
        count(session_id) as sessions_count,
        round(sum(kills) / sum(deaths), 2) as kdr,
        coalesce(round(sum(headshots) / sum(kills) * 100,2), 0) as hs_pct,
        round(sum(kills) / sum(session_duration_min), 2) as kills_per_min,

        -- Using windows functions to calculate cummulative sums, rolling averages, period-over-period changes
        round(count(session_id) /  sum(count(session_id)) over(), 2) as sessions_pct_share, 
        sum(count(session_id)) over( order by year, month, week) as cum_sessions_count,
        lag(round(sum(kills) / sum(deaths), 2), 1) over(order by year, month, week ) as prev_week_kdr,
        round((sum(kills) / sum(deaths)) - lag(sum(kills) / sum(deaths), 1) over(order by year, month, week ),2) as kdr_diff,

        -- Week-over-week kdr changes as percentages
        format('%.2f%%',
            safe_divide(
                (sum(kills) / sum(deaths)) - lag(sum(kills) / sum(deaths), 1) over(order by year, month, week ),
                lag(sum(kills) / sum(deaths), 1) over(order by year, month, week )
            ) * 100
        ) as kdr_pct_change,

        -- Rolling 4-week kdr
        round(safe_divide(
            sum(sum(kills)) over (order by year, month, week rows between 3 preceding and current row) ,
            sum(sum(deaths)) over (order by year, month, week rows between 3 preceding and current row) 
        ) , 2) as rolling_4_week_kdr

    from {{ ref('sessions') }}
    group by 1,2,3
    -- Selecting only current year for analysis
    having year = 2026
),

-- Compare current vs previous year performance
_2026_vs_2025 as (
    select
        year,
        count(session_id) as sessions_count,
        round(sum(kills) / sum(deaths), 2) as kdr,
        coalesce(round(sum(headshots) / sum(kills) * 100,2), 0) as hs_pct,
        round(sum(kills) / sum(session_duration_min), 2) as kills_per_min,
        round(safe_divide(sum(session_duration_min), 60),2) as playtime_hr,

        -- Distribution of sessions quality categories
        sum(case when session_quality = "Good" then 1 else null end) as good_sessions_count,
        sum(case when session_quality = "Average" then 1 else null end) as average_sessions_count,
        sum(case when session_quality = "Poor" then 1 else null end) as poor_sessions_count

    from {{ ref('sessions') }}
    group by 1
)

select *
from _2026_vs_2025
order by 1


-- RESULTS:

-- PERFORMANCE TRENDS
-- 66 sessions in 2026, with peak activity in March (11) and September (9).
-- KDR fluctuated from 0.50 to 2.43, ending at 1.56.
-- Rolling KDR recovered from 1.25 to 1.36 in the latest periods.
-- KPM ended at 1.39, while HS% fell to 57.14%, its lowest recorded level.

-- KEY TAKEAWAY
-- Recent KDR and KPM improved, but remained below the opening period.
-- Performance varied considerably, with many periods containing few sessions.

--

-- YEAR-OVER-YEAR COMPARISON
-- Sessions increased by 50%, while playtime grew by 24.6%.
-- KDR declined by 6.4% and KPM by 5%, while HS% rose by 1.64 pp.
-- Poor sessions increased from 12 to 30 (27.3% to 45.5%).

-- YEARLY PERFORMANCE
-- 2025: 44 sessions | KDR 1.56 | HS 76.17% | KPM 1.20 | 19.30 hours.
-- 2026: 66 sessions | KDR 1.46 | HS 77.81% | KPM 1.14 | 24.04 hours.

-- KEY TAKEAWAY
-- Higher activity in 2026 accompanied weaker KDR and KPM.
-- Poor sessions became more common despite higher overall HS%.
