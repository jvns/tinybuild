#!/bin/bash

set -e
usage() {
    echo "Usage: $0 -s <script> -d <dockerfile> -l <localdir> -c <containerdir>"
    exit 1
}

# Parse arguments

while getopts s:d:l:c: flag
do
    case "${flag}" in
        s) script=${OPTARG};;
        d) dockerfile=${OPTARG};;
        l) localdir=${OPTARG};;
        c) containerdir=${OPTARG};;
        *) usage;;
    esac
done

if [ -z "${script}" ] || [ -z "${localdir}" ] || [ -z "${containerdir}" ]; then
    usage
fi

if [ -z "${dockerfile}" ]; then
    dockerfile="Dockerfile"
fi

set -ux

# make sure volume doesn't exist
if [ -d "$localdir" ]; then
    echo "Directory $localdir already exists"
    exit 1
fi

mkdir "$localdir"

DIRNAME=$(basename "$(pwd)")
IMAGE_NAME="tinybuild-$DIRNAME"
docker build - -t "$IMAGE_NAME" < Dockerfile
CONTAINER_ID=$(docker run -v "$PWD":/src -v "$localdir:/artifact:z" -d -t "$IMAGE_NAME" /bin/bash)
docker exec "$CONTAINER_ID" bash -c "chmod 777 /"
if ! docker exec --user 1000:1000 "$CONTAINER_ID" bash -c "git clone /src /build && cd /build && bash /src/$script"
then
    echo "Build failed"
    docker kill "$CONTAINER_ID"
    rmdir "$localdir"
    exit 1
fi
docker exec "$CONTAINER_ID" bash -c "mv $containerdir/* /artifact"
docker kill "$CONTAINER_ID"
