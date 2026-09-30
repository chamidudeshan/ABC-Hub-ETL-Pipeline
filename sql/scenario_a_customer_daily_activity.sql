SELECT
    c.customer_id,
    d.activity_date,
    ca.city_id,
    COALESCE(s.streaming_sessions, 0)          AS streaming_sessions,
    COALESCE(s.total_streaming_duration, 0)    AS total_streaming_duration,
    COALESCE(r.physical_rentals, 0)             AS physical_rentals,
    COALESCE(r.returned_items, 0)                AS returned_items,
    COALESCE(p.total_amount_spent, 0)           AS total_amount_spent,
    COALESCE(t.support_tickets_raised, 0)       AS support_tickets_raised
FROM customer c
LEFT JOIN (
    SELECT DISTINCT ON (customer_id) customer_id, city_id
    FROM customer_address
    ORDER BY customer_id, address_id DESC
) ca ON ca.customer_id = c.customer_id
CROSS JOIN (
    SELECT DISTINCT activity_date FROM (
        SELECT CAST(start_time AS DATE) AS activity_date FROM streaming_session
        UNION
        SELECT rental_date FROM rental
        UNION
        SELECT CAST(payment_date AS DATE) FROM payment
        UNION
        SELECT CAST(opened_date AS DATE) FROM support_ticket
    ) all_dates
) d
LEFT JOIN (
    SELECT customer_id, CAST(start_time AS DATE) AS activity_date,
           COUNT(*) AS streaming_sessions,
           SUM(COALESCE(watch_duration,0)) AS total_streaming_duration
    FROM streaming_session
    GROUP BY customer_id, CAST(start_time AS DATE)
) s ON s.customer_id = c.customer_id AND s.activity_date = d.activity_date
LEFT JOIN (
    SELECT customer_id, rental_date AS activity_date,
           COUNT(*) AS physical_rentals,
           COUNT(*) FILTER (WHERE return_date IS NOT NULL) AS returned_items
    FROM (
        SELECT DISTINCT ON (inventory_id, rental_date, return_date)
               rental_id, customer_id, inventory_id, rental_date, return_date
        FROM rental
        ORDER BY inventory_id, rental_date, return_date, rental_id
    ) deduped_rentals
    GROUP BY customer_id, rental_date
) r ON r.customer_id = c.customer_id AND r.activity_date = d.activity_date
LEFT JOIN (
    SELECT customer_id, CAST(payment_date AS DATE) AS activity_date,
           SUM(amount) AS total_amount_spent
    FROM (
        SELECT DISTINCT ON (customer_id, rental_id, subscription_id, amount, payment_date)
               customer_id, rental_id, subscription_id, amount, payment_date
        FROM payment
        WHERE status = 'Completed'
        ORDER BY customer_id, rental_id, subscription_id, amount, payment_date, payment_id
    ) deduped_payments
    GROUP BY customer_id, CAST(payment_date AS DATE)
) p ON p.customer_id = c.customer_id AND p.activity_date = d.activity_date
LEFT JOIN (
    SELECT customer_id, CAST(opened_date AS DATE) AS activity_date,
           COUNT(*) AS support_tickets_raised
    FROM support_ticket
    GROUP BY customer_id, CAST(opened_date AS DATE)
) t ON t.customer_id = c.customer_id AND t.activity_date = d.activity_date
WHERE s.customer_id IS NOT NULL OR r.customer_id IS NOT NULL
   OR p.customer_id IS NOT NULL OR t.customer_id IS NOT NULL;


INSERT INTO analytics.fact_customer_daily_activity
  (customer_key, date_key, subscription_key, location_key,
   streaming_sessions, total_streaming_duration, physical_rentals,
   returned_items, total_amount_spent, support_tickets_raised)
SELECT
    dc.customer_key,
    TO_CHAR(s.activity_date, 'YYYYMMDD')::INT,
    ds.subscription_key,
    dl.location_key,
    s.streaming_sessions,
    s.total_streaming_duration,
    s.physical_rentals,
    s.returned_items,
    s.total_amount_spent::DECIMAL,
    s.support_tickets_raised
FROM analytics.stg_fact_customer_daily_activity s
JOIN analytics.dim_customer dc ON dc.customer_id = s.customer_id
LEFT JOIN analytics.dim_subscription ds ON ds.customer_id = s.customer_id AND ds.status = 'Active'
LEFT JOIN analytics.dim_location dl ON dl.city_id = s.city_id
ON CONFLICT (customer_key, date_key) DO UPDATE SET
    streaming_sessions = EXCLUDED.streaming_sessions,
    total_streaming_duration = EXCLUDED.total_streaming_duration,
    physical_rentals = EXCLUDED.physical_rentals,
    returned_items = EXCLUDED.returned_items,
    total_amount_spent = EXCLUDED.total_amount_spent,
    support_tickets_raised = EXCLUDED.support_tickets_raised;

