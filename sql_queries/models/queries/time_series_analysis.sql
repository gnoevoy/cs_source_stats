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
from trends_2026
order by 1,2,3


-- Results:

-- PERFORMANCE TRENDS
-- 99 sessions in 2026, with peak activity in March and September.
-- KDR generally declined from 2.43 to 1.57, with noticeable fluctuations.
-- Rolling KDR dropped to 1.27, indicating weaker recent performance.
-- HS% remained relatively strong, mostly between 75–90%.
-- KPM declined from 1.51 to 1.24, suggesting lower combat efficiency.

-- KEY TAKEAWAY
-- Performance weakened overall despite consistently strong headshot accuracy.
-- Higher playing activity did not consistently lead to better results.

--

-- YEAR-OVER-YEAR COMPARISON
-- Sessions increased by 37.5%, while playtime grew by 23.8%.
-- KDR declined by 6.4% and KPM by 5%, while HS% improved by 1.82 pp.
-- Poor sessions increased from 19 to 37 (26.4% to 37.4%).

-- YEARLY PERFORMANCE
-- 2025: 72 sessions | KDR 1.56 | HS 76.17% | KPM 1.20 | 19.23 hours.
-- 2026: 99 sessions | KDR 1.46 | HS 77.99% | KPM 1.14 | 23.80 hours.

-- KEY TAKEAWAY
-- Higher activity in 2026, but slightly weaker overall performance.
-- More frequent Poor sessions despite improved headshot accuracy.