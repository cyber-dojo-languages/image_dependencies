#!/bin/bash

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"

docker build --tag cyberdojofoundation/image_builder ${MY_DIR}