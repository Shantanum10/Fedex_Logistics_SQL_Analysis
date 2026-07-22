-- Task 1: Data Cleaning & Preparation
-- 1.1 Check Duplicate Order_ID

SELECT Order_ID, COUNT(*) AS Duplicate_Count
FROM fedex_orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;

-- Check Duplicate Shipment_ID

SELECT Shipment_ID, COUNT(*) AS Duplicate_Count
FROM fedex_shipments
GROUP BY Shipment_ID
HAVING COUNT(*) > 1;



-- 1.2 Replace Missing Delay_Hours

SELECT COUNT(*) AS Missing_Delay
FROM fedex_Shipments
WHERE Delay_Hours IS NULL;


-- 1.3 Standardize Date Format
-- Orders

SELECT
Order_ID,
DATE_FORMAT(Order_Date,'%Y-%m-%d %H:%i:%s')
FROM fedex_orders;

-- Shipments

SELECT
Shipment_ID,
DATE_FORMAT(Pickup_Date,'%Y-%m-%d %H:%i:%s'),
DATE_FORMAT(Delivery_Date,'%Y-%m-%d %H:%i:%s')
FROM fedex_shipments;

-- 1.4 Check Invalid Dates

SELECT
Shipment_ID,
Pickup_Date,
Delivery_Date
FROM fedex_shipments
WHERE Delivery_Date < Pickup_Date;

-- 1.5 Validate Referential Integrity
-- Orders --> Shipments

SELECT s.*
FROM fedex_shipments s
LEFT JOIN fedex_orders o
ON s.Order_ID = o.Order_ID
WHERE o.Order_ID IS NULL;

-- Routes --> Shipments

SELECT s.*
FROM fedex_shipments s
LEFT JOIN fedex_routes r
ON s.Route_ID = r.Route_ID
WHERE r.Route_ID IS NULL;

-- Warehouses --> Shipments

SELECT s.*
FROM fedex_shipments s
LEFT JOIN fedex_warehouses w
ON s.Warehouse_ID = w.Warehouse_ID
WHERE w.Warehouse_ID IS NULL;

-- Task 2 : Delivery Delay Analysis
-- 2.1 Calculate Delivery Delay for Each Shipment

SELECT
    shipment_id,
    pickup_date,
    delivery_date,
    TIMESTAMPDIFF(HOUR, pickup_date, delivery_date) AS delivery_delay_hours
FROM fedex_shipments;

-- 2.2 Top 10 Delayed Routes

SELECT
    route_id,
    ROUND(AVG(delay_hours),2) AS avg_delay_hours
FROM fedex_shipments
GROUP BY route_id
ORDER BY avg_delay_hours DESC
LIMIT 10;

-- 2.3 Rank Shipments by Delay within Each Warehouse

SELECT
    shipment_id,
    warehouse_id,
    delay_hours,
    RANK() OVER(
        PARTITION BY warehouse_id
        ORDER BY delay_hours DESC
    ) AS delay_rank
FROM fedex_shipments;

-- 2.4 Average Delay per Delivery Type

SELECT
    o.delivery_type,
    ROUND(AVG(s.delay_hours),2) AS avg_delay_hours
FROM fedex_shipments s
JOIN fedex_orders o
    ON s.order_id = o.order_id
GROUP BY o.delivery_type;

-- Task 3 : Route Optimization Insights 
-- 3.1 Average Transit Time per Route

SELECT
    s.route_id,
    ROUND(AVG(TIMESTAMPDIFF(HOUR,
            s.pickup_date,
            s.delivery_date)),2) AS avg_transit_time
FROM fedex_shipments s
GROUP BY s.route_id
ORDER BY s.route_id;

-- 3.2 Average Delay per Route

SELECT
    route_id,
    ROUND(AVG(delay_hours),2) AS avg_delay_hours
FROM fedex_shipments
GROUP BY route_id
ORDER BY avg_delay_hours DESC;

-- 3.3 Distance-to-Time Efficiency Ratio

