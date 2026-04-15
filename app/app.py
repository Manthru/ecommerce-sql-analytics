"""
╔══════════════════════════════════════════════════════╗
║   E-Commerce Analytics Dashboard                    ║
║   Author  : Ramavath Manthru Naik                   ║
║   Version : 2.0 — Production Ready                  ║
╚══════════════════════════════════════════════════════╝
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from db import get_connection
from datetime import date

# ──────────────────────────────────────────────────────
# PAGE CONFIG  (must be first Streamlit call)
# ──────────────────────────────────────────────────────
st.set_page_config(
    page_title="Maven Analytics",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ──────────────────────────────────────────────────────
# GLOBAL STYLES  — dark, editorial aesthetic
# ──────────────────────────────────────────────────────
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=DM+Sans:wght@300;400;500&display=swap');

html, body, [class*="css"] {
    font-family: 'DM Sans', sans-serif;
}

/* KPI cards */
[data-testid="metric-container"] {
    background: #1a1a2e;
    border: 1px solid #2a2a4a;
    border-radius: 12px;
    padding: 1.2rem 1.5rem;
    transition: border-color .2s;
}
[data-testid="metric-container"]:hover { border-color: #4f8ef7; }

[data-testid="stMetricLabel"]  { color: #8888aa !important; font-size: .8rem !important; letter-spacing: .06em; text-transform: uppercase; }
[data-testid="stMetricValue"]  { color: #e8e8f8 !important; font-family: 'DM Serif Display', serif !important; font-size: 2rem !important; }
[data-testid="stMetricDelta"]  { font-size: .8rem !important; }

/* Sidebar */
section[data-testid="stSidebar"] {
    background: #0f0f1a !important;
    border-right: 1px solid #2a2a4a;
}

/* Divider */
hr { border-color: #2a2a4a !important; }

/* Section headers */
h2, h3 { font-family: 'DM Serif Display', serif !important; color: #c8c8f8 !important; }

/* Expander */
details { border: 1px solid #2a2a4a !important; border-radius: 8px !important; background: #1a1a2e !important; }
</style>
""", unsafe_allow_html=True)

# ──────────────────────────────────────────────────────
# DATABASE HELPERS  — cached so we don't re-query on
# every widget interaction
# ──────────────────────────────────────────────────────
@st.cache_resource(show_spinner=False)
def get_conn():
    """Return a single shared, cached DB connection."""
    return get_connection()


@st.cache_data(ttl=300, show_spinner=False)   # refresh every 5 min
def run_query(sql: str, params: tuple = ()) -> pd.DataFrame:
    """Execute a read-only SQL query and return a DataFrame."""
    conn = get_conn()
    return pd.read_sql(sql, conn, params=params)


# ──────────────────────────────────────────────────────
# SIDEBAR  — global filters
# ──────────────────────────────────────────────────────
with st.sidebar:
    st.markdown("## 🛒 Maven Analytics")
    st.caption("eCommerce Intelligence Platform")
    st.divider()

    # Date range — pulled from actual data, not hardcoded
    date_bounds = run_query(
        "SELECT DATE(MIN(created_at)) AS min_d, DATE(MAX(created_at)) AS max_d FROM orders;"
    )
    min_d = pd.to_datetime(date_bounds["min_d"][0]).date()
    max_d = pd.to_datetime(date_bounds["max_d"][0]).date()

    st.markdown("**Date Range**")
    start_date = st.date_input("From", value=min_d, min_value=min_d, max_value=max_d)
    end_date   = st.date_input("To",   value=max_d, min_value=min_d, max_value=max_d)

    if start_date > end_date:
        st.error("Start date must be before end date.")
        st.stop()

    st.divider()

    # UTM source filter
    sources_df = run_query("SELECT DISTINCT utm_source FROM website_sessions WHERE utm_source IS NOT NULL ORDER BY 1;")
    source_options = ["All"] + sources_df["utm_source"].tolist()
    selected_source = st.selectbox("UTM Source", source_options)

    st.divider()
    st.caption("Data: Maven Fuzzy Factory · 2012")

# Convenience date strings for parameterised queries
d_start = start_date.strftime("%Y-%m-%d")
d_end   = end_date.strftime("%Y-%m-%d")

# ──────────────────────────────────────────────────────
# HEADER
# ──────────────────────────────────────────────────────
st.markdown("<h1 style='font-family:DM Serif Display,serif; color:#e8e8f8; margin-bottom:0'>E-Commerce Analytics</h1>", unsafe_allow_html=True)
st.caption(f"Showing data from **{start_date}** to **{end_date}**")
st.divider()

