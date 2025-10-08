#!/bin/bash

echo "Disk details: " && lsblk -o NAME,MODEL,SIZE,TYPE
echo "ext4 size and utilization: " && df -hT -t ext4
