#!/bin/bash

if ["$(id -u)" -ne 0]; then
  echo "This script can only be executed by root user." >&2
  exit 1
fi

