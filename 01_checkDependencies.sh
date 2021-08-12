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

# Check last command and remove file if given
checkSuccess() {
    if [ $1 -eq 0 ]; then
        echo "...succeeded."
    else
        echo -n "...but execution FAILED!"
        if [ ! -z $2 ]; then
            if [ -f $2 ]; then
                echo -n " -> delete file: $2"
                rm $2
            fi
        fi
        echo ""
        exit -1
    fi
}

# check required commands
required_commands=(
    "git"
    "tar"
    "docker"
    "docker-compose"
    "jq"
    "python3"
    "openssl"
)

ubuntu_packages=(
    "git"
    "tar tar-doc"
    "docker.io"
    "docker-compose"
    "jq"
    "python3"
    "openssl"
)


# Install every missing command
pkg_index_updated=""
for (( i=0; i<${#required_commands[*]}; ++i)); do
    cmd=${required_commands[$i]}
    pkg=${ubuntu_packages[$i]}

    if ! which $cmd 2>&1 >/dev/null; then
        # command is missing
        if [ -n "$(uname -a | grep Ubuntu)" ]; then
            # Check whether we need to update the package index
            if [ -z $pkg_index_updated ]; then
                echo "Updating package index..."
                sudo apt-get update -y
                checkSuccess $?
                pkg_index_updated="updated"
            fi
            echo "Installing package $pkg that provides command $cmd..."
            sudo apt-get install -y $pkg
            checkSuccess $?
        else
            echo "Please install command: $cmd"
            exit -1
        fi
    else
        echo "Command $cmd found."
    fi
done



# Check if docker works (without sudo permissions)
if ! docker ps >/dev/null 2>&1; then
    echo "Docker failed"

    if [ -n "$(uname -a | grep Ubuntu)" ]; then
        echo "Try to start Docker daemon..."
        sudo systemctl enable docker
        sudo systemctl start docker
        echo "Add user $(whoami) to docker group"
        sudo usermod -aG docker $(whoami)
        echo "Reboot to apply changes"
    else
        echo "Enable the Docker daemon and add the user $(whoami) to docker group (and reboot to apply changes)"
    fi
    exit -1
fi

cd $OLD_CWD
# prepare exit
unset THIS_DIR
unset OLD_CWD
