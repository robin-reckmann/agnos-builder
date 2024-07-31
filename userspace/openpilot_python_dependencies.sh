#!/bin/bash -e

echo "Installing python for openpilot"

echo "installing uv..."
export XDG_DATA_HOME="/usr/local"
export CARGO_HOME="$XDG_DATA_HOME/.cargo"

curl -LsSf https://astral.sh/uv/install.sh | sh
eval ". $CARGO_HOME/env"

# uv requires virtual env either managed or system before installing dependencies
uv venv $XDG_DATA_HOME/venv --python-preference only-managed --python=3.11.4
