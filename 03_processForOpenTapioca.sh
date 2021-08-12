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

# Clone Repo
ACCESS_TOKEN="JhQmd1agg1PZi3hkGUG-"
echo "Access token is: $ACCESS_TOKEN"
git clone https://oauth2:${ACCESS_TOKEN}@git.rz.uni-augsburg.de/freijoha/opentapioca build/opentapioca

# enter OpenTapioca folder
cd build/opentapioca
cd dockerized-devel

CONFIG_LOAD_FILE="../../../cfg/load_config.json"
WIKIDATA_ENDPOINT=$(jq -r '.["wikidata_endpoint"]' $CONFIG_LOAD_FILE)
OPENTAPIOCA_ITERATIONS=$(jq -r '.["opentapioca-iterations"]' $CONFIG_LOAD_FILE)

CONFIG_PROFILE_FILE="../../../cfg/opentapioca_profile.json"

# Create devel-data directory
if [ ! -d "./devel-data" ]; then
    echo "Create devel-data directory"
    sudo mkdir -p ./devel-data
fi

# Use existing files from shared folder
CACHED=0
echo "Copy files in root-owned folder"
if [ -f "../../shared/latest-all.json.bz2" ]; then
    echo "Using cached latest-all.json.bz2"
    CACHED=1
    sudo mv "../../shared/latest-all.json.bz2" "./devel-data/latest-all.json.bz2"
fi

# Add files from former scripts
sudo cp $CONFIG_PROFILE_FILE ./devel-data/opentapioca_profile.json
sudo cp "../../shared/nif-data.nif" ./devel-data/nif-data.nif

# (Re-)Build images
sed -i "s|WIKIDATA_QUERY_ENDPOINT=.*|WIKIDATA_QUERY_ENDPOINT=$WIKIDATA_ENDPOINT|g" docker-compose.yml
docker-compose build --force-rm --pull --no-cache

# Start docker
docker-compose up -d
# Wait till mongodb is up
sleep 10

# Drop all existing collections
EXISTING_COLLECTIONS=$(docker-compose exec opentapioca-solr curl http://localhost:8983/solr/admin/collections?action=list 2>/dev/null | python3 -c "import json, sys; print('\n'.join(json.loads(sys.stdin.read())['collections']))")

echo $EXISTING_COLLECTIONS | while read line; do
    if [ ! -z "$line" ]; then
        echo "Delete collection: $line"
        docker-compose exec -T opentapioca-solr curl http://localhost:8983/solr/admin/collections?action=DELETE&name=$line
    fi
done


# Run OpenTapioca setup pipeline
docker-compose exec opentapioca-devel sh -c "./main_run.sh data/opentapioca_profile.json data/nif-data.nif $OPENTAPIOCA_ITERATIONS"

# Extract files
./buildArchive.sh

# Move back latest-all.json.bz2
if [ "$CACHED" -eq 1 ]; then
    echo "Move back cached file"
    sudo mv ./devel-data/latest-all.json.bz2 "../../shared/latest-all.json.bz2"
    sudo chown $(whoami):$(whoami) "../../shared/latest-all.json.bz2"
elif [ ! -f "../../shared/latest-all.json.bz2" ]; then
    echo "Save latest-all.json.bz2 to shared directory"
    sudo mv "./devel-data/latest-all.json.bz2" "../../shared/latest-all.json.bz2"
    sudo chown $(whoami):$(whoami) "../../shared/latest-all.json.bz2"
fi

# Shut down docker
docker-compose down -v

# Move extracted archive
mv ./extracted_archive.tar.gz ../../pretrained_data.tar.gz

# Exit directory
cd ../../

# prepare exit
unset THIS_DIR
unset OLD_CWD
