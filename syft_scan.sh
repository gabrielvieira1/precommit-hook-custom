#!/bin/bash

echo "🔍 Executando Syft SBOM Scan..."
mkdir -p logs reports

# Verificar se Syft está instalado localmente
if command -v syft &> /dev/null; then
    echo "✅ Usando Syft local (mais rápido e confiável)"
    
    # Obter nome do projeto da pasta atual
    PROJECT_NAME=$(basename $(pwd))
    
    echo "📦 Gerando SBOM (Software Bill of Materials) para o projeto: $PROJECT_NAME"
    
    # Executar Syft localmente - gera tanto log quanto relatório JSON
    syft . -o table > logs/syft.log 2>&1
    EXIT_CODE_LOG=$?
    
    # Gerar também relatório em JSON para análise posterior
    syft . -o json > reports/syft-sbom.json 2>logs/syft-json.stderr
    EXIT_CODE_JSON=$?
    
    # Usar o maior exit code (se algum falhar)
    EXIT_CODE=$([[ $EXIT_CODE_LOG -gt $EXIT_CODE_JSON ]] && echo $EXIT_CODE_LOG || echo $EXIT_CODE_JSON)
    
else
    echo "⚠️  Syft não encontrado localmente, tentando Docker..."
    
    # Executar Syft via Docker - gera tanto log quanto relatório JSON
    docker run --rm -v "$(pwd):/project" -w /project anchore/syft:latest /project -o table > logs/syft.log 2>&1
    EXIT_CODE_LOG=$?
    
    # Gerar também relatório em JSON para análise posterior (separando stderr do JSON)
    docker run --rm -v "$(pwd):/project" -w /project anchore/syft:latest /project -o json 2>logs/syft-json.stderr >reports/syft-sbom.json
    EXIT_CODE_JSON=$?
    
    # Usar o maior exit code (se algum falhar)
    EXIT_CODE=$([[ $EXIT_CODE_LOG -gt $EXIT_CODE_JSON ]] && echo $EXIT_CODE_LOG || echo $EXIT_CODE_JSON)
fi

echo "📋 Resultados salvos em:"
echo "   - logs/syft.log (formato legível)"
echo "   - reports/syft-sbom.json (formato JSON)"

# Mostrar resumo se o JSON foi gerado com sucesso
if [ $EXIT_CODE_JSON -eq 0 ] && [ -f reports/syft-sbom.json ]; then
    if command -v jq &> /dev/null; then
        TOTAL_PACKAGES=$(jq '.artifacts | length' reports/syft-sbom.json 2>/dev/null || echo "0")
        echo "📊 Total de pacotes/dependências encontrados: $TOTAL_PACKAGES"
    fi
fi

exit $EXIT_CODE
