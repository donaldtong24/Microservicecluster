from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
import os

app = FastAPI()

# Exposes /metrics in Prometheus exposition format (request counts, latency
# histograms, in-progress requests) — scraped by the ServiceMonitor in
# charts/python-microservice/templates/servicemonitor.yaml.
Instrumentator().instrument(app).expose(app)

@app.get("/")
def read_root():
    return {"status": "online :)", "environment": "Production", "version": "3.0"}

@app.get("/health")
def health_check():
    # k8 will ping this to ensure the pod is healthy
    return {"Status": "Healthy"}