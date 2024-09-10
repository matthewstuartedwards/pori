export IPR_DB_PORT=5433 # if you don't already have a psql instance running locally, you don't need to set this

export KEYCLOAK_ADMIN_USER=admin
export KEYCLOAK_ADMIN_PASS=admin
export KEYCLOAK_TOKEN_URI=http://keycloak:8888/auth/realms/PORI/protocol/openid-connect/token
export KEYCLOAK_AUTH_URL=http://localhost:8888/auth

export GKB_DBS_PASS=root

export IPR_POSTGRES_USER=postgres
export IPR_POSTGRES_PASSWORD=root # set this

export IPR_DATABASE_HOSTNAME=db.ipr.svc.cluster.local
export IPR_DATABASE_NAME=ipr
export IPR_DATABASE_USERNAME=ipr_service
export IPR_DATABASE_PASSWORD=root #set this
export IPR_DATABASE_ADMINNAME=ipr_service

export IPR_GRAPHKB_USERNAME=ipr_graphkb_link
export IPR_GRAPHKB_PASSWORD=ipr_graphkb_link

export IPR_KEYCLOAK_KEYFILE=/keys/keycloak.key

export IPR_SERVICE_USER=ipr_service
export SERVICE_PASSWORD=root # set this

export GRAPHKB_DB_BACKUP=./databases/orientdb/backup
export GRAPHKB_DB_DATA=./databases/orientdb/data
export PSQL_DB_BACKUP=./databases/postgresql/backup
export PSQL_DB_DATA=./databases/postgresql/data

export SCHEMA_DUMP_LOCATION=../

export PORI_ADMIN_EMAIL=
export PORI_ADMIN_USER='pori_admin'
export TEMPLATE_NAME='templateipr'
