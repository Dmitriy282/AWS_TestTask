import os

from flask import Flask
from psycopg_pool import ConnectionPool

app = Flask(__name__)

# One small pool per gunicorn worker; connections stay open between requests
pool = ConnectionPool(
    os.environ.get("DATABASE_URL", ""),
    min_size=1,
    max_size=2,
    kwargs={"application_name": "flask"},
    open=bool(os.environ.get("DATABASE_URL")),
)

@app.route("/")
def hello_world():
    return "<p>Hello, World!</p>"

@app.route("/db")
def db_check():
    try:
        with pool.connection(timeout=3) as conn:
            version = conn.execute("SELECT version()").fetchone()[0]
        return f"<p>Connected to {version}</p>"
    except Exception as e:
        return f"<p>PostgreSQL connection failed: {e}</p>", 500

if __name__ == "__main__":
    app.run(debug=True)
