#!/bin/sh
set -eu
psql -v ON_ERROR_STOP=1 -f /schema.sql
for migration in /migrations/*.sql; do
  echo "Applying $migration"
  psql -v ON_ERROR_STOP=1 -f "$migration"
done
