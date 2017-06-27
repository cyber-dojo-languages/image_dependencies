#!/bin/bash

# Runs image-builder on source living in SRC_DIR which
# can be passed as $1 but defaults to the current work directory.
# This script is curl'd and run as the only command in each
# language's .travis.yml script.

readonly SRC_DIR=${1:-`pwd`}
readonly NETWORK=src_dir_network
readonly NAME=src_dir_container

if [ ! -d "${SRC_DIR}" ]; then
  echo "${SRC_DIR} does not exist"
  exit 1
fi

if [ -z "${TRAVIS}" ]; then
  echo "Running locally"
  readonly BASE_DIR=${SRC_DIR}
else
  echo 'Running on TRAVIS'
  readonly BASE_DIR=$(dirname ${SRC_DIR})
fi

# I create a data-volume-container which holds src-dir.
# By default this lives on one network and the containers
# created inside image_builder (from its docker-compose.yml file)
# live on a different network, and thus the later won't be
# to connect to the former. To solve this I'm putting the src-dir
# data-volume-container into its own dedicated network.

docker network create ${NETWORK}

docker create \
  --volume=${BASE_DIR}:${BASE_DIR} \
  --name=${NAME} \
  --network=${NETWORK} \
  cyberdojofoundation/image_builder \
    /bin/true

docker run \
  --user=root \
  --network=${NETWORK} \
  --rm \
  --interactive \
  --tty \
  --env DOCKER_USERNAME \
  --env DOCKER_PASSWORD \
  --env SRC_DIR=${SRC_DIR} \
  --volume=/var/run/docker.sock:/var/run/docker.sock \
    cyberdojofoundation/image_builder \
      /app/build_image.rb

exit_status=$?

docker rm --force --volumes ${NAME}

docker network rm ${NETWORK}

echo "exit_status=${exit_status}"
exit ${exit_status}
