#build dependencies
FROM python:3.11-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

#final runtime image
FROM python:3.11-slim

WORKDIR /app
#copy only the installed packages from the builder stage
COPY --from=builder /root/.local /root/.local
COPY . .

#update path to uinclude the user-installed binaries
ENV PATH=/root/.local/bin:$PATH
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]