#!/bin/bash

echo '🛡️  Executando Snyk Security Scan...'
mkdir -p logs

# Função para detectar o tipo de projeto
detect_project_type() {
    if [ -f "pom.xml" ]; then
        echo "java-maven"
    elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
        echo "java-gradle"
    elif [ -f "package.json" ]; then
        echo "node"
    elif [ -f "requirements.txt" ] || [ -f "Pipfile" ] || [ -f "pyproject.toml" ]; then
        echo "python"
    elif [ -f "go.mod" ]; then
        echo "go"
    elif [ -f "Cargo.toml" ]; then
        echo "rust"
    else
        echo "unknown"
    fi
}

# Detectar tipo do projeto
PROJECT_TYPE=$(detect_project_type)
echo "🔍 Tipo de projeto detectado: $PROJECT_TYPE"

# Configurar comando Snyk baseado no tipo do projeto
case $PROJECT_TYPE in
    "java-maven")
        SNYK_IMAGE="snyk/snyk:java"
        SNYK_COMMAND="snyk test --package-manager=maven --severity-threshold=high --json"
        echo "☕ Configurando para projeto Java (Maven)"
        ;;
    "java-gradle")
        SNYK_IMAGE="snyk/snyk:java"
        SNYK_COMMAND="snyk test --package-manager=gradle --severity-threshold=high --json"
        echo "☕ Configurando para projeto Java (Gradle)"
        ;;
    "node")
        SNYK_IMAGE="snyk/snyk:node"
        SNYK_COMMAND="snyk test --severity-threshold=high --json"
        echo "🟢 Configurando para projeto Node.js"
        ;;
    "python")
        SNYK_IMAGE="snyk/snyk:python"
        SNYK_COMMAND="snyk test --severity-threshold=high --json"
        echo "🐍 Configurando para projeto Python"
        ;;
    "go")
        SNYK_IMAGE="snyk/snyk:golang"
        SNYK_COMMAND="snyk test --severity-threshold=high --json"
        echo "🐹 Configurando para projeto Go"
        ;;
    "rust")
        SNYK_IMAGE="snyk/snyk:rust"
        SNYK_COMMAND="snyk test --severity-threshold=high --json"
        echo "🦀 Configurando para projeto Rust"
        ;;
    *)
        SNYK_IMAGE="snyk/snyk:node"
        SNYK_COMMAND="snyk test --severity-threshold=high --json"
        echo "❓ Tipo de projeto não identificado, usando configuração padrão (Node.js)"
        ;;
esac

# Carregar variáveis do .env se existir
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Verificar se Snyk está instalado localmente
if command -v snyk &> /dev/null; then
    echo "✅ Usando Snyk local (mais rápido e confiável)"
    if [ -n "$SNYK_TOKEN" ]; then
        echo "🔑 Token SNYK_TOKEN configurado"
    fi
    
    # Configurar comando Snyk baseado no tipo do projeto
    case $PROJECT_TYPE in
        java-maven|java-gradle)
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        node)
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        python)
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        go)
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        rust)
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        *)
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
    esac
    
    # Executar Snyk localmente
    $SNYK_COMMAND > logs/snyk.log 2>&1
    EXIT_CODE=$?
    
else
    echo "⚠️  Snyk não encontrado localmente, tentando Docker..."
    
    # Configurar imagem e comando Docker baseado no tipo do projeto
    case $PROJECT_TYPE in
        java-maven|java-gradle)
            SNYK_IMAGE="snyk/snyk:maven"
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        node)
            SNYK_IMAGE="snyk/snyk:node"
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        python)
            SNYK_IMAGE="snyk/snyk:python"
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        go)
            SNYK_IMAGE="snyk/snyk:golang"
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        rust)
            SNYK_IMAGE="snyk/snyk:docker"
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
        *)
            SNYK_IMAGE="snyk/snyk:node"
            SNYK_COMMAND="snyk test --severity-threshold=high --json"
            ;;
    esac
    
    if [ -n "$SNYK_TOKEN" ]; then
        echo "🔑 Usando SNYK_TOKEN para autenticação..."
        docker run --rm --network host -e SNYK_TOKEN="$SNYK_TOKEN" -v $(pwd):/project -w /project $SNYK_IMAGE $SNYK_COMMAND > logs/snyk.log 2>&1
        EXIT_CODE=$?
    else
        echo '⚠️  SNYK_TOKEN não encontrado. Configure seu token em .env'
        echo 'Executando sem autenticação (funcionalidade limitada)...'
        docker run --rm --network host -v $(pwd):/project -w /project $SNYK_IMAGE $SNYK_COMMAND > logs/snyk.log 2>&1
        EXIT_CODE=$?
    fi
fi

echo '📋 Resultados salvos em logs/snyk.log'

# Analisar resultados do Snyk
if grep -q "socket hang up" logs/snyk.log; then
    echo "❌ Erro de conexão detectado. Verifique sua conexão com a internet ou o status do serviço Snyk."
    echo "   Você pode tentar novamente ou verificar o token SNYK_TOKEN no .env"
elif [ -f logs/snyk.log ] && [ -s logs/snyk.log ]; then
    # Verificar se é JSON válido
    if grep -q '"vulnerabilities"' logs/snyk.log; then
        # Contar vulnerabilidades por severidade usando arquivos temporários
        grep '"severity": "critical"' logs/snyk.log | wc -l > /tmp/critical_count
        grep '"severity": "high"' logs/snyk.log | wc -l > /tmp/high_count
        grep '"severity": "medium"' logs/snyk.log | wc -l > /tmp/medium_count
        grep '"severity": "low"' logs/snyk.log | wc -l > /tmp/low_count
        
        CRITICAL=$(cat /tmp/critical_count 2>/dev/null || echo "0")
        HIGH=$(cat /tmp/high_count 2>/dev/null || echo "0")
        MEDIUM=$(cat /tmp/medium_count 2>/dev/null || echo "0")
        LOW=$(cat /tmp/low_count 2>/dev/null || echo "0")
        
        # Limpar arquivos temporários
        rm -f /tmp/critical_count /tmp/high_count /tmp/medium_count /tmp/low_count
        
        TOTAL=$((CRITICAL + HIGH + MEDIUM + LOW))
        
        if [ "$TOTAL" -gt 0 ]; then
            echo "🚨 Encontradas $TOTAL vulnerabilidades de dependências:"
            [ "$CRITICAL" -gt 0 ] && echo "   🔴 Críticas: $CRITICAL"
            [ "$HIGH" -gt 0 ] && echo "   🟠 Altas: $HIGH"
            [ "$MEDIUM" -gt 0 ] && echo "   🟡 Médias: $MEDIUM"
            [ "$LOW" -gt 0 ] && echo "   🔵 Baixas: $LOW"
            
            # Mostrar dependências afetadas
            echo ""
            echo "📦 Dependências afetadas:"
            grep '"moduleName"' logs/snyk.log | sed 's/.*"moduleName": "\([^"]*\)".*/   - \1/' | sort -u | head -5
        else
            echo "✅ Nenhuma vulnerabilidade encontrada nas dependências"
        fi
    elif grep -q '"ok": true' logs/snyk.log; then
        echo "✅ Nenhuma vulnerabilidade encontrada nas dependências"
    else
        echo "⚠️  Resultado inesperado - verifique logs/snyk.log"
    fi
else
    echo "❌ Nenhum resultado gerado - verifique a configuração"
fi

exit $EXIT_CODE
