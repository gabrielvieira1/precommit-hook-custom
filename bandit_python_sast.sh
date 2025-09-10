#!/bin/bash

echo '🐍 Executando Bandit Python SAST...'
mkdir -p logs

if find . -name '*.py' -not -path './.git/*' -not -path './logs/*' | head -1 | grep -q .; then
    docker run --rm -v $(pwd):/src --workdir /src python:3.11-slim bash -c 'pip install bandit > /dev/null 2>&1 && bandit -r . -f json' > logs/bandit.log 2>&1
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -ne 0 ]; then
        echo '❌ Vulnerabilidades Python encontradas!'
    fi
    
    echo '📋 Resultados salvos em logs/bandit.log'
    exit $EXIT_CODE
else
    echo 'ℹ️  Nenhum arquivo Python encontrado, pulando Bandit...'
    exit 0
fi
