#!/usr/bin/env bash

set -a

# Talk to the user
echo "Welcome to the app 🟢 Runner"
echo ""
echo ""
echo ""

echo "Please enter your sudo password now:"
sudo echo ""
echo "Thanks! 🙏"
echo ""
echo "Ok! We'll take it from here 🚀"

echo "Making sure any stack that might exist is stopped"


# If Mac
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ ! $(which brew) ]]; then
        echo "Homebrew not installed. Please install homebrew and restart installer"
        exit
    fi
fi


if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  DISTRIB=$(awk -F= '/^ID/{print $2}' /etc/os-release)
  if [[ ${DISTRIB} = "ubuntu"* ]]; then
    echo "Grabbing latest apt caches"
    sudo apt-get update
  elif [[ ${DISTRIB} = "debian"* ]]; then
    echo "Grabbing latest apt caches"
    sudo apt update
  fi
fi


# clone app
echo "Installing app 🟢"
if [[ ! $(which git) ]]; then
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      DISTRIB=$(awk -F= '/^ID/{print $2}' /etc/os-release)
      if [[ ${DISTRIB} = "ubuntu"* ]] || [[ ${DISTRIB} = "debian"* ]]; then
        sudo apt install -y git
      elif [[ ${DISTRIB} = "fedora"* ]] || [[ ${DISTRIB} = "almalinux"* ]] || [[ ${DISTRIB} = "rockylinux"* ]] || [[ ${DISTRIB} = "rhel"* ]]; then
        sudo dnf install git -y
      fi
    fi
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install git
    fi
fi


if [[ $IS_DOCKER == "true" ]]
then
    echo "This script should run in the docker container."
else
    GIT_REPO_URL=$(git config --get remote.origin.url)

    if [[ $GIT_REPO_URL != *app* ]] # * is used for pattern matching
    then
        git clone https://github.com/slauth-io/app.git || true
        cd app
    fi
fi



# if this script is not running in CI/CD
if [ -z "$CI_PIPELINE_ID" ]
then
    if [[ $IS_DOCKER == "true" ]]
    then
        echo "Running in docker container. Skipping git pull."
    else
        git pull
    fi
fi

cd ..

if [[ ! $(which node) && ! $(node --version) ]]; then
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo "Setting up NodeJS"
        sudo curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
        export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
        nvm install lts/*
        nvm use lts/*
        sudo ln -s "$NVM_DIR/versions/node/$(nvm version)/bin/node" "/usr/local/bin/node"
        sudo ln -s "$NVM_DIR/versions/node/$(nvm version)/bin/npm" "/usr/local/bin/npm"
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install nodejs
    fi
fi

if [[ ! $(which npm) ]]; then
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      DISTRIB=$(awk -F= '/^ID/{print $2}' /etc/os-release)
      if [[ ${DISTRIB} = "ubuntu"* ]] || [[ ${DISTRIB} = "debian"* ]]; then
        echo "Setting up NPM"
        sudo apt-get install -y npm
      elif [[ ${DISTRIB} = "fedora"* ]] || [[ ${DISTRIB} = "almalinux"* ]] || [[ ${DISTRIB} = "rockylinux"* ]] || [[ ${DISTRIB} = "rhel"* ]]; then
        echo "Setting up NPM"
        sudo dnf install -y npm
      fi
    fi
fi

if [[ ! $(which docker) && ! $(docker --version) ]]; then
  echo "Setting up Docker"
  sudo curl -sSL https://get.docker.com/ | sh  
fi


# If docker still fails to install, then quit. 
if [[ ! $(which docker) && ! $(docker --version) ]]; then
  echo -e "Failed to install docker. Please install Docker manually here: https://docs.docker.com/install."
  echo -e "Exiting the app installer."
  exit
fi


# enable docker without sudo
sudo usermod -aG docker "${USER}" || true

if [[ ! $(which docker-compose) && ! $(docker compose --version) ]]; then
mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
docker compose version
fi

if [[ ! $(which gomplate) ]]; then
    ARCHITECTURE=$(uname -m)

    if [[ $ARCHITECTURE == "aarch64" ]]; then
        ARCHITECTURE="arm64"
    fi

    if [[ $ARCHITECTURE == "x86_64" ]]; then
        ARCHITECTURE="amd64"
    fi

    echo "ARCHITECTURE:"
    echo "$(uname -s) $(uname -m)"

    sudo curl -o /usr/local/bin/gomplate -sSL https://github.com/hairyhenderson/gomplate/releases/download/v3.11.3/gomplate_$(uname -s)-$ARCHITECTURE
    sudo chmod 755 /usr/local/bin/gomplate
fi



if [[ ! $(which ts-node) ]]; then
    sudo npm install -g ts-node
fi

cd app

# Create .env file if it does not exist. 
touch config.env

# Reload terminal with newly installed packages.
source ~/.bashrc


# Load env values from config.env
export $(grep -v '^#' config.env | xargs)

