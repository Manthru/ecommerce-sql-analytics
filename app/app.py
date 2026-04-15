import streamlit as st
import pandas as pd
import mysql.connector

# 🔌 Database connection function
def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="1234",  # change if needed
        database="mavenfuzzyfactory"
    )

conn = get_connection()

# 🎯 App Title
st.title("🛒 E-Commerce Analytics Dashboard")

# 📈 Revenue Trend
st.subheader("📈 Monthly Revenue Trend")

query1 = """
SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    SUM(price_usd) AS revenue
FROM orders
GROUP BY month
ORDER BY month;
"""

df1 = pd.read_sql(query1, conn)
st.line_chart(df1.set_index("month"))

# 🏆 Top Customers
st.subheader("🏆 Top 10 Customers")

query2 = """
SELECT 
    user_id,
    SUM(price_usd) AS total_spent
FROM orders
GROUP BY user_id
ORDER BY total_spent DESC
LIMIT 10;
"""

df2 = pd.read_sql(query2, conn)
st.bar_chart(df2.set_index("user_id"))

# 📦 Total Orders
st.subheader("📦 Total Orders")

query3 = "SELECT COUNT(*) AS total_orders FROM orders;"
df3 = pd.read_sql(query3, conn)

st.metric("Total Orders", int(df3["total_orders"][0]))

# 🔥 Extra Insight (NEW - makes it stand out)
st.subheader("💰 Average Order Value")

query4 = "SELECT ROUND(AVG(price_usd),2) AS avg_order FROM orders;"
df4 = pd.read_sql(query4, conn)

st.metric("Average Order Value", df4["avg_order"][0])