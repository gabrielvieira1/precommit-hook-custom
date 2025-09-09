#!/bin/bash

echo '🔎 Executando Semgrep SAST via Docker...'
mkdir -p logs
docker run --rm -v $(pwd):/src returntocorp/semgrep semgrep --config=auto --error --json /src > logs/semgrep.log 2>&1
EXIT_CODE=$?
echo '📋 Resultados salvos em logs/semgrep.log'
exit $EXIT_CODE
