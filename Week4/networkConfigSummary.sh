#!/bin/bash

echo "Network Interface Names: " && sudo lshw -class network
echo "Show IP Address: " && ip -4 address show
echo "Show default route " && ip route | grep default
