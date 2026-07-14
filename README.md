# Staff Management — Phase 1 Backend

Decoupled API backend: **FastAPI + SQLModel + PostgreSQL**, all in Docker.
This covers Build Step 1 — the database foundation and the `/auth/login` route.

## Layout

```
staffmgmt/
├── docker-compose.yml        # Postgres + backend
├── .env.example              # copy to .env
└── backend/
    ├── Dockerfile
    ├── requirements.txt
    └── app/
        ├── main.py           # app + startup (create tables, seed admin)
        ├── seed.py           # idempotent first-run seeding
        ├── core/
        │   ├── config.py     # env-driven settings
        │   ├── security.py   # bcrypt + JWT
        │   └── database.py   # engine + session
        ├── models/models.py  # FULL schema (all blueprint tables + notifications)
        ├── schemas/auth.py   # request/response models
        └── api/
            ├── deps.py       # JWT verify + role guard
            └── routes/auth.py
```

## 1. Run it

```bash
cd staffmgmt
cp .env.example .env          # then edit JWT_SECRET_KEY + the seed admin password
docker compose up --build
```

First boot will: start Postgres, build the API image, create every table, and
seed a Super Admin. Watch for the API at:

- API root / docs:  http://localhost:8000/docs
- Health check:     http://localhost:8000/health

(Use `docker compose up -d --build` to run detached; `docker compose logs -f backend`
to tail logs; `docker compose down` to stop; `docker compose down -v` to also wipe
the database volume and start fresh.)

## 2. Test login

Default seeded account (override in `.env`):

```
username: superadmin
password: ChangeMe123!
```

Get a token:

```bash
curl -s -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"superadmin","password":"ChangeMe123!"}'
```

You'll get back `access_token`, `role`, `user_id`, `tenant_id`. Verify the token:

```bash
TOKEN="paste-the-access_token-here"
curl -s http://localhost:8000/api/v1/auth/me -H "Authorization: Bearer $TOKEN"
```

Or just use the **Authorize** button in `/docs` and try the endpoints there.

## 3. Inspect the DB (optional)

Postgres is exposed on `localhost:5432`. Connect with any client using the
credentials from `.env`, or:

```bash
docker compose exec db psql -U staffadmin -d staffmgmt -c "\dt"
```

## Notes on what changed vs. the original blueprint

- **Composite uniqueness for multi-tenancy.** `payroll_id`, `email`, and
  `username` are unique *per `tenant_id`* (`UNIQUE (tenant_id, <col>)`), not
  globally — otherwise two tenants could never reuse the same value.
- **`role` is CHECK-constrained** to the four allowed roles at the DB level.
- **`notifications` table added** — Step 4 needs an Admin notification queue that
  the original blueprint didn't define.

## Heads-up for later steps

- `/auth/login` currently looks a user up by `username` alone. That's correct for
  Phase 1 (single tenant). Once you go true multi-tenant, you'll need a tenant
  discriminator (subdomain, header, or an org field on the login form) so the same
  username can exist in different tenants without ambiguity.
- Tables are created with `SQLModel.metadata.create_all` on startup. Move to
  **Alembic** migrations before the schema starts changing in production.
