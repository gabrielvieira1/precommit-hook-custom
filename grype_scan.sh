#!/bin/bash

echo "🔍 Executando Grype Vulnerability Scanner via Docker..."
mkdir -p logs reports

# Verificar se existe SBOM do Syft para usar
if [ -f "reports/syft-sbom.json" ]; then
    echo "📋 Usando SBOM existente do Syft: reports/syft-sbom.json"
    SCAN_TARGET="sbom:reports/syft-sbom.json"
else
    echo "📦 SBOM não encontrado, escaneando diretório atual"
    SCAN_TARGET="/project"
fi

# Obter nome do projeto da pasta atual
PROJECT_NAME=$(basename $(pwd))

echo "🔎 Executando análise de vulnerabilidades para: $PROJECT_NAME"

# Executar Grype via Docker - gera tanto log quanto relatório JSON
docker run --rm -v "$(pwd):/project" -w /project anchore/grype:latest $SCAN_TARGET -o table > logs/grype.log 2>&1
EXIT_CODE_LOG=$?

# Gerar também relatório em JSON para análise posterior (separando stderr do JSON)
docker run --rm -v "$(pwd):/project" -w /project anchore/grype:latest $SCAN_TARGET -o json 2>logs/grype-json.stderr >reports/grype-vulnerabilities.json
EXIT_CODE_JSON=$?

# Usar o maior exit code (se algum falhar)
EXIT_CODE=$([[ $EXIT_CODE_LOG -gt $EXIT_CODE_JSON ]] && echo $EXIT_CODE_LOG || echo $EXIT_CODE_JSON)

echo "📋 Resultados salvos em:"
echo "   - logs/grype.log (formato legível)"
echo "   - reports/grype-vulnerabilities.json (formato JSON)"

# Analisar vulnerabilidades se o JSON foi gerado com sucesso
if [ $EXIT_CODE_JSON -eq 0 ] && [ -f reports/grype-vulnerabilities.json ]; then
    if command -v jq &> /dev/null; then
        # Contar vulnerabilidades por severidade
        CRITICAL=$(jq '.matches[]? | select(.vulnerability.severity? == "Critical") | .vulnerability.severity' reports/grype-vulnerabilities.json 2>/dev/null | wc -l || echo "0")
        HIGH=$(jq '.matches[]? | select(.vulnerability.severity? == "High") | .vulnerability.severity' reports/grype-vulnerabilities.json 2>/dev/null | wc -l || echo "0")
        MEDIUM=$(jq '.matches[]? | select(.vulnerability.severity? == "Medium") | .vulnerability.severity' reports/grype-vulnerabilities.json 2>/dev/null | wc -l || echo "0")
        LOW=$(jq '.matches[]? | select(.vulnerability.severity? == "Low") | .vulnerability.severity' reports/grype-vulnerabilities.json 2>/dev/null | wc -l || echo "0")

        echo "📊 Vulnerabilidades encontradas pelo Grype:"
        echo "   - CRITICAL: $CRITICAL"
        echo "   - HIGH: $HIGH"
        echo "   - MEDIUM: $MEDIUM"
        echo "   - LOW: $LOW"

        # Falhar se houver vulnerabilidades críticas ou altas
        if [ "$CRITICAL" != "0" ] || [ "$HIGH" != "0" ]; then
            echo "🚨 Vulnerabilidades CRITICAL ($CRITICAL) ou HIGH ($HIGH) detectadas - Hook falhou!"
            EXIT_CODE=1
        else
            echo "✅ Nenhuma vulnerabilidade crítica ou alta encontrada pelo Grype"
        fi
    else
        echo "⚠️ jq não encontrado - não foi possível analisar vulnerabilidades"
        # Não falhar se jq não estiver disponível
    fi
fi

exit $EXIT_CODE
