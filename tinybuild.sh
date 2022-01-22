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

set -u

# make sure volume doesn't exist
if [ -d "$localdir" ]; then
    echo "Directory $localdir already exists"
    exit 1
fi

# create the directory outside the container so that it's owned by my user to
# avoid permission issues
mkdir "$localdir"

DIRNAME=$(basename "$(pwd)")
IMAGE_NAME="tinybuild-$DIRNAME"
# Don't send the current directory to the Docker daemon, to speed up builds
docker build - -t "$IMAGE_NAME" < Dockerfile
CONTAINER_ID=$(docker run -v "$PWD":/src -v "$localdir:/artifact:z" -d -t "$IMAGE_NAME" /bin/bash)
# more permission nonsense, so that the git clone on the next line works
docker exec "$CONTAINER_ID" bash -c "chmod 777 /"
# set uid to 1000 to avoid permission issues, this is just hardcoded to my uid
if ! docker exec --user 1000:1000 "$CONTAINER_ID" bash -c "git clone /src /build && cd /build && bash /src/$script"
then
    echo "Build failed"
    docker kill "$CONTAINER_ID"
    rmdir "$localdir"
    exit 1
fi
docker exec "$CONTAINER_ID" bash -c "mv $containerdir/* /artifact"
docker kill "$CONTAINER_ID"
