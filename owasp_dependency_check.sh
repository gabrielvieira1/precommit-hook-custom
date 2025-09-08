#!/bin/bash

# Caminho para instalação local
DC_PATH="/home/gabriel/dependency-check/bin/dependency-check.sh"

# Verificar se a instalação local existe
if [ ! -f "$DC_PATH" ]; then
    echo "❌ Dependency-Check não encontrado em: $DC_PATH"
    exit 1
fi

# Criar diretórios necessários
mkdir -p reports logs

# Executar dependency-check local com base já baixada
$DC_PATH \
    --scan . \
    --format JSON \
    --project "vollmed-java-precommit-scan" \
    --out ./reports \
    --noupdate \
    > logs/dependency-check.log 2>&1

EXIT_CODE=$?

# Verificar se há vulnerabilidades críticas ou altas
if [ $EXIT_CODE -eq 0 ] && [ -f reports/dependency-check-report.json ]; then
    if command -v jq &> /dev/null; then
        CRITICAL=$(jq "[.dependencies[]? | select(.vulnerabilities?) | .vulnerabilities[] | select(.severity? == \"CRITICAL\")] | length" reports/dependency-check-report.json 2>/dev/null || echo "0")
        HIGH=$(jq "[.dependencies[]? | select(.vulnerabilities?) | .vulnerabilities[] | select(.severity? == \"HIGH\")] | length" reports/dependency-check-report.json 2>/dev/null || echo "0")

        if [ "$CRITICAL" != "0" ] || [ "$HIGH" != "0" ]; then
            echo "🚨 Vulnerabilidades CRITICAL ($CRITICAL) ou HIGH ($HIGH) detectadas"
            EXIT_CODE=1
        fi
    fi
fi

echo "📋 Log completo: logs/dependency-check.log"

exit $EXIT_CODE
