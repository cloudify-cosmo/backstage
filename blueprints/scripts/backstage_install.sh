#!/usr/bin/env bash


set -e

export NODE_OPTIONS=--max_old_space_size=4096

cd ${INSTALL_DIR}

scl enable devtoolset-8 llvm-toolset-7.0 - > /dev/null 2>&1 << EOF
yarn install
yarn tsc
yarn build
EOF
