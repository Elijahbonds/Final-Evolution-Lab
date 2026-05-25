FROM python:3.9-slim
WORKDIR /app
RUN pip install --no-cache-dir websockets
COPY ws_hud_server.py .
EXPOSE 8080
CMD ["python", "ws_hud_server.py", "--port", "8080"]
