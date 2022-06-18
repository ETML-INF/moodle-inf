#!/bin/bash
REPO="https://github.com/ETML-INF/moodle-inf.git"

if [ ! -d .git ]; then
  git init .
  git remote add origin ${REPO}
  git fetch
  git checkout main
fi