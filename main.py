from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/")
def read_root():
    return {"status": "online", "environment": "Production", "version": "2.0"}

@app.get("/health")
def health_check():
    # k8 will ping this to ensure the pod is healthy
    return {"Status": "Healthy"}