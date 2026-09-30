SELECT
    ii.inventory_id,
    ii.warehouse_id,
    d.activity_date,
    COALESCE(r_out.rentals, 0)   AS rentals,
    COALESCE(r_in.returns, 0)    AS returns,
    1                             AS days_available,
    CASE WHEN COALESCE(r_out.rentals,0) > 0 THEN 100.00 ELSE 0.00 END AS utilisation_percentage
FROM inventory_item ii
CROSS JOIN (
    SELECT DISTINCT rental_date AS activity_date FROM rental
    UNION
    SELECT DISTINCT return_date FROM rental WHERE return_date IS NOT NULL
) d
LEFT JOIN (
    SELECT inventory_id, rental_date AS activity_date, COUNT(*) AS rentals
    FROM (
        SELECT DISTINCT ON (inventory_id, rental_date, return_date)
               inventory_id, rental_date, return_date, rental_id
        FROM rental
        ORDER BY inventory_id, rental_date, return_date, rental_id
    ) deduped_rentals
    GROUP BY inventory_id, rental_date
) r_out ON r_out.inventory_id = ii.inventory_id AND r_out.activity_date = d.activity_date
LEFT JOIN (
    SELECT inventory_id, return_date AS activity_date, COUNT(*) AS returns
    FROM (
        SELECT DISTINCT ON (inventory_id, rental_date, return_date)
               inventory_id, rental_date, return_date, rental_id
        FROM rental
        WHERE return_date IS NOT NULL
        ORDER BY inventory_id, rental_date, return_date, rental_id
    ) deduped_returns
    GROUP BY inventory_id, return_date
) r_in ON r_in.inventory_id = ii.inventory_id AND r_in.activity_date = d.activity_date
WHERE r_out.inventory_id IS NOT NULL OR r_in.inventory_id IS NOT NULL;


SELECT w.warehouse_id, w.warehouse_name, w.city_id, c.city_name
FROM warehouse w
JOIN city c ON c.city_id = w.city_id;


INSERT INTO analytics.fact_inventory_utilisation
  (inventory_key, date_key, warehouse_key, rentals, returns, days_available, utilisation_percentage)
SELECT
    di.inventory_key,
    TO_CHAR(s.activity_date, 'YYYYMMDD')::INT,
    dw.warehouse_key,
    s.rentals, s.returns, s.days_available, s.utilisation_percentage::DECIMAL
FROM analytics.stg_fact_inventory_utilisation s
JOIN analytics.dim_inventory di ON di.inventory_id = s.inventory_id
LEFT JOIN analytics.dim_warehouse dw ON dw.warehouse_id = s.warehouse_id
ON CONFLICT (inventory_key, date_key) DO UPDATE SET
    rentals = EXCLUDED.rentals,
    returns = EXCLUDED.returns,
    days_available = EXCLUDED.days_available,
    utilisation_percentage = EXCLUDED.utilisation_percentage;

