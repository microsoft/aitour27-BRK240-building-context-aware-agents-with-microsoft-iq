FROM python:3.12-slim AS runtime
WORKDIR /app

# Build context is this src/ folder, so modules land flat at /app and import as
# top-level modules (e.g. `import responses_agent`).
COPY . /app/

RUN if [ -f /app/requirements.txt ]; then \
        pip install --no-cache-dir --progress-bar off --no-color -r /app/requirements.txt; \
    fi

EXPOSE 8088

ENV PORT=8088
ENV HOST=0.0.0.0
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["python", "main.py"]
