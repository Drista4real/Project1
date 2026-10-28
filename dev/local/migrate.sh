#!/bin/sh
set -eu
if [ "$(psql -Atqc "SELECT to_regclass('public.profiles') IS NULL")" = "t" ]; then
  psql -v ON_ERROR_STOP=1 -f /schema.sql
fi
psql -v ON_ERROR_STOP=1 -c 'CREATE TABLE IF NOT EXISTS public.local_demo_migrations (name text PRIMARY KEY, checksum text NOT NULL); REVOKE ALL ON public.local_demo_migrations FROM anon, authenticated;'
for migration in /migrations/*.sql; do
  name=$(basename "$migration")
  case "$name" in *[!0-9a-z_.]*) echo "Invalid migration name"; exit 1;; esac
  checksum=$(sha256sum "$migration" | cut -d ' ' -f 1)
  previous=$(psql -Atqc "SELECT checksum FROM public.local_demo_migrations WHERE name = '$name'")
  if [ "$previous" = "$checksum" ]; then continue; fi
  if [ -n "$previous" ]; then
    echo "Applied migration $name changed. Add a new migration or reset this demo database."
    exit 1
  fi
  psql -v ON_ERROR_STOP=1 -f "$migration"
  psql -v ON_ERROR_STOP=1 -c "INSERT INTO public.local_demo_migrations VALUES ('$name', '$checksum')"
done
