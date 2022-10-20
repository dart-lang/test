#!/bin/bash
# Created with package:mono_repo v6.4.0

# Support built in commands on windows out of the box.
# When it is a flutter repo (check the pubspec.yaml for "sdk: flutter")
# then "flutter" is called instead of "pub".
# This assumes that the Flutter SDK has been installed in a previous step.
function pub() {
  if grep -Fq "sdk: flutter" "${PWD}/pubspec.yaml"; then
    command flutter pub "$@"
  else
    command dart pub "$@"
  fi
}
# When it is a flutter repo (check the pubspec.yaml for "sdk: flutter")
# then "flutter" is called instead of "pub".
# This assumes that the Flutter SDK has been installed in a previous step.
function format() {
  if grep -Fq "sdk: flutter" "${PWD}/pubspec.yaml"; then
    command flutter format "$@"
  else
    command dart format "$@"
  fi
}
# When it is a flutter repo (check the pubspec.yaml for "sdk: flutter")
# then "flutter" is called instead of "pub".
# This assumes that the Flutter SDK has been installed in a previous step.
function analyze() {
  if grep -Fq "sdk: flutter" "${PWD}/pubspec.yaml"; then
    command flutter analyze "$@"
  else
    command dart analyze "$@"
  fi
}

if [[ -z ${PKGS} ]]; then
  echo -e '\033[31mPKGS environment variable must be set! - TERMINATING JOB\033[0m'
  exit 64
fi

if [[ "$#" == "0" ]]; then
  echo -e '\033[31mAt least one task argument must be provided! - TERMINATING JOB\033[0m'
  exit 64
fi

SUCCESS_COUNT=0
declare -a FAILURES

for PKG in ${PKGS}; do
  echo -e "\033[1mPKG: ${PKG}\033[22m"
  EXIT_CODE=0
  pushd "${PKG}" >/dev/null || EXIT_CODE=$?

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo -e "\033[31mPKG: '${PKG}' does not exist - TERMINATING JOB\033[0m"
    exit 64
  fi

  dart pub upgrade || EXIT_CODE=$?

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo -e "\033[31mPKG: ${PKG}; 'dart pub upgrade' - FAILED  (${EXIT_CODE})\033[0m"
    FAILURES+=("${PKG}; 'dart pub upgrade'")
  else
    for TASK in "$@"; do
      EXIT_CODE=0
      echo
      echo -e "\033[1mPKG: ${PKG}; TASK: ${TASK}\033[22m"
      case ${TASK} in
      analyze_0)
        echo 'dart analyze --fatal-infos'
        dart analyze --fatal-infos || EXIT_CODE=$?
        ;;
      analyze_1)
        echo 'dart analyze'
        dart analyze || EXIT_CODE=$?
        ;;
      command_00)
        echo 'pushd /tmp && wget https://dl.google.com/linux/direct/google-chrome-beta_current_amd64.deb && sudo dpkg -i google-chrome-beta_current_amd64.deb && popd && which google-chrome-beta'
        pushd /tmp && wget https://dl.google.com/linux/direct/google-chrome-beta_current_amd64.deb && sudo dpkg -i google-chrome-beta_current_amd64.deb && popd && which google-chrome-beta || EXIT_CODE=$?
        ;;
      command_01)
        echo 'dart test'
        dart test || EXIT_CODE=$?
        ;;
      command_02)
        echo 'xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 0'
        xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 0 || EXIT_CODE=$?
        ;;
      command_03)
        echo 'xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 1'
        xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 1 || EXIT_CODE=$?
        ;;
      command_04)
        echo 'xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 2'
        xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 2 || EXIT_CODE=$?
        ;;
      command_05)
        echo 'xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 3'
        xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 3 || EXIT_CODE=$?
        ;;
      command_06)
        echo 'xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 4'
        xvfb-run -s "-screen 0 1024x768x24" dart test --preset travis --total-shards 5 --shard-index 4 || EXIT_CODE=$?
        ;;
      command_07)
        echo 'dart test --preset travis --total-shards 5 --shard-index 0'
        dart test --preset travis --total-shards 5 --shard-index 0 || EXIT_CODE=$?
        ;;
      command_08)
        echo 'dart test --preset travis --total-shards 5 --shard-index 1'
        dart test --preset travis --total-shards 5 --shard-index 1 || EXIT_CODE=$?
        ;;
      command_09)
        echo 'dart test --preset travis --total-shards 5 --shard-index 2'
        dart test --preset travis --total-shards 5 --shard-index 2 || EXIT_CODE=$?
        ;;
      command_10)
        echo 'dart test --preset travis --total-shards 5 --shard-index 3'
        dart test --preset travis --total-shards 5 --shard-index 3 || EXIT_CODE=$?
        ;;
      command_11)
        echo 'dart test --preset travis --total-shards 5 --shard-index 4'
        dart test --preset travis --total-shards 5 --shard-index 4 || EXIT_CODE=$?
        ;;
      command_12)
        echo 'dart test --preset travis -x browser'
        dart test --preset travis -x browser || EXIT_CODE=$?
        ;;
      format)
        echo 'dart format --output=none --set-exit-if-changed .'
        dart format --output=none --set-exit-if-changed . || EXIT_CODE=$?
        ;;
      test_0)
        echo 'dart test -p chrome,vm,node'
        dart test -p chrome,vm,node || EXIT_CODE=$?
        ;;
      *)
        echo -e "\033[31mUnknown TASK '${TASK}' - TERMINATING JOB\033[0m"
        exit 64
        ;;
      esac

      if [[ ${EXIT_CODE} -ne 0 ]]; then
        echo -e "\033[31mPKG: ${PKG}; TASK: ${TASK} - FAILED (${EXIT_CODE})\033[0m"
        FAILURES+=("${PKG}; TASK: ${TASK}")
      else
        echo -e "\033[32mPKG: ${PKG}; TASK: ${TASK} - SUCCEEDED\033[0m"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      fi

    done
  fi

  echo
  echo -e "\033[32mSUCCESS COUNT: ${SUCCESS_COUNT}\033[0m"

  if [ ${#FAILURES[@]} -ne 0 ]; then
    echo -e "\033[31mFAILURES: ${#FAILURES[@]}\033[0m"
    for i in "${FAILURES[@]}"; do
      echo -e "\033[31m  $i\033[0m"
    done
  fi

  popd >/dev/null || exit 70
  echo
done

if [ ${#FAILURES[@]} -ne 0 ]; then
  exit 1
fi
