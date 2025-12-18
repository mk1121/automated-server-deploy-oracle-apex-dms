#!/bin/bash
# run_docker_test.sh
# Builds and runs the AlmaLinux 8 test container.

set -e

echo "Building Docker Image..."
docker build -t oracle-install-test .

echo "Starting Container..."
echo "Mounting $(pwd)/../server_setup to /root/server_setup"

# We run in interactive mode (-it) so the user gets a shell.
# --rm removes the container after exit.
docker run --rm -it \
    -v "$(pwd)/../server_setup:/root/server_setup" \
    oracle-install-test

