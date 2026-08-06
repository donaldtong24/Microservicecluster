from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
import os
import psycopg2

app = FastAPI()

# Exposes /metrics in Prometheus exposition format (request counts, latency
# histograms, in-progress requests) — scraped by the ServiceMonitor in
# charts/python-microservice/templates/servicemonitor.yaml.
Instrumentator().instrument(app).expose(app)

# Set via env.DATABASE_URL (values-prod.yaml -> kubernetes_secret in
# database.tf). Unset locally/dev — /visits reports that instead of crashing.
DATABASE_URL = os.environ.get("DATABASE_URL")


def get_connection():
    return psycopg2.connect(DATABASE_URL)


@app.on_event("startup")
def init_db():
    if not DATABASE_URL:
        return
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS visits (
                    id SERIAL PRIMARY KEY,
                    count INTEGER NOT NULL DEFAULT 0
                )
                """
            )
            cur.execute(
                "INSERT INTO visits (count) SELECT 0 WHERE NOT EXISTS (SELECT 1 FROM visits)"
            )
        conn.commit()


@app.get("/")
def read_root():
    return {"status": "online :)", "environment": "Production", "version": "3.0"}

@app.get("/health")
def health_check():
    # k8 will ping this to ensure the pod is healthy
    return {"Status": "Healthy"}


@app.get("/visits")
def record_visit():
    # Increments and returns a counter stored in RDS Postgres — the app's
    # one real read/write path against the database.
    if not DATABASE_URL:
        return {"error": "DATABASE_URL not configured"}
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("UPDATE visits SET count = count + 1 RETURNING count")
            count = cur.fetchone()[0]
        conn.commit()
    return {"visits": count}