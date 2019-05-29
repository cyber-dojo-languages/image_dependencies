#!/bin/bash

cat "${1}/Dockerfile" \
  | \
    docker run --rm \
      --interactive \
      --volume /var/run/docker.sock:/var/run/docker.sock \
      cyberdojo/augment_dockerfile