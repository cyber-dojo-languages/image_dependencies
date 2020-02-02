#!/bin/bash -Ee

# - - - - - - - - - - - - - - - - - - - - - - -
# Curl'd and run in CircleCI scripts of all
# repos of the cyber-dojo-languages organization.
#
# Note: TMP_DIR is off ~ and not /tmp because if we are
# not running on native Linux (eg on Docker-Toolbox on a Mac)
# then we need the TMP_DIR in a location which is visible
# (as a default) to the VM being used.
# - - - - - - - - - - - - - - - - - - - - - - -

readonly MY_NAME=$(basename $0)
readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"
readonly SRC_DIR=${1:-${PWD}}
readonly TMP_DIR=$(mktemp -d ~/tmp-cyber-dojo.image_builder.XXXXXX)
remove_tmp_dir() { rm -rf "${TMP_DIR}" > /dev/null; }

# - - - - - - - - - - - - - - - - - - - - - - -
trap_handler()
{
  remove_tmp_dir
  remove_start_point_image
  remove_runner
  remove_docker_network
}
trap trap_handler EXIT

# - - - - - - - - - - - - - - - - - - - - - - -
show_use_short()
{
  echo "Use: ${MY_NAME} [SRC_DIR|-h|--help]"
  echo ''
  echo '  SRC_DIR defaults to ${PWD}'
  echo '  SRC_DIR/docker/Dockerfile.base must exist'
  echo ''
}

# - - - - - - - - - - - - - - - - - - - - - - -
show_use_long()
{
  show_use_short
  define TEXT <<- EOF
  Creates \${SRC_DIR}/docker/Dockerfile from \${SRC_DIR}/docker/Dockerfile.base
  adjusted to fulfil the runner service's requirements, and then attempts to
  build a docker-image from the Dockerfile. The name of the docker-image is the
  'image_name' property of \${SRC_DIR}/start_point/manifest.json, if it exists,
  otherwise of \${SRC_DIR}/docker/image_name.json.

  If \${SRC_DIR}/start_point/ exists:
  *) Attempts to build a start-point image from the git-cloneable \${SRC_DIR}.
     $ cyber-dojo start-point create ... --languages \${SRC_DIR}
  *) Verifies the red|amber|green traffic-lights for \${SRC_DIR}/start_point/ files
     o) unmodified, give a red traffic-light.
     o) with '6 * 9' replaced by '6 * 9sd', give an amber traffic-light.
     o) with '6 * 9' replaced by '6 * 7', give a green traffic-light.
  *) If there is no \${SRC_DIR}/start_point/ file containing '6 * 9',
     looks for the file \${SRC_DIR}/start_point/options.json. For example, see:
     https://github.com/cyber-dojo-languages/nasm-assert/tree/master/start_point

  If running on the CI/CD pipeine:
  *) Pushes the docker-image to dockerhub
  *) Triggers cyber-dojo-languages github repositories that use
     the created docker-image as their base (FROM) image.

EOF
  printf "${TEXT}"
}

# - - - - - - - - - - - - - - - - - - - - - - -
define()
{
  o=;
  while IFS="\n" read -r a
  do
    o="$o$a"'
';
  done
  eval "$1=\$o"
}

