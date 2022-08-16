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
git clone https://oauth2:${ACCESS_TOKEN}@git.rz.uni-augsburg.de/freijoha/annotation-nif-generation build/annotation-nif-generation

# Copy files
CONFIG_LOAD_FILE="./cfg/load_config.json"
CONFIG_PROFILE_FILE="./cfg/opentapioca_profile.json"

cp $CONFIG_LOAD_FILE build/annotation-nif-generation/nif-data/
cp $CONFIG_PROFILE_FILE build/annotation-nif-generation/nif-data/
wiki_lang_code=$(jq -r '.["wiki_language_code"]' "$CONFIG_LOAD_FILE")
max_cpu_workers=$(jq -r '.["max_cpu_workers"]' "$CONFIG_LOAD_FILE")

cd build/annotation-nif-generation

# Start docker
docker-compose up -d --build

# Reuse downloaded files
shared_dir="../shared"
if [ ! -d "$shared_dir" ]; then
    mkdir -p "$shared_dir"
fi

wiki_files=("latest-all.json.bz2"
            "${wiki_lang_code}wiki-latest-redirect.sql.gz"
            "${wiki_lang_code}wiki-latest-pagelinks.sql.gz"
            "${wiki_lang_code}wiki-latest-pages-meta-current.xml.bz2")

nif_data_dir="./nif-data"
if [ ! -d "$nif_data_dir" ]; then
    mkdir -p "$nif_data_dir"
    sudo chown root:root "$nif_data_dir"
fi

for wikifile in ${wiki_files[@]}; do
    if [ -f "$shared_dir/$wikifile" ]; then
        echo "Reuse file: $wikifile"
        sudo mv "$shared_dir/$wikifile" "$nif_data_dir/$wikifile"
    fi
done

echo "Downloading missing files"
# Download data
docker-compose exec -T wiki-nif-loader sh -c './mongowiki/loadData.sh 2>&1 | tee ./mongowiki/data/loadData_$(date +%s).log'
# Process data (takes ~1-3 days)
docker-compose exec -T wiki-nif-loader sh -c "PYTHONPATH=. python3 mongowiki/processData.py ${max_cpu_workers} 2>&1 | tee ./mongowiki/data/processData_$(date +%s).log"

# Clean nif-data.nif file, if exists
if [ -f "./nif-data/nif-data.nif" ]; then
    echo "Remove existing NIF file"
    sudo rm "./nif-data/nif-data.nif"
fi

# Generate NIF
docker-compose exec -T wiki-nif-loader sh -c "PYTHONPATH=. python3 generateNIF.py -c ${max_cpu_workers} mongowiki/data/opentapioca_profile.json ./mongowiki/data/nif-data.nif 2>&1 | tee ./mongowiki/data/generateNIF_$(date +%s).log"

# Shut down container
docker-compose down -v

# Extract NIF file
sudo chown $(whoami):$(whoami) nif-data/nif-data.nif
cp nif-data/nif-data.nif ../shared/nif-data.nif

# Move back wiki files
for wikifile in ${wiki_files[@]}; do
    echo "Move to shared files: $wikifile"
    sudo mv "$nif_data_dir/$wikifile" "$shared_dir/$wikifile"
    sudo chown $(whoami):$(whoami) "$shared_dir/$wikifile"
done

# Exit annotation-nif-generation directory
cd ../../

# prepare exit
unset THIS_DIR
unset OLD_CWD
