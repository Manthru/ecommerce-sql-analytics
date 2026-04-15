
-- Author: Ramavath Manthru Naik

USE mavenfuzzyfactory;

-- ============================================================
-- TASK 1 — Monthly Gsearch Sessions, Orders & CVR
-- ============================================================
-- Shows top-line growth from our biggest paid channel.
-- CVR = orders / sessions * 100

SELECT
    DATE_FORMAT(ws.created_at, '%Y-%m')          AS month,
    COUNT(DISTINCT ws.website_session_id)         AS sessions,
    COUNT(DISTINCT o.order_id)                    AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100.0
    , 2)                                          AS cvr_pct
FROM  website_sessions ws
LEFT  JOIN orders o USING (website_session_id)
WHERE ws.utm_source   = 'gsearch'
  AND ws.created_at   < '2012-11-27'
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- TASK 2 — Monthly Gsearch: Brand vs Non-Brand Split
-- ============================================================
-- Helps demonstrate that brand awareness is growing alongside
-- paid non-brand acquisition.

SELECT
    DATE_FORMAT(ws.created_at, '%Y-%m')                AS month,

    -- Non-brand
    COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'nonbrand'
          THEN ws.website_session_id END)               AS nonbrand_sessions,
    COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'nonbrand'
          THEN o.order_id END)                          AS nonbrand_orders,
    ROUND(
        COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'nonbrand'
              THEN o.order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'nonbrand'
              THEN ws.website_session_id END), 0) * 100.0
    , 2)                                               AS nonbrand_cvr_pct,

    -- Brand
    COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'brand'
          THEN ws.website_session_id END)               AS brand_sessions,
    COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'brand'
          THEN o.order_id END)                          AS brand_orders,
    ROUND(
        COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'brand'
              THEN o.order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN ws.utm_campaign = 'brand'
              THEN ws.website_session_id END), 0) * 100.0
    , 2)                                               AS brand_cvr_pct

FROM  website_sessions ws
LEFT  JOIN orders o USING (website_session_id)
WHERE ws.utm_source = 'gsearch'
  AND ws.created_at < '2012-11-27'
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- TASK 3 — Monthly Gsearch Non-Brand: Desktop vs Mobile
-- ============================================================
-- Low mobile CVR can justify reallocating budget to desktop bids.

SELECT
    DATE_FORMAT(ws.created_at, '%Y-%m')                 AS month,

    -- Desktop
    COUNT(DISTINCT CASE WHEN ws.device_type = 'desktop'
          THEN ws.website_session_id END)                AS desktop_sessions,
    COUNT(DISTINCT CASE WHEN ws.device_type = 'desktop'
          THEN o.order_id END)                           AS desktop_orders,
    ROUND(
        COUNT(DISTINCT CASE WHEN ws.device_type = 'desktop'
              THEN o.order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN ws.device_type = 'desktop'
              THEN ws.website_session_id END), 0) * 100.0
    , 2)                                                AS desktop_cvr_pct,

    -- Mobile
    COUNT(DISTINCT CASE WHEN ws.device_type = 'mobile'
          THEN ws.website_session_id END)                AS mobile_sessions,
    COUNT(DISTINCT CASE WHEN ws.device_type = 'mobile'
          THEN o.order_id END)                           AS mobile_orders,
    ROUND(
        COUNT(DISTINCT CASE WHEN ws.device_type = 'mobile'
              THEN o.order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN ws.device_type = 'mobile'
              THEN ws.website_session_id END), 0) * 100.0
    , 2)                                                AS mobile_cvr_pct

FROM  website_sessions ws
LEFT  JOIN orders o USING (website_session_id)
WHERE ws.utm_source   = 'gsearch'
  AND ws.utm_campaign = 'nonbrand'
  AND ws.created_at   < '2012-11-27'
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- TASK 4 — Monthly Traffic by Channel Mix
-- ============================================================
-- Traffic source logic:
--   gsearch paid   → utm_source = 'gsearch'
--   bsearch paid   → utm_source = 'bsearch'
--   organic search → utm_source IS NULL AND http_referer IS NOT NULL
--   direct / type-in → utm_source IS NULL AND http_referer IS NULL

