use trips_db;
-- BR1
select dc.city_id,
	   dc.city_name,
	   count(ft.trip_id) as total_trips,
	   sum(ft.fare_amount)/sum(ft.distance_travelled_km) as avg_fare_per_km,
	   sum(ft.fare_amount)/count(ft.trip_id) as avg_fare_per_trip,
	   100*count(ft.trip_id)/(select count(trip_id) from fact_trips) as percentage_contribution_to_total_trips
from trips_db.dim_city as dc
join trips_db.fact_trips as ft
on dc.city_id = ft.city_id
group by city_id;

-- BR2
with monthly_city_level_trips_target_evaluation as(
	select dc.city_name,
		   dd.month_name,
		   count(ft.trip_id) as actual_trips,
		   mtt.total_target_trips as target_trips
	from trips_db.fact_trips as ft
	join trips_db.dim_city as dc on dc.city_id = ft.city_id
	join trips_db.dim_date as dd on dd.date = ft.date
	join targets_db.monthly_target_trips as mtt on mtt.city_id = ft.city_id and dd.start_of_month = mtt.month
	group by dc.city_name,dd.month_name,mtt.total_target_trips
)
select *, 
	   case when actual_trips>target_trips then 'above target'
			else 'below target'
	   end as performance_status,
       100*(actual_trips - target_trips)/target_trips as percentage_difference
from monthly_city_level_trips_target_evaluation;

-- BR3
SELECT dc.city_name,
    100 * SUM(CASE WHEN drtd.trip_count = '2-Trips' THEN drtd.repeat_passenger_count ELSE 0 END) / total_repeat_passenger_count as '2-Trips',
    100 * SUM(CASE WHEN drtd.trip_count = '3-Trips' THEN drtd.repeat_passenger_count ELSE 0 END) / total_repeat_passenger_count as '3-Trips',
    100 * SUM(CASE WHEN drtd.trip_count = '4-Trips' THEN drtd.repeat_passenger_count ELSE 0 END) / total_repeat_passenger_count as '4-Trips',
    100 * SUM(CASE WHEN drtd.trip_count = '5-Trips' THEN drtd.repeat_passenger_count ELSE 0 END) / total_repeat_passenger_count as '5-Trips',
    100 * SUM(CASE WHEN drtd.trip_count = '6-Trips' THEN drtd.repeat_passenger_count ELSE 0 END) / total_repeat_passenger_count as '6-Trips',
    100 * SUM(CASE WHEN drtd.trip_count = '7-Trips' THEN drtd.repeat_passenger_count ELSE 0 END) / total_repeat_passenger_count as '7-Trips',
    100 * SUM(CASE WHEN drtd.trip_count = '8-Trips' THEN drtd.repeat_passenger_count ELSE 0 end) / total_repeat_passenger_count as '8-Trips',
    100 * SUM(CASE WHEN drtd.trip_count = '9-Trips' THEN drtd.repeat_passenger_count ELSE 0 end) / total_repeat_passenger_count as '9-Trips',
    100 * SUM(CASE WHEN drtd.trip_count = '10-Trips' THEN drtd.repeat_passenger_count ELSE 0 end) / total_repeat_passenger_count as '10-Trips'
from trips_db.dim_city as dc
join (select city_id, sum(repeat_passenger_count) as total_repeat_passenger_count 
     from trips_db.dim_repeat_trip_distribution 
     group by city_id) as total_counts on dc.city_id = total_counts.city_id
join trips_db.dim_repeat_trip_distribution as drtd on dc.city_id = drtd.city_id
group by dc.city_name, total_repeat_passenger_count;

-- BR4
with city_totals as (
    select dc.city_name,
           sum(fps.new_passengers) as total_new_passengers
    from trips_db.fact_passenger_summary as fps
    join trips_db.dim_city as dc on dc.city_id = fps.city_id
    group by dc.city_name
),
top_3_cities as (
    select city_name, 
           total_new_passengers, 
           'Top 3' as city_category
    from city_totals
    order by total_new_passengers desc
    limit 3
),
bottom_3_cities as (
    select city_name, 
           total_new_passengers, 
           'Bottom 3' as city_category
    from city_totals
    order by total_new_passengers asc
    limit 3
)
select * from top_3_cities
union
select * from bottom_3_cities;

-- BR5
WITH city_monthly_revenue AS (
    select dc.city_name,
           dd.month_name,
           sum(ft.fare_amount) as revenue,
           100*(sum(ft.fare_amount) / (
            select sum(fare_amount) 
            from trips_db.fact_trips as ft_inner
            join trips_db.dim_city as dc_inner on dc_inner.city_id = ft_inner.city_id
            where dc_inner.city_name = dc.city_name
            ))as percentage_contribution
    from trips_db.fact_trips as ft
    join trips_db.dim_city as dc on dc.city_id = ft.city_id
    join trips_db.dim_date as dd on dd.date = ft.date
    group by dc.city_name, dd.month_name
),
city_highest_revenue_month as (
    select city_name,
           month_name,
           revenue,
           percentage_contribution,
           rank() over(partition by city_name order by revenue desc) as rnk
    from
        city_monthly_revenue
)
select city_name,
       month_name as highest_revenue_month,
       revenue,
       percentage_contribution
from city_highest_revenue_month
where rnk = 1;

-- BR6
with monthly_passenger_rate_cte as(
	select dc.city_name,
		   dd.start_of_month as month,
           dd.month_name,
           fps.total_passengers,
           fps.repeat_passengers,
           100*(fps.repeat_passengers/fps.total_passengers) as monthly_repeat_passenger_rate
	from trips_db.fact_passenger_summary as fps
    join trips_db.dim_city as dc on dc.city_id = fps.city_id
    join trips_db.dim_date as dd on dd.start_of_month = fps.month
),
city_passenger_rate_cte as(
	select dc.city_name,
		   100*sum(fps.repeat_passengers)/sum(fps.total_passengers) as city_passenger_rate
	from trips_db.fact_passenger_summary as fps
    join trips_db.dim_city as dc on dc.city_id = fps.city_id
    group by dc.city_name
)
select distinct m.*, c.city_passenger_rate
from monthly_passenger_rate_cte as m
join city_passenger_rate_cte as c on c.city_name = m.city_name
order by m.city_name, m.month;