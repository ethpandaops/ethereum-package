#!/bin/sh
set -xe

git clone https://@github.com/lu-bann/taiyi.git
cd taiyi/contracts
forge build
sh script/deploy.sh

