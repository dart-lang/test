#!/bin/bash
# Created with package:mono_repo v3.0.0

# Support built in commands on windows out of the box.
function pub() {
  if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    command pub.bat "$@"
  else
    command pub "$@"
  fi
}
function dartfmt() {
  if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    command dartfmt.bat "$@"
  else
    command dartfmt "$@"
  fi
}
function dartanalyzer() {
  if [[ $TRAVIS_OS_NAME == "windows" ]]; then
    command dartanalyzer.bat "$@"
  else
    command dartanalyzer "$@"
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

  pub upgrade --no-precompile || EXIT_CODE=$?

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    echo -e "\033[31mPKG: ${PKG}; 'pub upgrade' - FAILED  (${EXIT_CODE})\033[0m"
    FAILURES+=("${PKG}; 'pub upgrade'")
  else
    for TASK in "$@"; do
      EXIT_CODE=0
      echo
      echo -e "\033[1mPKG: ${PKG}; TASK: ${TASK}\033[22m"
      case ${TASK} in
      command_0)
        echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 0'
        xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 0 || EXIT_CODE=$?
        ;;
      command_1)
        echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 1'
        xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 1 || EXIT_CODE=$?
        ;;
      command_2)
        echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 2'
        xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 2 || EXIT_CODE=$?
        ;;
      command_3)
        echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 3'
        xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 3 || EXIT_CODE=$?
        ;;
      command_4)
        echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 4'
        xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs --total-shards 5 --shard-index 4 || EXIT_CODE=$?
        ;;
      command_5)
        echo 'pub run --enable-experiment=non-nullable test --preset travis -x browser'
        pub run --enable-experiment=non-nullable test --preset travis -x browser || EXIT_CODE=$?
        ;;
      dartanalyzer)
        echo 'dartanalyzer --enable-experiment=non-nullable --fatal-infos --fatal-warnings .'
        dartanalyzer --enable-experiment=non-nullable --fatal-infos --fatal-warnings . || EXIT_CODE=$?
        ;;
      dartfmt)
        echo 'dartfmt -n --set-exit-if-changed .'
        dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
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