SELECT
    route_id,
    distance_km,
    avg_transit_time_hours,
    ROUND(distance_km / avg_transit_time_hours,2) AS efficiency_ratio
FROM fedex_routes
ORDER BY efficiency_ratio ASC;

-- 3.4 Identify 3 Worst Routes

SELECT
    route_id,
    ROUND(distance_km / avg_transit_time_hours,2) AS efficiency_ratio
FROM fedex_routes
ORDER BY efficiency_ratio ASC
LIMIT 3;

-- 3.5 Routes with >20% Delayed Shipments

SELECT
    s.route_id,
    ROUND(
        100 *
        SUM(
            CASE
                WHEN TIMESTAMPDIFF(HOUR,
                     s.pickup_date,
                     s.delivery_date)
                     >
                     r.avg_transit_time_hours
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS delayed_percentage
FROM fedex_shipments s
JOIN fedex_routes r
ON s.route_id = r.route_id
GROUP BY s.route_id
HAVING delayed_percentage > 20
ORDER BY delayed_percentage DESC;

-- Task 4 : Warehouse Performance 
-- 4.1 Top 3 Warehouses with Highest Average Delay

SELECT
    warehouse_id,
    ROUND(AVG(delay_hours),2) AS avg_delay_hours
FROM fedex_shipments
GROUP BY warehouse_id
ORDER BY avg_delay_hours DESC
LIMIT 3;

-- 4.2 Total Shipments vs Delayed Shipments per Warehouse

SELECT
    warehouse_id,
    COUNT(*) AS total_shipments,
    SUM(
        CASE
            WHEN delay_hours > 0 THEN 1
            ELSE 0
        END
    ) AS delayed_shipments
FROM fedex_shipments
GROUP BY warehouse_id;

-- 4.3 Warehouses Above Global Average Delay (Using CTE)

WITH warehouse_delay AS
(
    SELECT
        warehouse_id,
        AVG(delay_hours) AS avg_delay
    FROM fedex_shipments
    GROUP BY warehouse_id
)

SELECT *
FROM warehouse_delay
WHERE avg_delay >
(
    SELECT AVG(delay_hours)
    FROM fedex_shipments
);

-- 4.4 Rank Warehouses by On-Time Delivery %

SELECT
    warehouse_id,
    ROUND(
        100 *
        SUM(
            CASE
                WHEN delay_hours <= 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS on_time_delivery_pct,

    RANK() OVER(
        ORDER BY
        ROUND(
            100 *
            SUM(
                CASE
                    WHEN delay_hours <= 0 THEN 1
                    ELSE 0
                END
            ) / COUNT(*),
            2
        ) DESC
    ) AS warehouse_rank FROM fedex_shipments GROUP BY warehouse_id;

-- Task 5 : Delivery Agent Performance
-- 5.1 Rank Delivery Agents (Per Route) by On-Time Delivery %

SELECT
    route_id,
    agent_id,
    ROUND(
        100 *
        SUM(
            CASE
                WHEN delay_hours <= 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS on_time_pct,
    RANK() OVER (
        PARTITION BY route_id
        ORDER BY
        ROUND(
            100 *
            SUM(
                CASE
                    WHEN delay_hours <= 0 THEN 1
                    ELSE 0
                END
            ) / COUNT(*),
            2
        ) DESC
    ) AS agent_rank FROM fedex_shipments GROUP BY route_id, agent_id;

-- 5.2 Find Agents with On-Time % Below 85%

SELECT
    agent_id,

    ROUND(
        100 *
        SUM(
            CASE
                WHEN delay_hours <= 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS on_time_pct

FROM fedex_shipments
GROUP BY agent_id
HAVING on_time_pct < 85;

-- 5.3 Compare Top 5 vs Bottom 5 Agents

SELECT
    s.agent_id,
    a.agent_name,
    a.experience_years,
    a.avg_rating,

    ROUND(
        100 *
        SUM(
            CASE
                WHEN s.delay_hours <= 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS on_time_pct

FROM fedex_shipments s
JOIN fedex_delivery_agents a
ON s.agent_id = a.agent_id

GROUP BY
    s.agent_id,
    a.agent_name,
    a.experience_years,
    a.avg_rating

ORDER BY on_time_pct DESC;

-- Top 5 Agents

SELECT *
FROM
(
    SELECT
        s.agent_id,
        a.agent_name,
        a.experience_years,
        a.avg_rating,
        ROUND(
            100 *
            SUM(
                CASE
                    WHEN s.delay_hours <= 0 THEN 1
                    ELSE 0
                END
            ) / COUNT(*),
            2
        ) AS on_time_pct
    FROM fedex_shipments s
    JOIN fedex_delivery_agents a
    ON s.agent_id = a.agent_id
    GROUP BY
        s.agent_id,
        a.agent_name,
        a.experience_years,
        a.avg_rating
) x
ORDER BY on_time_pct DESC
LIMIT 5;

-- Bottom 5 Agents

SELECT *
FROM
(
    SELECT
        s.agent_id,
        a.agent_name,
        a.experience_years,
        a.avg_rating,
        ROUND(
            100 *
            SUM(
                CASE
                    WHEN s.delay_hours <= 0 THEN 1
                    ELSE 0
                END
            ) / COUNT(*),
            2
        ) AS on_time_pct
    FROM fedex_shipments s
    JOIN fedex_delivery_agents a
    ON s.agent_id = a.agent_id
    GROUP BY
        s.agent_id,
        a.agent_name,
        a.experience_years,
        a.avg_rating
) x
ORDER BY on_time_pct ASC
LIMIT 5;

-- Task 6 :  Shipment Tracking Analytics
-- 6.1 Latest Status and Latest Delivery Date for Each Shipment

SELECT
    shipment_id,
    delivery_status,
    delivery_date
FROM fedex_shipments
ORDER BY delivery_date DESC;

-- 6.2 Routes Where Majority of Shipments are "In Transit" or "Returned"

SELECT
    route_id,
    delivery_status,
    COUNT(*) AS shipment_count
FROM fedex_shipments
WHERE delivery_status IN ('In Transit','Returned')
GROUP BY route_id, delivery_status
ORDER BY shipment_count DESC;

-- 6.3 Most Frequent Delay Reasons

SELECT
    delay_reason,
    COUNT(*) AS frequency
FROM fedex_shipments
GROUP BY delay_reason
ORDER BY frequency DESC;

-- 6.4 Orders with Exceptionally High Delays (>120 Hours)

SELECT
    shipment_id,
    order_id,
    route_id,
    warehouse_id,
    delay_hours
FROM fedex_shipments
WHERE delay_hours > 120
ORDER BY delay_hours DESC;

-- Task 7 : Advanced KPI Reporting
-- 7.1 Average Delivery Delay per Source Country

SELECT
    r.source_country,
    ROUND(AVG(s.delay_hours),2) AS avg_delivery_delay
FROM fedex_shipments s
JOIN fedex_routes r
ON s.route_id = r.route_id
GROUP BY r.source_country
ORDER BY avg_delivery_delay DESC;

-- 7.2 On-Time Delivery Percentage

SELECT
    ROUND(
        100 *
        SUM(
            CASE
                WHEN delay_hours <= 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS on_time_delivery_percentage
FROM fedex_shipments;

-- 7.3 Average Delay per Route

SELECT
    route_id,
    ROUND(AVG(delay_hours),2) AS avg_delay_hours
FROM fedex_shipments
GROUP BY route_id
ORDER BY avg_delay_hours DESC;

-- 7.4 Warehouse Utilization %

SELECT
    w.warehouse_id,
    w.capacity_per_day,
    COUNT(s.shipment_id) AS shipments_handled,

    ROUND(
        COUNT(s.shipment_id) * 100.0 /
        w.capacity_per_day,
        2
    ) AS utilization_percentage

FROM fedex_warehouses w
LEFT JOIN fedex_shipments s
ON w.warehouse_id = s.warehouse_id

GROUP BY
    w.warehouse_id,
    w.capacity_per_day

ORDER BY utilization_percentage DESC;


