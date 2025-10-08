#!/bin/bash

cat /etc/os-release | grep "PRETTY_NAME"
lscpu | grep -E "Model name|CPU\(\s)"
free -h
