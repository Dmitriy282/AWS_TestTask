#!/bin/sh
# Runs once, on the first start with an empty data volume.
# POSTGRES_DB is created by the image itself; this creates the extra ones.
set -e

for db in $(echo "$POSTGRES_EXTRA_DATABASES" | tr ',' ' '); do
    echo "Creating database: $db"
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres \
        -c "CREATE DATABASE \"$db\" OWNER \"$POSTGRES_USER\";"
done
