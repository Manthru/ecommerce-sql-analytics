import mysql.connector

def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="Manthru@2004",  # change if needed
        database="mavenfuzzyfactory"
    )