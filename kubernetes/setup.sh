#!/bin/bash
kubectl create namespace graphkb
kubectl create namespace ipr
kubectl create namespace security
kubectl create namespace db
kubectl apply -f (string join ',' *.yaml)