#!/bin/bash

# Get into the graphkb container
PODNAME=$(kubectl get pods -n graphkb --no-headers | awk '{print $1}' | grep '^db-' | head -n 1 ) 

kubectl exec -n graphkb $PODNAME -- apt update && apt install -y lvm2 zip
kubectl exec -n graphkb $PODNAME -- ./bin/backup.sh remote:localhost/orientdb root root /root/backup.zip

# NOTE: This script did not work because of the following:
# ./bin/backup.sh remote:localhost/graphkb/ root root /root/backup.zip
#Error: java.lang.UnsupportedOperationException: backup is not supported against remote storage. Open the database with plocal or use the incremental backup in the Enterprise Edition

#NOTE: I think this will work after setting up a persistent storage for the graphkb database
#      You have to get a lock on the database for this to work.  Not sure how to do that yet.
./bin/backup.sh plocal:/orientdb/databases/graphkb root root /root/backup.zip

# Copy the backed up database to the current directory.
kubectl cp -n graphkb $PODNAME:/root/backup.zip .