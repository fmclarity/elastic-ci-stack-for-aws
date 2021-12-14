#!/bin/bash
set -eu -o pipefail

# install nodejs 14 and npm
curl -sL https://rpm.nodesource.com/setup_14.x | sudo bash -
sudo yum install -y nodejs

# install yarn
sudo npm install -y --global yarn
