SELECT
    c.content_id,
    c.content_type_id,
    pg.genre_id,
    d.performance_month,
    COALESCE(s.total_streams, 0)        AS total_streams,
    COALESCE(r.total_rental_count, 0)   AS total_rental_count,
    COALESCE(rv2.revenue_generated, 0)  AS revenue_generated,
    rv.avg_customer_rating              AS avg_customer_rating,
    COALESCE(w.wishlist_additions, 0)   AS wishlist_additions
FROM content c
LEFT JOIN (
    SELECT DISTINCT ON (content_id) content_id, genre_id
    FROM content_genre ORDER BY content_id, genre_id
) pg ON pg.content_id = c.content_id
CROSS JOIN (
    SELECT DISTINCT DATE_TRUNC('month', activity_date)::DATE AS performance_month FROM (
        SELECT CAST(start_time AS DATE) AS activity_date FROM streaming_session
        UNION
        SELECT rental_date FROM rental
        UNION
        SELECT CAST(review_date AS DATE) FROM review
        UNION
        SELECT CAST(added_date AS DATE) FROM wishlist
    ) all_dates
) d
LEFT JOIN (
    SELECT content_id, DATE_TRUNC('month', start_time)::DATE AS performance_month,
           COUNT(*) AS total_streams
    FROM streaming_session
    GROUP BY content_id, DATE_TRUNC('month', start_time)::DATE
) s ON s.content_id = c.content_id AND s.performance_month = d.performance_month
LEFT JOIN (
    SELECT ii.content_id, DATE_TRUNC('month', dr.rental_date)::DATE AS performance_month,
           COUNT(*) AS total_rental_count
    FROM (
        SELECT DISTINCT ON (inventory_id, rental_date, return_date)
               rental_id, inventory_id, rental_date, return_date
        FROM rental
        ORDER BY inventory_id, rental_date, return_date, rental_id
    ) dr
    JOIN inventory_item ii ON ii.inventory_id = dr.inventory_id
    GROUP BY ii.content_id, DATE_TRUNC('month', dr.rental_date)::DATE
) r ON r.content_id = c.content_id AND r.performance_month = d.performance_month
LEFT JOIN (
    SELECT ii.content_id, DATE_TRUNC('month', dr.rental_date)::DATE AS performance_month,
           SUM(dr.rental_fee + GREATEST(COALESCE(dr.late_fee,0),0)) AS revenue_generated
    FROM (
        SELECT DISTINCT ON (inventory_id, rental_date, return_date)
               rental_id, inventory_id, rental_date, return_date, rental_fee, late_fee
        FROM rental
        ORDER BY inventory_id, rental_date, return_date, rental_id
    ) dr
    JOIN inventory_item ii ON ii.inventory_id = dr.inventory_id
    GROUP BY ii.content_id, DATE_TRUNC('month', dr.rental_date)::DATE
) rv2 ON rv2.content_id = c.content_id AND rv2.performance_month = d.performance_month
LEFT JOIN (
    SELECT content_id, DATE_TRUNC('month', review_date)::DATE AS performance_month,
           AVG(rating) AS avg_customer_rating
    FROM review
    GROUP BY content_id, DATE_TRUNC('month', review_date)::DATE
) rv ON rv.content_id = c.content_id AND rv.performance_month = d.performance_month
LEFT JOIN (
    SELECT content_id, DATE_TRUNC('month', added_date)::DATE AS performance_month,
           COUNT(*) AS wishlist_additions
    FROM wishlist
    GROUP BY content_id, DATE_TRUNC('month', added_date)::DATE
) w ON w.content_id = c.content_id AND w.performance_month = d.performance_month
WHERE s.content_id IS NOT NULL OR r.content_id IS NOT NULL
   OR rv.content_id IS NOT NULL OR w.content_id IS NOT NULL;


SELECT c.content_id, c.title, ct.content_type, c.release_date,
       c.duration_minutes, c.language, c.age_rating
FROM content c
JOIN content_type ct ON ct.content_type_id = c.content_type_id;


INSERT INTO analytics.fact_content_monthly_performance
  (content_key, date_key, genre_key, content_type_key,
   total_streams, total_rental_count, revenue_generated,
   avg_customer_rating, wishlist_additions)
SELECT
    dc.content_key,
    TO_CHAR(s.performance_month, 'YYYYMMDD')::INT,
    dg.genre_key,
    dct.content_type_key,
    s.total_streams, s.total_rental_count, s.revenue_generated::DECIMAL,
    s.avg_customer_rating::DECIMAL, s.wishlist_additions
FROM analytics.stg_fact_content_monthly_performance s
JOIN analytics.dim_content dc ON dc.content_id = s.content_id
LEFT JOIN analytics.dim_genre dg ON dg.genre_id = s.genre_id
LEFT JOIN analytics.dim_content_type dct ON dct.content_type_id = s.content_type_id
ON CONFLICT (content_key, date_key) DO UPDATE SET
    total_streams = EXCLUDED.total_streams,
    total_rental_count = EXCLUDED.total_rental_count,
    revenue_generated = EXCLUDED.revenue_generated,
    avg_customer_rating = EXCLUDED.avg_customer_rating,
    wishlist_additions = EXCLUDED.wishlist_additions;