SELECT
    DATE_FORMAT(ws.created_at, '%Y-%m')                    AS month,
    COUNT(DISTINCT ws.website_session_id)                   AS total_sessions,
    COUNT(DISTINCT CASE WHEN ws.utm_source = 'gsearch'
          THEN ws.website_session_id END)                   AS gsearch_paid,
    COUNT(DISTINCT CASE WHEN ws.utm_source = 'bsearch'
          THEN ws.website_session_id END)                   AS bsearch_paid,
    COUNT(DISTINCT CASE WHEN ws.utm_source IS NULL
               AND ws.http_referer IS NOT NULL
          THEN ws.website_session_id END)                   AS organic_search,
    COUNT(DISTINCT CASE WHEN ws.utm_source IS NULL
               AND ws.http_referer IS NULL
          THEN ws.website_session_id END)                   AS direct_type_in
FROM  website_sessions ws
WHERE ws.created_at < '2012-11-27'
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- TASK 5 — Monthly Session-to-Order CVR (All Channels)
-- ============================================================
-- Demonstrates overall website performance improvement over 8 months.

SELECT
    DATE_FORMAT(ws.created_at, '%Y-%m')          AS month,
    COUNT(DISTINCT ws.website_session_id)         AS sessions,
    COUNT(DISTINCT o.order_id)                    AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100.0
    , 2)                                          AS cvr_pct
FROM  website_sessions ws
LEFT  JOIN orders o USING (website_session_id)
WHERE ws.created_at < '2012-11-27'
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- TASK 6 — Lander-1 A/B Test: Revenue Lift Estimate
-- ============================================================
-- /lander-1 first appeared at website_pageview_id = 23504 (Jun 19).
-- Test window closed Jul 28. We measure the incremental orders
-- earned by the higher CVR from that date forward.
--
-- Step 1: CVR by landing page during test window

SELECT
    wp.pageview_url                                         AS landing_page,
    COUNT(DISTINCT ws.website_session_id)                   AS sessions,
    COUNT(DISTINCT o.order_id)                              AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100.0
    , 2)                                                    AS cvr_pct
FROM  website_sessions ws
JOIN  website_pageviews wp  USING (website_session_id)
LEFT  JOIN orders o         USING (website_session_id)
WHERE wp.website_pageview_id >= 23504          -- first lander-1 view
  AND ws.created_at   <  '2012-07-28'
  AND ws.utm_source   =  'gsearch'
  AND ws.utm_campaign =  'nonbrand'
  AND wp.pageview_url IN ('/home', '/lander-1')
GROUP BY 1;

-- Results (reference):
--   /home     → CVR ≈ 3.18 %
--   /lander-1 → CVR ≈ 4.06 %
--   Lift      → +0.88 pp per session

-- Step 2: Sessions since /home was fully retired (session_id ≥ 17145)

SELECT
    COUNT(DISTINCT website_session_id)           AS sessions_since_test_end
FROM  website_sessions
WHERE created_at    <  '2012-11-27'
  AND website_session_id >= 17145
  AND utm_source   =  'gsearch'
  AND utm_campaign =  'nonbrand';

-- ≈ 22 973 sessions × 0.0088 lift ≈ 202 incremental orders (~50/month)


-- ============================================================
-- TASK 7 — Full Conversion Funnel: /home vs /lander-1
-- ============================================================
-- Time window: Jun 19 – Jul 28, 2012 | gsearch nonbrand only
-- Each row = one session; flag = 1 if the user reached that step.

-- Part A — Raw session flags

DROP TEMPORARY TABLE IF EXISTS session_funnel_flags;

