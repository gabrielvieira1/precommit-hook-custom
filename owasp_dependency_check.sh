#!/bin/bash

# Função para encontrar o executável do Dependency-Check
find_dependency_check() {
    local paths=(
        "/usr/local/bin/dependency-check"
        "/usr/bin/dependency-check"
        "/opt/dependency-check/bin/dependency-check.sh"
        "$HOME/dependency-check/bin/dependency-check.sh"
    )

    # Primeiro tentar encontrar via which
    if command -v dependency-check &> /dev/null; then
        echo "dependency-check"
        return 0
    fi

    # Procurar nos caminhos comuns
    for path in "${paths[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Encontrar o executável do Dependency-Check
DC_PATH=$(find_dependency_check)

# Verificar se encontrou o executável
if [ -z "$DC_PATH" ]; then
    echo "❌ OWASP Dependency-Check não encontrado!"
    echo "   Verifique se está instalado em um dos seguintes locais:"
    echo "   - /usr/local/bin/dependency-check"
    echo "   - /usr/bin/dependency-check"
    echo "   - /opt/dependency-check/bin/dependency-check.sh"
    echo "   - ~/dependency-check/bin/dependency-check.sh"
    echo "   - /home/\$USER/dependency-check/bin/dependency-check.sh"
    echo "   Ou certifique-se de que está no PATH do sistema"
    exit 1
fi

echo "✅ Dependency-Check encontrado em: $DC_PATH"

# Criar diretórios necessários
mkdir -p reports logs

# Obter nome do projeto da pasta atual
PROJECT_NAME=$(basename $(pwd))

# Executar dependency-check local com base já baixada
# Primeiro gerar JSON na pasta logs
$DC_PATH \
    --scan . \
    --format JSON \
    --project "$PROJECT_NAME" \
    --out ./logs \
    --noupdate \
    > logs/dependency-check.log 2>&1

# Depois gerar HTML na pasta reports
$DC_PATH \
    --scan . \
    --format HTML \
    --project "$PROJECT_NAME" \
    --out ./reports \
    --noupdate \
    >> logs/dependency-check.log 2>&1

EXIT_CODE=$?

# Verificar se há vulnerabilidades críticas ou altas
if [ $EXIT_CODE -eq 0 ] && [ -f logs/dependency-check-report.json ]; then
    if command -v jq &> /dev/null; then
        # Contar vulnerabilidades por severidade
        CRITICAL=$(jq "[.dependencies[]? | select(.vulnerabilities?) | .vulnerabilities[] | select(.severity? == \"CRITICAL\")] | length" logs/dependency-check-report.json 2>/dev/null || echo "0")
        HIGH=$(jq "[.dependencies[]? | select(.vulnerabilities?) | .vulnerabilities[] | select(.severity? == \"HIGH\")] | length" logs/dependency-check-report.json 2>/dev/null || echo "0")
        MEDIUM=$(jq "[.dependencies[]? | select(.vulnerabilities?) | .vulnerabilities[] | select(.severity? == \"MEDIUM\")] | length" logs/dependency-check-report.json 2>/dev/null || echo "0")

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
echo "📄 Relatório JSON: logs/dependency-check-report.json"
echo "📄 Relatório HTML: reports/dependency-check-report.html"

exit $EXIT_CODE
