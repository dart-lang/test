#!/bin/bash
# Created with package:mono_repo v1.2.1

if [ -z "$PKG" ]; then
  echo -e '\033[31mPKG environment variable must be set!\033[0m'
  exit 1
fi

if [ "$#" == "0" ]; then
  echo -e '\033[31mAt least one task argument must be provided!\033[0m'
  exit 1
fi

pushd $PKG
pub upgrade || exit $?

EXIT_CODE=0

while (( "$#" )); do
  TASK=$1
  case $TASK in
  command_0) echo
    echo -e '\033[1mTASK: command_0\033[22m'
    echo -e 'tool/dartfmt_and_analyze.sh'
    tool/dartfmt_and_analyze.sh || EXIT_CODE=$?
    ;;
  command_1) echo
    echo -e '\033[1mTASK: command_1\033[22m'
    echo -e 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 0'
    xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 0 || EXIT_CODE=$?
    ;;
  command_2) echo
    echo -e '\033[1mTASK: command_2\033[22m'
    echo -e 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 1'
    xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 1 || EXIT_CODE=$?
    ;;
  command_3) echo
    echo -e '\033[1mTASK: command_3\033[22m'
    echo -e 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 2'
    xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 2 || EXIT_CODE=$?
    ;;
  command_4) echo
    echo -e '\033[1mTASK: command_4\033[22m'
    echo -e 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 3'
    xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 3 || EXIT_CODE=$?
    ;;
  command_5) echo
    echo -e '\033[1mTASK: command_5\033[22m'
    echo -e 'xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 4'
    xvfb-run -s "-screen 0 1024x768x24" pub run test --preset travis --total-shards 5 --shard-index 4 || EXIT_CODE=$?
    ;;
  command_6) echo
    echo -e '\033[1mTASK: command_6\033[22m'
    echo -e 'pub run test --preset travis'
    pub run test --preset travis || EXIT_CODE=$?
    ;;
  *) echo -e "\033[31mNot expecting TASK '${TASK}'. Error!\033[0m"
    EXIT_CODE=1
    ;;
  esac

  shift
done

exit $EXIT_CODE
