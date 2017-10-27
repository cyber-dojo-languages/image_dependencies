#!/bin/bash

echo 'dirs with /docker/ only ==> languages'
echo 'success cases...'

test_alpine()
{
  build_image /test/languages/alpine-gcc
  assertStdoutIncludes '# build_the_image'
  refuteStdoutIncludes '# check_start_point_can_be_created'
  assertStdoutIncludes "adduser -D -G cyber-dojo -h /home/flamingo -s '/bin/sh' -u 40014 flamingo"
  assertStdoutIncludes '# print_image_info'
  assertStdoutIncludes 'Welcome to Alpine Linux 3.6'
  refuteStdoutIncludes '# check_start_point_src_red_green_amber_using_runner_stateful'
  refuteStdoutIncludes 'red: OK'
  refuteStdoutIncludes 'green: OK'
  refuteStdoutIncludes 'amber: OK'
  assertNoStderr
}

test_ubuntu()
{
  build_image /test/languages/ubuntu-python
  assertStdoutIncludes '# build_the_image'
  refuteStdoutIncludes '# check_start_point_can_be_created'
  assertStdoutIncludes "adduser --disabled-password --gecos \"\" --ingroup cyber-dojo --home /home/flamingo --uid 40014 flamingo"
  assertStdoutIncludes '# print_image_info'
  assertStdoutIncludes 'Ubuntu 17.04'
  refuteStdoutIncludes '# check_start_point_src_red_green_amber_using_runner_stateless'
  refuteStdoutIncludes 'red: OK'
  refuteStdoutIncludes 'green: OK'
  refuteStdoutIncludes 'amber: OK'
  assertNoStderr
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"

. ${MY_DIR}/test_helpers.sh
. ${MY_DIR}/shunit2_helpers.sh
. ${MY_DIR}/shunit2
