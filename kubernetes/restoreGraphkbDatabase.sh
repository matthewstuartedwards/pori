#!/bin/bash

# Get into the graphkb container
PODNAME=$(kubectl get pods -n graphkb --no-headers | awk '{print $1}' | grep '^db-' | head -n 1 ) 

# Copy the backed up database to the pod
kubectl cp -n graphkb ./backup.zip $PODNAME:/root/backup.zip

ORIENTDB_CONSOLE_PATH"/orientdb/bin/console.sh"
BACKUP_FILE_PATH="/root/backup.zip"
RESTORE_COMMAND="RESTORE DATABASE $BACKUP_FILE_PATH"

# Totally untested so far.
kubectl exec -n graphkb $PODNAME -- echo $RESTORE_COMMAND | $ORIENTDB_CONSOLE_PATH