# ──────────────────────────────────────────────────────
# KPI SECTION
# ──────────────────────────────────────────────────────
kpi_sql = """
SELECT
    COUNT(DISTINCT order_id)                              AS total_orders,
    ROUND(SUM(price_usd), 2)                              AS total_revenue,
    ROUND(AVG(price_usd), 2)                              AS avg_order_value,
    COUNT(DISTINCT user_id)                               AS unique_customers,
    ROUND(SUM(price_usd) / COUNT(DISTINCT user_id), 2)    AS revenue_per_customer
FROM orders
WHERE DATE(created_at) BETWEEN %s AND %s;
"""
kpi = run_query(kpi_sql, (d_start, d_end)).iloc[0]

c1, c2, c3, c4, c5 = st.columns(5)
c1.metric("📦 Total Orders",        f"{int(kpi['total_orders']):,}")
c2.metric("💰 Total Revenue",       f"${kpi['total_revenue']:,.2f}")
c3.metric("📊 Avg Order Value",     f"${kpi['avg_order_value']:,.2f}")
c4.metric("👤 Unique Customers",    f"{int(kpi['unique_customers']):,}")
c5.metric("💎 Rev / Customer",      f"${kpi['revenue_per_customer']:,.2f}")

st.divider()

# ──────────────────────────────────────────────────────
# ROW 1 — Revenue trend  |  Channel mix
# ──────────────────────────────────────────────────────
col_left, col_right = st.columns([3, 2], gap="large")

with col_left:
    st.subheader("Monthly Revenue Trend")

    trend_sql = """
    SELECT
        DATE_FORMAT(created_at, '%Y-%m')  AS month,
        ROUND(SUM(price_usd), 2)          AS revenue,
        COUNT(DISTINCT order_id)          AS orders
    FROM orders
    WHERE DATE(created_at) BETWEEN %s AND %s
    GROUP BY month
    ORDER BY month;
    """
    df_trend = run_query(trend_sql, (d_start, d_end))

    if df_trend.empty:
        st.info("No data for selected range.")
    else:
        fig = go.Figure()
        fig.add_trace(go.Scatter(
            x=df_trend["month"], y=df_trend["revenue"],
            mode="lines+markers",
            name="Revenue",
            line=dict(color="#4f8ef7", width=2.5),
            marker=dict(size=6),
            fill="tozeroy",
            fillcolor="rgba(79,142,247,0.08)",
        ))
        fig.update_layout(
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#aaaacc", family="DM Sans"),
            xaxis=dict(gridcolor="#1e1e3a", showline=False),
            yaxis=dict(gridcolor="#1e1e3a", tickprefix="$"),
            margin=dict(l=0, r=0, t=10, b=0),
            hovermode="x unified",
        )
        st.plotly_chart(fig, use_container_width=True)

with col_right:
    st.subheader("Traffic Channel Mix")

    channel_sql = """
    SELECT
        CASE
            WHEN utm_source IS NOT NULL THEN utm_source
            WHEN http_referer IS NOT NULL THEN 'organic'
            ELSE 'direct'
        END AS channel,
        COUNT(DISTINCT website_session_id) AS sessions
    FROM website_sessions
    WHERE DATE(created_at) BETWEEN %s AND %s
    GROUP BY 1
    ORDER BY 2 DESC;
    """
    df_ch = run_query(channel_sql, (d_start, d_end))

    if df_ch.empty:
        st.info("No session data.")
    else:
        colors = ["#4f8ef7","#a78bfa","#34d399","#f59e0b","#f87171","#60a5fa"]
        fig2 = px.pie(
            df_ch, names="channel", values="sessions",
            hole=0.55,
            color_discrete_sequence=colors,
        )
        fig2.update_traces(textposition="outside", textinfo="percent+label")
        fig2.update_layout(
            paper_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#aaaacc", family="DM Sans"),
            showlegend=False,
            margin=dict(l=0, r=0, t=10, b=0),
        )
        st.plotly_chart(fig2, use_container_width=True)

st.divider()

# ──────────────────────────────────────────────────────
# ROW 2 — Top customers  |  Device split
# ──────────────────────────────────────────────────────
col_a, col_b = st.columns(2, gap="large")

with col_a:
    st.subheader("Top 10 Customers by Spend")

    cust_sql = """
    SELECT
        user_id,
        COUNT(DISTINCT order_id)          AS orders,
        ROUND(SUM(price_usd), 2)          AS total_spent,
        RANK() OVER (ORDER BY SUM(price_usd) DESC) AS rnk
    FROM orders
    WHERE DATE(created_at) BETWEEN %s AND %s
    GROUP BY user_id
    ORDER BY rnk
    LIMIT 10;
    """
    df_cust = run_query(cust_sql, (d_start, d_end))

    if not df_cust.empty:
        fig3 = px.bar(
            df_cust, x="total_spent", y=df_cust["user_id"].astype(str),
            orientation="h",
            color="total_spent",
            color_continuous_scale=["#1a2a4a","#4f8ef7"],
            labels={"total_spent": "Total Spent ($)", "y": "User ID"},
            text="total_spent",
        )
        fig3.update_traces(texttemplate="$%{text:,.0f}", textposition="outside")
        fig3.update_layout(
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#aaaacc", family="DM Sans"),
            coloraxis_showscale=False,
            yaxis=dict(autorange="reversed", gridcolor="#1e1e3a"),
            xaxis=dict(gridcolor="#1e1e3a", tickprefix="$"),
            margin=dict(l=0, r=60, t=10, b=0),
        )
        st.plotly_chart(fig3, use_container_width=True)

