with tmp_errors as (
    select distinct order_id
    from factdata.errors
    where external_flag = TRUE
)


select customer_orders.customer_order_id,
       customer_orders.date_placed,
       datediff('d', customer_orders.date_placed, customer_orders.date_delivered) days_deliverd,
       customer_orders.net_price,
       customer_orders.total_units,
       count(distinct designs.design_id)                                          designs_prior_30,
       nvl2(tmp_errors.order_id, 1, 0)                                            errors,
       round(median_household_income::numeric(20) * population::numeric(20))      zip_wealth,
       segment_name_uber,
       case
           when segment_name_uber in ('Friends & Family', 'All Athletics', 'Organizations')
               then 'Family, Org, & Athletics'
           else segment_name_uber end                                    as       segment_name_ultra,
       case
           when segment_name_ultra = 'Family, Org, & Athletics' then 1
           when segment_name_ultra = 'Students & Schools' then 2
           else 3 end                                                             segment_rank_ultra,
       style_uber_category,
       case
           when style_uber_category != 'Casual Apparel' then 'Remaining Apparel'
           else style_uber_category end                                  as       style_category_utlra,
       case
           when sales_channel_attributed in ('KAM', 'NAM', 'Outreach') then 'Proactive Channel'
           else 'Reactive Channel' end                                   as       uber_sales_channel_attr,
       case when uber_sales_channel_attr = 'Proactive' then 2 else 1 end as       uber_channel_attr_rank,
       case
           when sales_channel_placed in ('KAM', 'NAM', 'Outreach') then 'Proactive Channel'
           else 'Reactive Channel' end                                   as       uber_sales_channel_placed,
       sales_bulk_following_365                                                   sales_bulk_following_365
from general_use.customer_orders
         join general_use.customer_orders_purchase_window using (customer_order_id)
         join general_use.customer_orders_segmentation using (customer_order_id)
         join general_use.customer_orders_products using (customer_order_id)
         left join factdata.designs
                   on customer_account_id = account_id
                       and
                      convert_timezone('America/New_York', date_design_saved) between timestamp_placed - 30 and timestamp_placed
         left join tmp_errors
                   on customer_order_id = order_id
         left join factdata.orders
                   on customer_order_id = orders.order_id
         left join factdata.dim_address bill_address
                   on bill_address_id = address_id
         left join rawdata.static_zip_to_zcta
                   on left(bill_address.zipcode, 5) = static_zip_to_zcta.zipcode
         left join rawdata.static_household_income
                   on static_zip_to_zcta.zcta = static_household_income.zipcode
                       and customer_orders.date_placed between date_census_start and date_census_end
where is_fix = 0
  and is_canceled = 0
  and business_line = 'Bulk'
  -- look at a customer's first purchase only
  and prior_bulk_purchase_date is null
  -- look only at customers who had a repeat order within a year
  and days_to_next_bulk_purchase <= 365
  and sales_bulk_following_365 > 0
  -- pull data from two years before COVID started
  and customer_orders.date_placed < dateadd('day', -365, '2020-03-01')
  and customer_orders.date_placed >= dateadd('day', -365 * 2, '2020-03-01')
  and segment_name_uber not in ('None', 'Ignore')
  and style_uber_category not in ('Health & Wellness', 'None')
  and customer_orders.net_price > 0
  and customer_orders.date_delivered is not null
  and median_household_income is not null
group by 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17
limit 500
