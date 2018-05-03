#!/bin/bash

pub get || exit $

EXIT_CODE=0
dartfmt -n --set-exit-if-changed . || EXIT_CODE=$?
dartanalyzer . || EXIT_CODE=$?

exit $EXIT_CODE
