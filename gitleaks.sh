#!/bin/bash

echo '🕵️  Executando GitLeaks via Docker...'
mkdir -p logs
docker run --rm -v $(pwd):/path zricethezav/gitleaks:latest detect --source=/path --no-git --verbose > logs/gitleaks.log 2>&1
EXIT_CODE=$?
echo '📋 Resultados salvos em logs/gitleaks.log'
exit $EXIT_CODE
