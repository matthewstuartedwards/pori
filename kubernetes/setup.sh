#!/bin/bash
#eval $(minikube docker-env) # This is needed whenever building a local docker image.  If not used, newly built containers will never be found by Kubernetes.
kubectl create namespace graphkb
kubectl create namespace ipr
kubectl create namespace security
kubectl create namespace db
kubectl apply -f (string join ',' *.yaml)