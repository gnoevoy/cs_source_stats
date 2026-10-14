
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
)

select
    day_of_week,
    is_weekend,
    
from source_df
order by 1 asc

