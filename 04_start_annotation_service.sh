#!/usr/bin/env bash

if [ "$EUID" -eq 0 ]; then
    echo "Do not run as root!"
    exit
fi

# prepare script settings
set -eEu -o pipefail
THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OLD_CWD=$(pwd)
cd $THIS_DIR

# Check for available file
if [ ! -f "./build/pretrained_data.tar.gz" ]; then
    echo "Missing $(pwd)/build/pretrained_data.tar.gz file"
    exit -1
fi

# Clone Repo
ACCESS_TOKEN="JhQmd1agg1PZi3hkGUG-"
echo "Access token is: $ACCESS_TOKEN"
git clone https://oauth2:${ACCESS_TOKEN}@git.rz.uni-augsburg.de/freijoha/annotation-service serve/annotation-service

# enter annotation service folder
cd serve/annotation-service

# Clone container
./loadOpentapiocaContainer.sh

# Generate self-signed certificates
./generateCerts.sh

# Move extracted_archive to Dockerfiles directory
cp ../../build/pretrained_data.tar.gz ./opentapioca-instance/pretrained_data.tar.gz
cp ../../build/pretrained_data.tar.gz ./opentapioca-solr/pretrained_data.tar.gz

# Edit build args file path
sed -i 's|DATASET_FILE=.*|DATASET_FILE=./pretrained_data.tar.gz|g' docker-compose.yml

# (Re-)Build images
docker-compose build --force-rm --pull --no-cache

# Cleanup pretrained_data
rm ./opentapioca-instance/pretrained_data.tar.gz
rm ./opentapioca-solr/pretrained_data.tar.gz

# Run annotation service
docker-compose up -d

# Exit directory
cd ../../

# prepare exit
unset THIS_DIR
unset OLD_CWD
