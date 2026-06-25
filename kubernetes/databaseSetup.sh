#!/bin/sh

TEMPLATE_NAME=template
SERVICE_USER=ipr_service
DATABASE_NAME=pori
SERVICE_PASSWORD=root
SECTION="--section=pre-data --section=data"
DB_DUMP_LOCATION=/docker-entrypoint-initdb.d/initialDatabase.dump
POSTGRES_USER=postgres
READONLY_USER=ipr_ro
echo "Start database setup script"
psql -U postgres -c "CREATE ROLE ipr_service; ALTER ROLE ipr_service WITH NOSUPERUSER INHERIT NOCREATEROLE CREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'root'"
psql -U postgres  -c "CREATE ROLE ipr_ro; ALTER ROLE ipr_ro WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'root'"

# create the template database
psql -U $POSTGRES_USER -c "CREATE DATABASE $TEMPLATE_NAME OWNER $SERVICE_USER IS_TEMPLATE = true;"
psql -U $POSTGRES_USER -c "GRANT CONNECT ON DATABASE $TEMPLATE_NAME TO PUBLIC; REVOKE TEMPORARY ON DATABASE $TEMPLATE_NAME FROM PUBLIC;"
psql -U $POSTGRES_USER -d "$TEMPLATE_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
psql -U $POSTGRES_USER -d "$TEMPLATE_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"fuzzystrmatch\";"
psql -U $POSTGRES_USER -d "$TEMPLATE_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";"

# import dump
# shouldn't need to create the pori database.  The pg_restore command will create it from the template.
PGPASSWORD=$SERVICE_PASSWORD createdb -U $SERVICE_USER -T $TEMPLATE_NAME $DATABASE_NAME || true
PGPASSWORD=$SERVICE_PASSWORD pg_restore -U $SERVICE_USER -n public $SECTION --no-acl --no-owner -Fc "$DB_DUMP_LOCATION" -d "$DATABASE_NAME" --clean --if-exists 2>&1

# create the RO user for demos
psql -U $POSTGRES_USER -c "GRANT CONNECT ON DATABASE $DATABASE_NAME TO $READONLY_USER;"
psql -U $POSTGRES_USER -d $DATABASE_NAME -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $READONLY_USER;"

psql -U $POSTGRES_USER -d pori -c "grant all privileges on user_metadata to ipr_ro;"
#psql -U $POSTGRES_USER -d pori -c "grant all privileges on user_tables to ipr_ro;"
psql -U $POSTGRES_USER -d pori -c "grant all privileges on user_metadata_id_seq to ipr_ro;"
psql -U $POSTGRES_USER -d pori -c "grant all privileges on all tables in schema \"public\" to ipr_ro;"

psql -U $POSTGRES_USER -d pori -c "GRANT ALL privileges ON ALL SEQUENCES IN schema public TO ipr_ro;"

psql -U $POSTGRES_USER -c "GRANT CONNECT ON DATABASE $DATABASE_NAME TO $SERVICE_USER;"
psql -U $POSTGRES_USER -d $DATABASE_NAME -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $SERVICE_USER;"

psql -U $POSTGRES_USER -d pori -c "grant all privileges on user_metadata to $SERVICE_USER;"
#psql -U $POSTGRES_USER -d pori -c "grant all privileges on user_tables to SERVICE_USER;"
psql -U $POSTGRES_USER -d pori -c "grant all privileges on user_metadata_id_seq to $SERVICE_USER;"
psql -U $POSTGRES_USER -d pori -c "grant all privileges on all tables in schema \"public\" to $SERVICE_USER;"

psql -U $POSTGRES_USER -d pori -c "GRANT ALL privileges ON ALL SEQUENCES IN schema public TO $SERVICE_USER;"



psql -U $POSTGRES_USER -d pori -c "ALTER TABLE users ADD PRIMARY KEY (id);"
psql -U $POSTGRES_USER -d pori -c "ALTER TABLE reports ADD PRIMARY KEY (id);"
psql -U $POSTGRES_USER -d pori -c "ALTER TABLE "reports_small_mutations" ADD COLUMN IF NOT EXISTS exon VARCHAR(255);"

# TODO: These need to be run after the database migration job.
#psql -U $POSTGRES_USER -d pori -c "GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE reports_seqqc TO ipr_service;"
#psql -U $POSTGRES_USER -d pori -c "GRANT ALL ON SEQUENCE reports_seqqc_id_seq TO ipr_service;"
