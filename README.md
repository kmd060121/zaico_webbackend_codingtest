# zaico_webbackend_codingtest

Rails 8.1.2 scaffold with a minimal Docker Compose setup for local development.

## Local development (Docker Compose)

1. `docker compose build`
2. `docker compose up`
3. Open `http://localhost:3000`

The container entrypoint runs `bin/rails db:prepare` automatically on boot.
