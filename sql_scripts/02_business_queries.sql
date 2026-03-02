-- ==============================================================================
-- OLIST E-COMMERCE: BUSINESS ANALYSIS & ADVANCED SQL QUERIES
-- ==============================================================================
USE olist_ecommerce;

-- ==============================================================================
-- CHAPTER 1A: CUSTOMER BEHAVIOR & RFM SEGMENTATION
-- ==============================================================================
-- Objective: Segment customers into actionable marketing categories based on 
-- Recency (days since last purchase), Frequency (total orders), and Monetary value.

WITH rfm_base AS (
    -- Step 1: Calculate the raw R, F, and M metrics for each unique customer
    SELECT 
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(op.payment_value) AS monetary_value
    FROM orders o
		JOIN customers c ON o.customer_id = c.customer_id
		JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

rfm_scores AS (
    -- Step 2: Score customers from 1-5 for each metric using NTILE
    -- (Use a dynamic subquery to find the max date in the database to act as "today")
    SELECT 
        customer_unique_id,
        DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM orders), last_purchase_date) AS recency_days,
        frequency,
        monetary_value,
        -- For Recency: Lower days is better, so DESC sort is used so that the smallest gap gets a 5
        NTILE(5) OVER (ORDER BY DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM orders), last_purchase_date) DESC) AS R_Score,
        -- For Frequency & Monetary: Higher is better, so ASC sort is used
        NTILE(5) OVER (ORDER BY frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS M_Score
    FROM rfm_base
)

-- Step 3: Categorize customers based on their combined RFM scores
SELECT 
    customer_unique_id,
    recency_days,
    frequency,
    monetary_value,
    R_Score,
    F_Score,
    M_Score,
    CASE 
        WHEN R_Score = 5 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
        WHEN R_Score >= 4 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
        WHEN R_Score >= 3 AND F_Score <= 3 THEN 'Recent/Average Buyers'
        WHEN R_Score <= 2 AND F_Score >= 3 THEN 'At Risk (Big Spenders)'
        WHEN R_Score <= 2 AND F_Score = 1 THEN 'Lost (One-Time)'
        ELSE 'Regular/Other'
    END AS customer_segment
FROM rfm_scores
ORDER BY monetary_value DESC;

-- ==============================================================================
-- CHAPTER 1B: RFM SEGMENT DISTRIBUTION & SUMMARY
-- ==============================================================================
-- Objective: Aggregate the customer segments to see the overall health of the 
-- customer base and determine where marketing efforts should be focused.

WITH rfm_base AS (
    SELECT 
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_purchase_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(op.payment_value) AS monetary_value
    FROM orders o
		JOIN customers c ON o.customer_id = c.customer_id
		JOIN order_payments op ON o.order_id = op.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

rfm_scores AS (
    SELECT 
        customer_unique_id,
        DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM orders), last_purchase_date) AS recency_days,
        frequency,
        monetary_value,
        NTILE(5) OVER (ORDER BY DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM orders), last_purchase_date) DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS M_Score
    FROM rfm_base
),

rfm_segments AS (
    SELECT 
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value,
        CASE 
            WHEN R_Score = 5 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
            WHEN R_Score >= 4 AND F_Score >= 3 AND M_Score >= 3 THEN 'Loyal Customers'
            WHEN R_Score >= 3 AND F_Score <= 3 THEN 'Recent/Average Buyers'
            WHEN R_Score <= 2 AND F_Score >= 3 THEN 'At Risk (Big Spenders)'
            WHEN R_Score <= 2 AND F_Score = 1 THEN 'Lost (One-Time)'
            ELSE 'Regular/Other'
        END AS customer_segment
    FROM rfm_scores
)

-- Final Aggregation: Count customers, calculate percentages, and find all RFM averages
SELECT 
    customer_segment,
    COUNT(customer_unique_id) AS total_customers,
    ROUND(COUNT(customer_unique_id) * 100.0 / (SELECT COUNT(*) FROM rfm_segments), 2) AS percentage_of_base,
    ROUND(AVG(recency_days), 0) AS average_days_since_last_purchase,
    ROUND(AVG(frequency), 2) AS average_orders,
    ROUND(AVG(monetary_value), 2) AS average_spend
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_customers DESC;

-- ==============================================================================
-- CHAPTER 2: COHORT ANALYSIS (CUSTOMER RETENTION)
-- ==============================================================================
-- Objective: Track customer retention by grouping users into monthly cohorts based 
-- on their first purchase, then measuring how many return in subsequent months.

