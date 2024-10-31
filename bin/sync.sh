#!/bin/bash
# To be run from the local machine. $1 is the ssh address of the remote machine
rsync -auP $1:~/${PWD##*/}/data/ data/