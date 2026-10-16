-- Reusable source table with calculated columns for sessions analysis

select 
    session_id,

    -- Date and time columns
    session_start,
    session_end,
    extract(year from session_start) as year,
    extract(month from session_start) as month,
    extract(week from session_start) as week,
    format_date("%A", session_start) as day_of_week,
    case when extract(dayofweek from session_start) in (1, 7) then 1 else 0 end as is_weekend,
    extract(hour from session_start) as hour,
    timestamp_diff(session_end, session_start, minute) as session_duration_min,

    -- Using conditional logic to creating categorical values
    case
        when extract(hour from session_start) between 6 and 11 then 'Morning'
        when extract(hour from session_start) between 12 and 17 then 'Afternoon'
        when extract(hour from session_start) between 18 and 23 then 'Evening'
        else 'Night'
    end as day_part,    

    case
        when timestamp_diff(session_end, session_start, minute) <= 10 then "Short"
        when timestamp_diff(session_end, session_start, minute) <= 45 then "Medium"
        else "Long"
    end as duration_category,

    -- Stats columns
    kills,
    deaths,
    headshots,
    round(safe_divide(kills, deaths), 2) as session_kdr,
    coalesce(round(safe_divide(headshots, kills) * 100,2), 0) as session_hs_pct, 
    round(safe_divide(kills, timestamp_diff(session_end, session_start, minute)),2) as session_kills_per_minute,

    case 
        when safe_divide(kills, deaths) >= 1.5 and safe_divide(headshots, kills) >= 0.7 then "Good"
        when safe_divide(kills, deaths) >= 1.0 and safe_divide(headshots, kills) >= 0.5 then "Average"
        else "Poor"
    end as session_quality

from {{ source(env_var('DATASET_NAME'), 'my_sessions') }}
-- Remove sessions without any activity (no kills or deaths)
where (kills > 0 or deaths > 0)
order by session_id asc