WITH customer_cohorts AS (
    -- Step 1: Find the first purchase month for every unique customer
    SELECT 
        c.customer_unique_id,
        -- DATE_FORMAT standardizes timestamps to the 1st of the month for clean grouping
        DATE_FORMAT(MIN(o.order_purchase_timestamp), '%Y-%m-01') AS cohort_month
    FROM orders o
		JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

order_months AS (
    -- Step 2: Get the purchase month for every individual order
    SELECT 
        c.customer_unique_id,
        o.order_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS order_month
    FROM orders o
		JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),

cohort_retention AS (
    -- Step 3: Join orders to cohorts and calculate the month difference
    SELECT 
        om.customer_unique_id,
        cc.cohort_month,
        om.order_month,
        -- PERIOD_DIFF calculates the exact number of months between two YYYYMM dates
        PERIOD_DIFF(EXTRACT(YEAR_MONTH FROM om.order_month), EXTRACT(YEAR_MONTH FROM cc.cohort_month)) AS month_index
    FROM order_months om
		JOIN customer_cohorts cc ON om.customer_unique_id = cc.customer_unique_id
)

-- Step 4: Pivot the data into a retention matrix using conditional aggregation
SELECT 
    cohort_month,
    -- Month 0 is always the total size of the original cohort
    COUNT(DISTINCT CASE WHEN month_index = 0 THEN customer_unique_id END) AS Month_0_Total_Customers,
    COUNT(DISTINCT CASE WHEN month_index = 1 THEN customer_unique_id END) AS Month_1,
    COUNT(DISTINCT CASE WHEN month_index = 2 THEN customer_unique_id END) AS Month_2,
    COUNT(DISTINCT CASE WHEN month_index = 3 THEN customer_unique_id END) AS Month_3,
    COUNT(DISTINCT CASE WHEN month_index = 4 THEN customer_unique_id END) AS Month_4,
    COUNT(DISTINCT CASE WHEN month_index = 5 THEN customer_unique_id END) AS Month_5
FROM cohort_retention
-- Filter out null cohorts just in case any missing dates slipped through
WHERE cohort_month IS NOT NULL
GROUP BY cohort_month
ORDER BY cohort_month;

-- ==============================================================================
-- CHAPTER 3: LOGISTICS PERFORMANCE & SUPPLY CHAIN BOTTLENECKS
-- ==============================================================================
-- Objective: Calculate delivery times across the supply chain milestones and 
-- identify which geographic regions suffer from the highest rate of late deliveries.

WITH delivery_metrics AS (
    -- Step 1: Calculate the exact time (in days) between supply chain milestones
    SELECT 
        o.order_id,
        c.customer_state,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        -- Calculate specific stage delays
        DATEDIFF(o.order_approved_at, o.order_purchase_timestamp) AS days_to_approve,
        DATEDIFF(o.order_delivered_carrier_date, o.order_approved_at) AS days_to_carrier,
        DATEDIFF(o.order_delivered_customer_date, o.order_delivered_carrier_date) AS days_in_transit,
        DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS total_delivery_days,
        -- Flag if the order missed the promised delivery date
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 
            ELSE 0 
        END AS is_late
    FROM orders o
		JOIN customers c ON o.customer_id = c.customer_id
    WHERE
		o.order_status = 'delivered'
		-- Filter out bad data where delivery dates are missing
		AND o.order_delivered_customer_date IS NOT NULL
		AND o.order_estimated_delivery_date IS NOT NULL
)

-- Step 2: Aggregate by state to find the worst geographical bottlenecks
SELECT 
    customer_state,
    COUNT(order_id) AS total_orders,
    ROUND(AVG(total_delivery_days), 1) AS avg_delivery_days,
    SUM(is_late) AS total_late_deliveries,
    ROUND((SUM(is_late) / COUNT(order_id)) * 100, 2) AS late_delivery_rate_pct,
    ROUND(AVG(days_to_approve), 1) AS avg_days_to_approve,
    ROUND(AVG(days_to_carrier), 1) AS avg_days_to_carrier,
    ROUND(AVG(days_in_transit), 1) AS avg_days_in_transit
FROM delivery_metrics
GROUP BY customer_state
-- Filter out states with very few orders to avoid skewed data
HAVING total_orders > 100 
-- Sort by the worst late delivery rates first
ORDER BY late_delivery_rate_pct DESC;
