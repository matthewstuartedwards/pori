#!/bin/sh

TEMPLATE_NAME=template
SERVICE_USER=ipr_service
DATABASE_NAME=pori
SERVICE_PASSWORD=root
SECTION="--section=pre-data --section=data"
DB_DUMP_LOCATION=/docker-entrypoint-initdb.d/ipr_new_deployment.postgres.dump
POSTGRES_USER=postgres
READONLY_USER=ipr_ro

psql -U postgres -c "CREATE ROLE ipr_service; ALTER ROLE ipr_service WITH NOSUPERUSER INHERIT NOCREATEROLE CREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'root'"
psql -U postgres  -c "CREATE ROLE ipr_ro; ALTER ROLE ipr_ro WITH NOSUPERUSER INHERIT NOCREATEROLE NOCREATEDB LOGIN NOREPLICATION NOBYPASSRLS PASSWORD 'root'"

# create the template database
psql -U $POSTGRES_USER -c "CREATE DATABASE $TEMPLATE_NAME OWNER $SERVICE_USER IS_TEMPLATE = true;"
psql -U $POSTGRES_USER -c "GRANT CONNECT ON DATABASE $TEMPLATE_NAME TO PUBLIC; REVOKE TEMPORARY ON DATABASE $TEMPLATE_NAME FROM PUBLIC;"
psql -U $POSTGRES_USER -d "$TEMPLATE_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
psql -U $POSTGRES_USER -d "$TEMPLATE_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"fuzzystrmatch\";"
psql -U $POSTGRES_USER -d "$TEMPLATE_NAME" -c "CREATE EXTENSION IF NOT EXISTS \"pg_trgm\";"

# import dump
PGPASSWORD=$SERVICE_PASSWORD createdb -U $SERVICE_USER -T $TEMPLATE_NAME $DATABASE_NAME
PGPASSWORD=$SERVICE_PASSWORD pg_restore -U $SERVICE_USER -n public $SECTION --no-acl --no-owner -Fc "$DB_DUMP_LOCATION" -d "$DATABASE_NAME"

# create the RO user for demos
psql -U $POSTGRES_USER -c "GRANT CONNECT ON DATABASE $DATABASE_NAME TO $READONLY_USER;"
psql -U $POSTGRES_USER -d $DATABASE_NAME -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO $READONLY_USER;"

psql -U $POSTGRES_USER -d pori -c "grant all privileges on user_metadata to ipr_ro;"
psql -U $POSTGRES_USER -d pori -c "grant all privileges on user_tables to ipr_ro;"
psql -U $POSTGRES_USER -d pori -c "grant all privileges on user_metadata_id_seq to ipr_ro;"
psql -U $POSTGRES_USER -d pori -c "grant all privileges on all tables in schema \"public\" to ipr_ro;"

psql -U $POSTGRES_USER -d pori -c "GRANT ALL privileges ON ALL SEQUENCES IN schema public TO ipr_ro;"
