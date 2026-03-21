# Voice Agent API — Spring Boot Backend

Java 17 / Spring Boot 3.2 backend for Voice Agent. Provides REST APIs for dictation history, correction tracking, rule management, and user settings. Secured with Supabase JWT authentication.

## Quick Start

### Prerequisites

- Java 17+
- Maven 3.8+ (or use the included `mvnw` wrapper)
- PostgreSQL 16 (or use Docker)
- A Supabase project (for auth and hosted Postgres)

### Run Locally (Maven)

```bash
# Set required environment variables
export SUPABASE_JWT_SECRET=your-supabase-jwt-secret
export SUPABASE_DB_HOST=localhost
export SUPABASE_DB_PORT=5432
export SUPABASE_DB_NAME=voiceagent
export SUPABASE_DB_USER=postgres
export SUPABASE_DB_PASSWORD=postgres

# Start the application
./mvnw spring-boot:run
```

The API will be available at `http://localhost:8080`.

### Run with Docker

```bash
# Copy and fill in environment variables
cp .env.example .env
# Edit .env with your values

# Start everything (API + Postgres)
docker-compose up --build

# Or run in detached mode
docker-compose up --build -d
```

## API Endpoints

All endpoints except `/api/health` require a valid Supabase JWT in the `Authorization: Bearer <token>` header.

### Health

| Method | Path           | Description          |
|--------|----------------|----------------------|
| GET    | `/api/health`  | Health check (public)|

### Dictations

| Method | Path               | Description                              |
|--------|--------------------|------------------------------------------|
| GET    | `/api/dictations`  | List dictations (query: userId, search, limit) |
| POST   | `/api/dictations`  | Store a new dictation                    |

### Corrections

| Method | Path                    | Description                              |
|--------|-------------------------|------------------------------------------|
| GET    | `/api/corrections`      | List corrections (query: userId, limit)  |
| POST   | `/api/corrections`      | Batch create/upsert corrections          |
| DELETE | `/api/corrections/{id}` | Delete a correction by ID                |

### Rules

| Method | Path                 | Description                              |
|--------|----------------------|------------------------------------------|
| GET    | `/api/rules`         | Get compressed rules (query: userId)     |
| POST   | `/api/rules/refresh` | Regenerate rules from patterns + AI (query: userId) |
| POST   | `/api/rules/compare` | Compare pattern-based vs cloud-refined rules |

### Settings

| Method | Path              | Description                              |
|--------|-------------------|------------------------------------------|
| GET    | `/api/settings`   | Get all settings (query: userId)         |
| POST   | `/api/settings`   | Create or update a setting               |

## Environment Variables

| Variable                | Required | Description                                   |
|-------------------------|----------|-----------------------------------------------|
| `SUPABASE_JWT_SECRET`   | Yes      | JWT secret from Supabase (Settings > API)     |
| `SUPABASE_DB_HOST`      | Yes      | Postgres host (use `db.xxx.supabase.co` for Supabase) |
| `SUPABASE_DB_PORT`      | No       | Postgres port (default: 5432)                 |
| `SUPABASE_DB_NAME`      | No       | Database name (default: voiceagent)           |
| `SUPABASE_DB_USER`      | Yes      | Postgres username                             |
| `SUPABASE_DB_PASSWORD`  | Yes      | Postgres password                             |
| `CLOUDFLARE_ACCOUNT_ID` | Yes      | Cloudflare account ID for Workers AI          |
| `CLOUDFLARE_API_TOKEN`  | Yes      | Cloudflare API token with Workers AI access   |

## Connecting to Supabase

1. Create a project at [supabase.com](https://supabase.com).
2. Go to **Settings > API** and copy the **JWT Secret**.
3. Go to **Settings > Database** and copy the connection details (host, port, user, password).
4. Set the environment variables listed above with your Supabase values.
5. Flyway migrations will run automatically on startup to set up the schema.

## Project Structure

```
backend/
  src/main/java/com/voiceagent/api/
    config/         # SecurityConfig, JwtUtils, CORS, JPA, Cloudflare config
    controller/     # REST controllers (Health, Dictation, Correction, Rule, Settings)
    dto/            # Data transfer objects
    model/          # JPA entities (User, Dictation, Correction, Rule, Setting, Context)
    repository/     # Spring Data JPA repositories
    service/        # Business logic services
  src/main/resources/
    application.yml # Application configuration
    db/migration/   # Flyway SQL migrations
  Dockerfile        # Multi-stage Docker build
  docker-compose.yml# Local dev stack (API + Postgres)
  pom.xml           # Maven dependencies
```