# - - - - - - - - - - - - - - - - - - - - - - -
exit_zero_if_show_help()
{
  if [ "${1}" == '-h' ] || [ "${1}" == '--help' ]; then
    show_use_long
    exit 0
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - -
exit_non_zero_unless_good_SRC_DIR()
{
  if [ ! -d "${SRC_DIR}" ]; then
    show_use_short
    echo "error: ${SRC_DIR} does not exist"
    exit 42
  fi
  if [ ! -f "${SRC_DIR}/docker/Dockerfile.base" ]; then
    show_use_short
    echo "error: ${SRC_DIR}/docker/Dockerfile.base does not exist"
    exit 42
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - -
exit_non_zero_unless_docker_installed()
{
  if [ ! -x docker ]; then
    echo error: docker is not installed
    exit 42
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - -
ip_address()
{
  if [ -n "${DOCKER_MACHINE_NAME}" ]; then
    docker-machine ip ${DOCKER_MACHINE_NAME}
  else
    echo localhost
  fi
}
readonly IP_ADDRESS=$(ip_address)

# - - - - - - - - - - - - - - - - - - - - - - -
cyber_dojo()
{
  local -r name=cyber-dojo
  if [ -x "$(command -v ${name})" ]; then
    >&2 echo "Found executable ${name} on the PATH"
    echo "${name}"
  else
    local -r url="https://raw.githubusercontent.com/cyber-dojo/commander/master/${name}"
    >&2 echo "Did not find executable ${name} on the PATH"
    >&2 echo "Curling it from ${url}"
    curl --fail --output "${TMP_DIR}/${name}" --silent "${url}"
    chmod 700 "${TMP_DIR}/${name}"
    echo "${TMP_DIR}/${name}"
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - -
build_cdl_docker_image()
{
  # Create new Dockerfile containing extra
  # commands to fulfil the runner's requirements.
  echo "Building docker-image $(image_name)"
  cat "$(src_dir_abs)/docker/Dockerfile.base" \
    | \
      docker run \
        --interactive \
        --rm \
        --volume /var/run/docker.sock:/var/run/docker.sock \
        cyberdojofoundation/image_dockerfile_augmenter \
    > \
      "$(src_dir_abs)/docker/Dockerfile"

  # Write new Dockerfile to stdout in case of debugging
  cat "$(src_dir_abs)/docker/Dockerfile"

  # Build the augmented docker-image.
  docker build \
    --file "$(src_dir_abs)/docker/Dockerfile" \
    --tag "$(image_name)" \
    "$(src_dir_abs)/docker"
}

#- - - - - - - - - - - - - - - - - - - - - - -
src_dir_abs()
{
  # docker volume-mounts cannot be relative
  echo $(cd ${SRC_DIR} && pwd)
}

#- - - - - - - - - - - - - - - - - - - - - - -
image_name()
{
  docker run \
    --rm \
    --volume "$(src_dir_abs):/data:ro" \
    cyberdojofoundation/image_namer
}

# - - - - - - - - - - - - - - - - - - - - - - -
on_CI()
{
  [ -n "${CIRCLE_SHA1}" ]
}

# - - - - - - - - - - - - - - - - - - - - - - -
testing_myself()
{
  # Don't push CDL images or notify dependent repos
  # if building CDL images as part of image_builder's own tests.
  [ "${CIRCLE_PROJECT_REPONAME}" = 'image_builder' ]
}

# - - - - - - - - - - - - - - - - - - - - - - -
has_start_point()
{
  [ -d "$(src_dir_abs)/start_point" ]
}

# - - - - - - - - - - - - - - - - - - - - - - -
start_point_image_name()
{
  echo test_start_point_image
}

# - - - - - - - - - - - - - - - - - - - - - - -
create_start_point_image()
{
  echo "Checking $(src_dir_abs)"
  echo 'Looking for uncommitted changes'
  if [[ -z $(cd $(src_dir_abs) && git status -s ) ]]; then
    echo 'Found none'
    echo "Using $(src_dir_abs)"
    local -r url="$(src_dir_abs)"
  else
    echo 'Found some'
    local -r url="${TMP_DIR}/$(basename $(src_dir_abs))"
    echo "So copying it to ${url}"
    cp -r "$(src_dir_abs)" "${TMP_DIR}"
    echo "Committing the changes in ${url}"
    cd ${url}
    git config user.email "cyber-dojo-machine-user@cyber-dojo.org"
    git config user.name "CyberDojoMachineUser"
    git add .
    git commit -m "Save"
    echo "Using ${url}"
  fi
  local -r name=$(start_point_image_name)
  echo "Building ${name}"
  "$(cyber_dojo)" start-point create "${name}" --languages "${url}"
}

# - - - - - - - - - - - - - - - - - - - - - - -
remove_start_point_image()
{
  docker image remove --force $(start_point_image_name) > /dev/null 2>&1 || true
}

# - - - - - - - - - - - - - - - - - - - - - - -
check_red_amber_green()
{
  echo 'Checking red|amber|green traffic-lights'
  create_docker_network
  start_runner
  wait_until_ready runner "${CYBER_DOJO_RUNNER_PORT}"
  assert_traffic_light red
  assert_traffic_light amber
  assert_traffic_light green
}

# - - - - - - - - - - - - - - - - - - - - - - -
# network to host containers
# - - - - - - - - - - - - - - - - - - - - - - -
network_name()
{
  echo traffic-light
}

create_docker_network()
{
  echo "Creating network $(network_name)"
  local -r msg=$(docker network create $(network_name))
}

remove_docker_network()
{
  docker network remove $(network_name) > /dev/null 2>&1 || true
}

# - - - - - - - - - - - - - - - - - - - - - - -
# runner service to pass '6*9' starting files to
# - - - - - - - - - - - - - - - - - - - - - - -
runner_name()
{
  echo traffic-light-runner
}

start_runner()
{
  local -r image="${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
  local -r port="${CYBER_DOJO_RUNNER_PORT}"
  echo "Creating $(runner_name) service"
  local -r cid=$(docker run \
     --detach \
     --env NO_PROMETHEUS \
     --init \
     --name $(runner_name) \
     --network $(network_name) \
     --network-alias runner \
     --publish "${port}:${port}" \
     --read-only \
     --restart no \
     --tmpfs /tmp \
     --user root \
     --volume /var/run/docker.sock:/var/run/docker.sock \
       "${image}")
}

remove_runner()
{
  docker rm --force $(runner_name) > /dev/null 2>&1 || true
}

# - - - - - - - - - - - - - - - - - - - - - - -
readonly READY_FILENAME='/tmp/curl-ready-output'

wait_until_ready()
{
  local -r name="traffic-light-${1}"
  local -r port="${2}"
  local -r max_tries=20
  printf "Waiting until ${name} is ready"
  for _ in $(seq ${max_tries})
  do
    if ready ${port} ; then
      printf '.OK\n'
      return
    else
      printf .
      sleep 0.2
    fi
  done
  printf 'FAIL\n'
  echo "${name} not ready after ${max_tries} tries"
  if [ -f "${READY_FILENAME}" ]; then
    echo "$(cat "${READY_FILENAME}")"
  fi
  docker logs ${name}
  exit 42
}

# - - - - - - - - - - - - - - - - - - - - - - -
ready()
{
  local -r port="${1}"
  local -r path=ready?
  local -r curl_cmd="curl \
    --output ${READY_FILENAME} \
    --silent \
    --fail \
    --data {} \
    -X GET http://${IP_ADDRESS}:${port}/${path}"
  rm -f "${READY_FILENAME}"
  if ${curl_cmd} && [ "$(cat "${READY_FILENAME}")" = '{"ready?":true}' ]; then
    true
  else
    false
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - -
# check red->amber->green progression of '6 * 9'
# Works via a volume-mount and not via a git-clone
# so uncommitted changes in SRC_DIR will be seen.
# - - - - - - - - - - - - - - - - - - - - - - -
assert_traffic_light()
{
  local -r colour="${1}" # eg red
  docker run \
    --env NO_PROMETHEUS \
    --env SRC_DIR=$(src_dir_abs) \
    --init \
    --name traffic-light \
    --network $(network_name) \
    --read-only \
    --restart no \
    --rm \
    --tmpfs /tmp \
    --user nobody \
    --volume $(src_dir_abs):$(src_dir_abs):ro \
      cyberdojofoundation/image_hiker:latest "${colour}"
}

# - - - - - - - - - - - - - - - - - - - - - - -
# notify github projects that use the built image as their base FROM image
# - - - - - - - - - - - - - - - - - - - - - - -
notify_dependent_projects()
{
  echo 'Notifying dependent projects'

  local -r commit_push=github_automated_commit_push.sh
  local -r curled_path="${TMP_DIR}/${commit_push}"
  local -r github_org=https://raw.githubusercontent.com/cyber-dojo
  local -r url="${github_org}/cyber-dojo/master/circle-ci/${script_name}"

  curl \
    --fail \
    --output "${curled_path}" \
    --silent \
    "${url}"
  chmod 700 "${curled_path}"

  local -r from_org=cyber-dojo-languages
  local -r from_repo="${CIRCLE_PROJECT_REPONAME}" # eg java
  local -r from_sha="${CIRCLE_SHA1}" # eg a9334c964f81800a910dc3d301543262161fbbff
  local -r to_org=cyber-dojo-languages

  $(commit_push) \
    "${from_org}" "${from_repo}" "${from_sha}" \
    "${to_org}" $(dependent_projects)

  echo 'Successfully notified dependent projects'
}

# - - - - - - - - - - - - - - - - - - - - - - -
dependent_projects()
{
  docker run \
    --rm \
    --volume "$(src_dir_abs):/data:ro" \
      cyberdojofoundation/image_dependents
}

# - - - - - - - - - - - - - - - - - - - - - - -
check_version()
{
  "${SRC_DIR}/check_version.sh"
}

# - - - - - - - - - - - - - - - - - - - - - - -
push_cdl_image_to_dockerhub()
{
  echo "Pushing $(image_name) to dockerhub"
  # DOCKER_PASSWORD, DOCKER_USERNAME must be in the CI context
  echo "${DOCKER_PASSWORD}" | docker login --username "${DOCKER_USERNAME}" --password-stdin
  docker push $(image_name)
  echo "Successfully pushed $(image_name) to dockerhub"
  docker logout
}

# - - - - - - - - - - - - - - - - - - - - - - -
versioner_env_vars()
{
  docker run --rm cyberdojo/versioner:latest
}

# - - - - - - - - - - - - - - - - - - - - - - -
export $(versioner_env_vars)
exit_zero_if_show_help ${*}
exit_non_zero_unless_good_SRC_DIR ${*}
exit_non_zero_unless_docker_installed
build_cdl_docker_image
if has_start_point; then
  create_start_point_image
  check_red_amber_green
else
  echo 'No ${SRC_DIR}/start_point/ dir so assuming base-language repo'
  check_version
fi
if on_CI && ! testing_myself; then
  push_cdl_image_to_dockerhub
  dependents="$(dependent_projects)"
  #notify_dependent_projects # Not live yet
else
  echo Not pushing image to dockerhub
  echo Not notifying dependent repos
fi