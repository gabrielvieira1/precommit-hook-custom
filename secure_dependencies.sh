#!/bin/bash

echo '🛡️  Executando Snyk Security Scan via Docker...'
mkdir -p logs

# Carregar variáveis do .env se existir
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -n "$SNYK_TOKEN" ]; then
    echo "🔑 Usando SNYK_TOKEN para autenticação..."
    docker run --rm --network host -e SNYK_TOKEN="$SNYK_TOKEN" -v $(pwd):/project -w /project snyk/snyk:node snyk test --severity-threshold=high --json > logs/snyk.log 2>&1
    EXIT_CODE=$?
else
    echo '⚠️  SNYK_TOKEN não encontrado. Configure seu token em .env'
    echo 'Executando sem autenticação (funcionalidade limitada)...'
    docker run --rm --network host -v $(pwd):/project -w /project snyk/snyk:node snyk test --severity-threshold=high --json > logs/snyk.log 2>&1
    EXIT_CODE=$?
fi

echo '📋 Resultados salvos em logs/snyk.log'

# Verificar se houve erro de conexão
if grep -q "socket hang up" logs/snyk.log; then
    echo "❌ Erro de conexão detectado. Verifique sua conexão com a internet ou o status do serviço Snyk."
    echo "   Você pode tentar novamente ou verificar o token SNYK_TOKEN no .env"
fi

exit $EXIT_CODE
