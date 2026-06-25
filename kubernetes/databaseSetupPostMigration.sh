#!/bin/sh

TEMPLATE_NAME=template
SERVICE_USER=ipr_service
DATABASE_NAME=pori
SERVICE_PASSWORD=root
SECTION="--section=pre-data --section=data"
DB_DUMP_LOCATION=/docker-entrypoint-initdb.d/initialDatabase.dump
POSTGRES_USER=postgres
READONLY_USER=ipr_ro
echo "Start post migraiton database setup script"

psql -U $POSTGRES_USER -d pori -c "GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE reports_seqqc TO $SERVICE_USER;"
psql -U $POSTGRES_USER -d pori -c "GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE reports_seqqc TO $READONLY_USER;"
psql -U $POSTGRES_USER -d pori -c "GRANT ALL ON SEQUENCE reports_seqqc_id_seq TO $SERVICE_USER;"
psql -U $POSTGRES_USER -d pori -c "GRANT ALL ON SEQUENCE reports_seqqc_id_seq TO $READONLY_USER;"
