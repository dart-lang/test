#!/bin/bash

# Fast fail the script on failures.   
set -e

pub run unittest:unittest
