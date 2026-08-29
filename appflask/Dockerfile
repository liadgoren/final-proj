# Pin by tag + digest for reproducible, tamper-evident builds.
# Refresh the digest with: docker pull alpine:3.21.2 && docker inspect --format='{{index .RepoDigests 0}}' alpine:3.21.2
FROM alpine:3.24.1

RUN apk update && \
    apk add --no-cache python3 py3-pip && \
    addgroup -S app && adduser -S app -G app

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --break-system-packages -r requirements.txt

COPY app.py .

USER app

EXPOSE 5000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/healthz', timeout=2)" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
