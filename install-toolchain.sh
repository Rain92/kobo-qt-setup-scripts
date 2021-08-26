#!/bin/bash
set -e

./koxtoolchain/gen-tc.sh kobo

chmod -R +rwx /home/${USER}/x-tools
