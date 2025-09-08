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
    --format HTML \
    --project "vollmed-java-precommit-scan" \
    --out ./reports \
    --noupdate \
    > logs/dependency-check.log 2>&1

EXIT_CODE=$?

# Verificar se há vulnerabilidades críticas ou altas
if [ $EXIT_CODE -eq 0 ] && [ -f reports/dependency-check-report.json ]; then
    if command -v jq &> /dev/null; then
        # Contar vulnerabilidades por severidade
        CRITICAL=$(jq "[.dependencies[]? | select(.vulnerabilities?) | .vulnerabilities[] | select(.severity? == \"CRITICAL\")] | length" reports/dependency-check-report.json 2>/dev/null || echo "0")
        HIGH=$(jq "[.dependencies[]? | select(.vulnerabilities?) | .vulnerabilities[] | select(.severity? == \"HIGH\")] | length" reports/dependency-check-report.json 2>/dev/null || echo "0")
        MEDIUM=$(jq "[.dependencies[]? | select(.vulnerabilities?) | .vulnerabilities[] | select(.severity? == \"MEDIUM\")] | length" reports/dependency-check-report.json 2>/dev/null || echo "0")

        echo "📊 Vulnerabilidades encontradas:"
        echo "   - CRITICAL: $CRITICAL"
        echo "   - HIGH: $HIGH"
        echo "   - MEDIUM: $MEDIUM"

        # Falhar se houver vulnerabilidades críticas ou altas
        if [ "$CRITICAL" != "0" ] || [ "$HIGH" != "0" ]; then
            echo "🚨 Vulnerabilidades CRITICAL ($CRITICAL) ou HIGH ($HIGH) detectadas - Hook falhou!"
            EXIT_CODE=1
        else
            echo "✅ Nenhuma vulnerabilidade crítica ou alta encontrada"
        fi
    else
        echo "⚠️ jq não encontrado - não foi possível analisar vulnerabilidades"
        EXIT_CODE=1
    fi
fi

echo "📋 Log completo: logs/dependency-check.log"
echo "📄 Relatório HTML: reports/dependency-check-report.html"

exit $EXIT_CODE