CREATE TEMPORARY TABLE session_funnel_flags
SELECT
    ws.website_session_id,
    MAX(CASE WHEN wp.pageview_url = '/home'                    THEN 1 ELSE 0 END) AS saw_home,
    MAX(CASE WHEN wp.pageview_url = '/lander-1'                THEN 1 ELSE 0 END) AS saw_lander1,
    MAX(CASE WHEN wp.pageview_url = '/products'                THEN 1 ELSE 0 END) AS saw_products,
    MAX(CASE WHEN wp.pageview_url = '/the-original-mr-fuzzy'   THEN 1 ELSE 0 END) AS saw_mrfuzzy,
    MAX(CASE WHEN wp.pageview_url = '/cart'                    THEN 1 ELSE 0 END) AS saw_cart,
    MAX(CASE WHEN wp.pageview_url = '/shipping'                THEN 1 ELSE 0 END) AS saw_shipping,
    MAX(CASE WHEN wp.pageview_url = '/billing'                 THEN 1 ELSE 0 END) AS saw_billing,
    MAX(CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS saw_thankyou
FROM  website_sessions ws
LEFT  JOIN website_pageviews wp USING (website_session_id)
WHERE ws.utm_source   =  'gsearch'
  AND ws.utm_campaign =  'nonbrand'
  AND wp.created_at BETWEEN '2012-06-19' AND '2012-07-28'
GROUP BY ws.website_session_id;

-- Part B — Volume counts per funnel step

SELECT
    CASE
        WHEN saw_home    = 1 THEN 'saw_homepage'
        WHEN saw_lander1 = 1 THEN 'saw_lander1'
        ELSE 'check_logic'
    END                                       AS segment,
    COUNT(DISTINCT website_session_id)        AS sessions,
    SUM(saw_products)                         AS to_products,
    SUM(saw_mrfuzzy)                          AS to_mrfuzzy,
    SUM(saw_cart)                             AS to_cart,
    SUM(saw_shipping)                         AS to_shipping,
    SUM(saw_billing)                          AS to_billing,
    SUM(saw_thankyou)                         AS to_thankyou
FROM  session_funnel_flags
GROUP BY 1;

-- Part C — Click-through rates per funnel step

SELECT
    CASE
        WHEN saw_home    = 1 THEN 'saw_homepage'
        WHEN saw_lander1 = 1 THEN 'saw_lander1'
        ELSE 'check_logic'
    END                                                        AS segment,
    ROUND(SUM(saw_products)  / COUNT(DISTINCT website_session_id) * 100.0, 2) AS products_ctr,
    ROUND(SUM(saw_mrfuzzy)   / COUNT(DISTINCT website_session_id) * 100.0, 2) AS mrfuzzy_ctr,
    ROUND(SUM(saw_cart)      / COUNT(DISTINCT website_session_id) * 100.0, 2) AS cart_ctr,
    ROUND(SUM(saw_shipping)  / COUNT(DISTINCT website_session_id) * 100.0, 2) AS shipping_ctr,
    ROUND(SUM(saw_billing)   / COUNT(DISTINCT website_session_id) * 100.0, 2) AS billing_ctr,
    ROUND(SUM(saw_thankyou)  / COUNT(DISTINCT website_session_id) * 100.0, 2) AS thankyou_ctr
FROM  session_funnel_flags
GROUP BY 1;


-- ============================================================
-- TASK 8 — Billing Page A/B Test: Revenue per Session Lift
-- ============================================================
-- Test window: Sep 10 – Nov 10, 2012
-- /billing-2 generates ~$8.51 more revenue per billing session.

SELECT
    wp.pageview_url                                           AS billing_version,
    COUNT(DISTINCT wp.website_session_id)                     AS sessions,
    ROUND(SUM(o.price_usd)
          / COUNT(DISTINCT wp.website_session_id), 2)         AS revenue_per_session
FROM  website_pageviews wp
LEFT  JOIN orders o USING (website_session_id)
WHERE wp.created_at  BETWEEN '2012-09-10' AND '2012-11-10'
  AND wp.pageview_url IN ('/billing', '/billing-2')
GROUP BY 1;

-- Monthly billing session volume (Oct 27 – Nov 27)

SELECT
    COUNT(DISTINCT website_session_id)           AS billing_sessions_last_month
FROM  website_pageviews
WHERE created_at   BETWEEN '2012-10-27' AND '2012-11-27'
  AND pageview_url IN ('/billing', '/billing-2');

-- 1 193 sessions × $8.51 lift ≈ $10 153 incremental revenue last month


-- ============================================================
-- TASK 9 (BONUS) — Weekly Gsearch Non-Brand Bid Efficiency
-- ============================================================
-- Weekly granularity lets us spot CVR volatility that monthly
-- averages can hide — useful for adjusting bid strategies faster.

SELECT
    DATE_FORMAT(ws.created_at, '%Y-%u')          AS year_week,
    MIN(DATE(ws.created_at))                      AS week_start,
    COUNT(DISTINCT ws.website_session_id)         AS sessions,
    COUNT(DISTINCT o.order_id)                    AS orders,
    ROUND(
        COUNT(DISTINCT o.order_id)
        / COUNT(DISTINCT ws.website_session_id) * 100.0
    , 2)                                          AS cvr_pct,
    ROUND(
        COUNT(DISTINCT o.order_id)
        / NULLIF(COUNT(DISTINCT ws.website_session_id), 0)
        -- relative change vs prior week can be computed in a BI tool
    , 4)                                          AS orders_per_session
FROM  website_sessions ws
LEFT  JOIN orders o USING (website_session_id)
WHERE ws.utm_source   = 'gsearch'
  AND ws.utm_campaign = 'nonbrand'
  AND ws.created_at   < '2012-11-27'
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- TASK 10 (BONUS) — Product Page Performance & AOV Trend
-- ============================================================
-- Tracks monthly order volume, revenue, and average order value
-- so we can detect pricing sensitivity and product mix shifts.

SELECT
    DATE_FORMAT(o.created_at, '%Y-%m')           AS month,
    COUNT(DISTINCT o.order_id)                    AS orders,
    ROUND(SUM(o.price_usd), 2)                    AS total_revenue,
    ROUND(AVG(o.price_usd), 2)                    AS avg_order_value,
    ROUND(SUM(o.items_purchased)
          / COUNT(DISTINCT o.order_id), 2)        AS avg_items_per_order
FROM  orders o
WHERE o.created_at < '2012-11-27'
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- TASK 11 (BONUS) — Bounce Rate Trend by Landing Page
-- ============================================================
-- A "bounce" = session with only ONE pageview.
-- Monitoring bounce rate month-over-month helps validate UX changes.

DROP TEMPORARY TABLE IF EXISTS session_pageview_counts;

CREATE TEMPORARY TABLE session_pageview_counts
SELECT
    ws.website_session_id,
    DATE_FORMAT(ws.created_at, '%Y-%m')     AS month,
    wp.pageview_url                          AS landing_page,
    COUNT(wp.website_pageview_id)            AS pageview_count
FROM  website_sessions ws
JOIN  website_pageviews wp USING (website_session_id)
WHERE ws.created_at < '2012-11-27'
  AND ws.utm_source  = 'gsearch'
  AND ws.utm_campaign = 'nonbrand'
GROUP BY 1, 2, 3;

SELECT
    spc.month,
    spc.landing_page,
    COUNT(DISTINCT spc.website_session_id)                        AS total_sessions,
    COUNT(DISTINCT CASE WHEN spc.pageview_count = 1
          THEN spc.website_session_id END)                         AS bounced_sessions,
    ROUND(
        COUNT(DISTINCT CASE WHEN spc.pageview_count = 1
              THEN spc.website_session_id END)
        / COUNT(DISTINCT spc.website_session_id) * 100.0
    , 2)                                                           AS bounce_rate_pct
FROM  session_pageview_counts spc
GROUP BY 1, 2
ORDER BY 1, 2;

-- ============================================================
-- TASK 12 (BONUS) — Monthly Revenue using CTE
-- ============================================================
-- CTEs (Common Table Expressions) improve readability and allow
-- reuse of intermediate results without nested subqueries.
-- Interviewers love seeing this — it signals production-level SQL.

WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(created_at, '%Y-%m')     AS month,
        COUNT(DISTINCT order_id)             AS orders,
        ROUND(SUM(price_usd), 2)             AS revenue,
        ROUND(AVG(price_usd), 2)             AS avg_order_value
    FROM  orders
    WHERE created_at < '2012-11-27'
    GROUP BY month
)

SELECT
    month,
    orders,
    revenue,
    avg_order_value,
    -- Running cumulative revenue — shows growth story at a glance
    ROUND(SUM(revenue) OVER (ORDER BY month ROWS UNBOUNDED PRECEDING), 2) AS cumulative_revenue
FROM  monthly_revenue
ORDER BY month;


-- ============================================================
-- TASK 13 (BONUS) — Top Customers by Lifetime Spend (Window Function)
-- ============================================================
-- RANK() is a window function — it assigns a rank to each row
-- within an ordered partition WITHOUT collapsing rows like GROUP BY.
-- This is one of the most common interview questions for data roles.

SELECT
    user_id,
    COUNT(DISTINCT order_id)              AS total_orders,
    ROUND(SUM(price_usd), 2)              AS total_spent,
    ROUND(AVG(price_usd), 2)              AS avg_order_value,
    RANK() OVER (ORDER BY SUM(price_usd) DESC) AS customer_rank
FROM  orders
WHERE created_at < '2012-11-27'
GROUP BY user_id
ORDER BY customer_rank
LIMIT 10;

-- ============================================================
-- END OF ANALYSIS
-- ============================================================