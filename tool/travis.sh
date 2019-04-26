#!/bin/bash
# Created with package:mono_repo v2.1.0

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
  pub upgrade --no-precompile || exit $?

  for TASK in "$@"; do
    echo
    echo -e "\033[1mPKG: ${PKG}; TASK: ${TASK}\033[22m"
    case ${TASK} in
    command_0)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 0'
      xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 0 || EXIT_CODE=$?
      ;;
    command_1)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 1'
      xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 1 || EXIT_CODE=$?
      ;;
    command_2)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 2'
      xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 2 || EXIT_CODE=$?
      ;;
    command_3)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 3'
      xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 3 || EXIT_CODE=$?
      ;;
    command_4)
      echo 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 4'
      xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 4 || EXIT_CODE=$?
      ;;
    dartanalyzer_0)
      echo 'dartanalyzer --fatal-infos --fatal-warnings .'
      dartanalyzer --fatal-infos --fatal-warnings . || EXIT_CODE=$?
      ;;
    dartanalyzer_1)
      echo 'dartanalyzer --fatal-warnings .'
      dartanalyzer --fatal-warnings . || EXIT_CODE=$?
      ;;
    dartfmt)
      echo 'dartfmt -n --set-exit-if-changed .'
      dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
      ;;
    test)
      echo 'pub run test --preset travis'
      pub run test --preset travis || EXIT_CODE=$?
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
