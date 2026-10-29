#!/usr/bin/env bash

# initialize the submodules, monero-lws builds against monero-project so its own monero is left out
git submodule update --init external/monero-lws
git submodule update --init --recursive external/monero-project
