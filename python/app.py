import os

import redis
from flask import Flask
from psycopg_pool import ConnectionPool

APP_NAME = "python"
HIT_KEYS = ("hits:total", f"hits:{APP_NAME}")
HITS_TTL = int(os.environ.get("HITS_TTL", 3 * 24 * 3600))

app = Flask(__name__)

# One small pool per gunicorn worker; connections stay open between requests
pool = ConnectionPool(
    os.environ.get("DATABASE_URL", ""),
    min_size=1,
    max_size=2,
    kwargs={"application_name": "flask"},
    open=bool(os.environ.get("DATABASE_URL")),
)

# Shared Redis for the hit counter. Short timeouts: if Redis is down, the site still works
cache = redis.Redis(
    host=os.environ.get("REDIS_HOST", "127.0.0.1"),
    port=int(os.environ.get("REDIS_PORT", 6379)),
    password=os.environ.get("REDIS_PASSWORD") or None,
    socket_timeout=0.5,
    socket_connect_timeout=0.5,
    decode_responses=True,
)

@app.before_request
def count_hit():
    try:
        # MULTI/EXEC: increment, and start the TTL only when the key is new (NX),
        # so the counter covers a fixed 3-day window and then starts again from 0
        with cache.pipeline() as tx:
            for key in HIT_KEYS:
                tx.incr(key)
                tx.expire(key, HITS_TTL, nx=True)
            tx.execute()
    except redis.RedisError as e:
        app.logger.warning("hit counter: %s", e)

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

@app.route("/hits")
def hits():
    try:
        apps = ("php", "python", "node")
        values = cache.mget(["hits:total", *(f"hits:{a}" for a in apps)])
        counts = dict(zip(("total", *apps), (int(v or 0) for v in values)))
        return {**counts, "ttl_seconds": cache.ttl("hits:total"), "served_by": APP_NAME}
    except redis.RedisError as e:
        return {"error": f"Redis: {e}"}, 500

if __name__ == "__main__":
    app.run(debug=True)
