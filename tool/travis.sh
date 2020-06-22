#!/bin/bash
# Created with package:mono_repo v2.3.0

# Support built in commands on windows out of the box.
function pub {
       if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command pub.bat "$@"
    else
        command pub "$@"
    fi
}
function dartfmt {
       if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command dartfmt.bat "$@"
    else
        command dartfmt "$@"
    fi
}
function dartanalyzer {
       if [[ $TRAVIS_OS_NAME == "windows" ]]; then
        command dartanalyzer.bat "$@"
    else
        command dartanalyzer "$@"
    fi
}

if [[ -z ${PKGS} ]]; then
  echo -e '\033[31mPKGS environment variable must be set!\033[0m'
  exit 1
fi

if [[ "$#" == "0" ]]; then
  echo -e '\033[31mAt least one task argument must be provided!\033[0m'
  exit 1
fi

EXIT_CODE=0

for PKG in ${PKGS}; do
  echo -e "\033[1mPKG: ${PKG}\033[22m"
  pushd "${PKG}" || exit $?

  PUB_EXIT_CODE=0
  pub upgrade --no-precompile || PUB_EXIT_CODE=$?

  if [[ ${PUB_EXIT_CODE} -ne 0 ]]; then
    EXIT_CODE=1
    echo -e '\033[31mpub upgrade failed\033[0m'
    popd
    continue
  fi

  for TASK in "$@"; do
    echo
    echo -e "\033[1mPKG: ${PKG}; TASK: ${TASK}\033[22m"
    case ${TASK} in
    command_0)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 0'
      xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 0 || EXIT_CODE=$?
      ;;
    command_1)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 1'
      xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 1 || EXIT_CODE=$?
      ;;
    command_2)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 2'
      xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 2 || EXIT_CODE=$?
      ;;
    command_3)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 3'
      xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 3 || EXIT_CODE=$?
      ;;
    command_4)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 4'
      xvfb-run -s "-screen 0 1024x768x24" pub run --enable-experiment=non-nullable test --preset travis -x phantomjs -x node --total-shards 5 --shard-index 4 || EXIT_CODE=$?
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
      echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
      EXIT_CODE=1
      ;;
    esac
  done

  popd
done

exit ${EXIT_CODE}