with col_b:
    st.subheader("Desktop vs Mobile CVR")

    device_sql = """
    SELECT
        ws.device_type,
        DATE_FORMAT(ws.created_at, '%Y-%m')               AS month,
        COUNT(DISTINCT ws.website_session_id)              AS sessions,
        COUNT(DISTINCT o.order_id)                         AS orders,
        ROUND(COUNT(DISTINCT o.order_id)
              / COUNT(DISTINCT ws.website_session_id) * 100, 2) AS cvr_pct
    FROM website_sessions ws
    LEFT JOIN orders o USING (website_session_id)
    WHERE DATE(ws.created_at) BETWEEN %s AND %s
      AND ws.utm_source = 'gsearch'
      AND ws.utm_campaign = 'nonbrand'
    GROUP BY 1, 2
    ORDER BY 2, 1;
    """
    df_dev = run_query(device_sql, (d_start, d_end))

    if not df_dev.empty:
        fig4 = px.line(
            df_dev, x="month", y="cvr_pct", color="device_type",
            markers=True,
            color_discrete_map={"desktop": "#4f8ef7", "mobile": "#a78bfa"},
            labels={"cvr_pct": "CVR (%)", "month": "", "device_type": "Device"},
        )
        fig4.update_layout(
            paper_bgcolor="rgba(0,0,0,0)",
            plot_bgcolor="rgba(0,0,0,0)",
            font=dict(color="#aaaacc", family="DM Sans"),
            xaxis=dict(gridcolor="#1e1e3a"),
            yaxis=dict(gridcolor="#1e1e3a", ticksuffix="%"),
            margin=dict(l=0, r=0, t=10, b=0),
            legend=dict(bgcolor="rgba(0,0,0,0)"),
        )
        st.plotly_chart(fig4, use_container_width=True)

st.divider()

# ──────────────────────────────────────────────────────
# CONVERSION FUNNEL
# ──────────────────────────────────────────────────────
st.subheader("Conversion Funnel — gsearch Nonbrand")

funnel_sql = """
SELECT
    COUNT(DISTINCT ws.website_session_id)                                          AS sessions,
    SUM(CASE WHEN wp.pageview_url = '/products'              THEN 1 ELSE 0 END)   AS to_products,
    SUM(CASE WHEN wp.pageview_url = '/the-original-mr-fuzzy' THEN 1 ELSE 0 END)   AS to_product_page,
    SUM(CASE WHEN wp.pageview_url = '/cart'                  THEN 1 ELSE 0 END)   AS to_cart,
    SUM(CASE WHEN wp.pageview_url = '/shipping'              THEN 1 ELSE 0 END)   AS to_shipping,
    SUM(CASE WHEN wp.pageview_url = '/billing'               THEN 1 ELSE 0 END)   AS to_billing,
    SUM(CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS to_order
FROM website_sessions ws
LEFT JOIN website_pageviews wp USING (website_session_id)
WHERE DATE(ws.created_at) BETWEEN %s AND %s
  AND ws.utm_source   = 'gsearch'
  AND ws.utm_campaign = 'nonbrand';
"""
df_funnel = run_query(funnel_sql, (d_start, d_end))

if not df_funnel.empty:
    steps  = ["Sessions","Products","Product Page","Cart","Shipping","Billing","Order ✓"]
    values = [int(df_funnel.iloc[0, i]) for i in range(7)]

    fig5 = go.Figure(go.Funnel(
        y=steps, x=values,
        textinfo="value+percent initial",
        marker=dict(color=["#4f8ef7","#5b93f7","#6899f0","#7a9fe8","#8ca5df","#9dabd6","#34d399"]),
        connector=dict(line=dict(color="#2a2a4a", width=2)),
    ))
    fig5.update_layout(
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        font=dict(color="#aaaacc", family="DM Sans"),
        margin=dict(l=0, r=0, t=10, b=0),
        height=320,
    )
    st.plotly_chart(fig5, use_container_width=True)

st.divider()

# ──────────────────────────────────────────────────────
# RAW DATA EXPLORER
# ──────────────────────────────────────────────────────
with st.expander("🔎 Raw Orders — last 200 rows"):
    raw_sql = """
    SELECT
        order_id, user_id,
        DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created_at,
        items_purchased, price_usd
    FROM orders
    WHERE DATE(created_at) BETWEEN %s AND %s
    ORDER BY created_at DESC
    LIMIT 200;
    """
    df_raw = run_query(raw_sql, (d_start, d_end))
    st.dataframe(
        df_raw.style.format({"price_usd": "${:.2f}"}),
        use_container_width=True,
        hide_index=True,
    )