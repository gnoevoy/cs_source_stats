-- Task 1: Evaluate overall gaming performance using key metrics such as KDR, HS%, kills per minute

with source_df as (
    select
        session_quality,
        duration_category,

        count(session_id) as sessions_count,
        sum(kills) as total_kills,
        sum(deaths) as total_deaths,
        sum(headshots) as total_headshots,
        sum(session_duration_min) as playtime_min,

        -- Calculate key metrics for each aggregation group
        round(safe_divide(sum(kills), sum(deaths)), 2) as kdr,
        coalesce(round(safe_divide(sum(headshots), sum(kills)) * 100,2), 0) as hs_pct,
        round(safe_divide(sum(session_duration_min), 60),2) as playtime_hr,
        round(safe_divide(sum(kills), sum(session_duration_min)), 2) as kills_per_min

    from {{ ref('sessions') }}
    group by 1,2
),

-- Generate unique combinations of 2 columns
all_combinations as (
    select *
    from (select distinct session_quality from {{ ref('sessions') }})
    cross join (select distinct duration_category from {{ ref('sessions') }})
)

select
    t1.session_quality,
    t1.duration_category,
    coalesce(sessions_count,0) as sessions_count,
    kdr,
    hs_pct,
    playtime_hr,
    kills_per_min,

    -- Using window functions to get rankings and overall stats
    dense_rank() over(partition by t1.session_quality order by kdr desc) as kdr_rank,
    sum(sessions_count) over() as overall_sessions_count,
    round(safe_divide(sum(total_kills) over() , sum(total_deaths) over()), 2) as overall_kdr,
    round(safe_divide(sum(total_headshots) over() , sum(total_kills) over()) * 100, 2) as overall_hs_pct,
    round(safe_divide(sum(playtime_min) over() , 60), 2) as overall_playtime_hr,
    round(safe_divide(sum(total_kills) over(), sum(playtime_min) over()), 2) as overall_kills_per_min

-- Join 2 tables to get stats with all possible combinations of categorical values
from all_combinations as t1
left join source_df as t2
    on t1.session_quality = t2.session_quality and t1.duration_category = t2.duration_category

order by t1.session_quality, kdr_rank


-- RESULTS:

-- OVERALL PERFORMANCE
-- 110 sessions | 43.34 hours | KDR: 1.50 | HS: 77.06% | KPM: 1.17.

-- SESSION DISTRIBUTION
-- Good: 24 (21.8%) | Average: 44 (40.0%) | Poor: 42 (38.2%).
-- Average sessions account for ~56% of total playtime.
-- Short: 51 (46.4%) | Medium: 39 (35.5%) | Long: 20 (18.2%).

-- PERFORMANCE INSIGHTS
-- Good + Short: highest KDR (2.45), HS% (88.54%), and KPM (1.47).
-- Poor + Short: lowest KDR (0.78) and KPM (0.63).
-- KDR decreases with duration in Good and Average groups, but increases in the Poor group.
-- Short sessions account for 71.4% of Poor sessions.

-- KEY TAKEAWAY
-- Short sessions show the widest performance differences.
-- Session duration and high HS% alone do not determine performance quality.
