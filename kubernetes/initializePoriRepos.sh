#!/bin/bash
git clone http://github.com/matthewstuartedwards/pori.git
cd pori
git switch new_version_test
cd ..

git clone http://github.com/bcgsc/pori_ipr_api.git
cd pori_ipr_api
git switch release/v8.5.0
cd ..

git clone http://github.com/bcgsc/pori_graphkb_loader.git
git clone http://github.com/bcgsc/pori_graphkb_api.git
git clone http://github.com/bcgsc/pori_ipr_client.git

curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
sudo dpkg -i minikube_latest_amd64.deb
