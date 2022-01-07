#!/bin/bash
set -eu -o pipefail

# install terraform latest version
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform-1.1.2-1.x86_64
