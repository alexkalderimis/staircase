#!/bin/bash

set -e

BASE_DIR=$(dirname $0)

$BASE_DIR/../node_modules/karma/bin/karma start $BASE_DIR/../config/karma.conf.coffee $*
