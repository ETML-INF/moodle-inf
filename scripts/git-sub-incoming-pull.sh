#!/bin/bash
git submodule foreach --recursive 'git pull && git submodule update || :'