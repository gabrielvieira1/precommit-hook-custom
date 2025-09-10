#!/bin/bash

echo '🛡️  Executando Snyk Security Scan via Docker...'
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

echo '📋 Resultados salvos em logs/snyk.log'

# Verificar se houve erro de conexão
if grep -q "socket hang up" logs/snyk.log; then
    echo "❌ Erro de conexão detectado. Verifique sua conexão com a internet ou o status do serviço Snyk."
    echo "   Você pode tentar novamente ou verificar o token SNYK_TOKEN no .env"
fi

exit $EXIT_CODE
