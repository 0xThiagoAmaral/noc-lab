#!/bin/bash

# Script para criar nova sala TryHackMe no repositório
# Uso: ./create_writeup.sh "categoria" "nivel" "nome-sala" "nome-display"

CATEGORIA=$1
NIVEL=$2
NOME_SALA=$3
NOME_DISPLAY=$4
BASE_DIR="/home/throot/Documentos/Repositorio/noc-lab/tryhackme-writeups"

if [ $# -ne 4 ]; then
    echo "❌ Uso: $0 <categoria> <nivel> <nome-sala> <nome-display>"
    echo ""
    echo "📋 Categorias disponíveis:"
    echo "  • 01-linux-administration"
    echo "  • 02-backup-security" 
    echo "  • 03-network-protocols"
    echo "  • 04-monitoring-soc"
    echo "  • 05-troubleshooting-blueteam"
    echo "  • 06-windows-activedirectory"
    echo "  • 07-automation-devops"
    echo "  • 08-disaster-recovery"
    echo "  • 09-practical-scenarios"
    echo "  • 10-log-analysis"
    echo ""
    echo "📊 Níveis disponíveis:"
    echo "  • fundamentals"
    echo "  • intermediate"  
    echo "  • advanced"
    echo ""
    echo "💡 Exemplo:"
    echo "  $0 01-linux-administration fundamentals linux-fundamentals-part2 \"Linux Fundamentals Part 2\""
    exit 1
fi

# Validar categoria
if [[ ! "$CATEGORIA" =~ ^(01-linux-administration|02-backup-security|03-network-protocols|04-monitoring-soc|05-troubleshooting-blueteam|06-windows-activedirectory|07-automation-devops|08-disaster-recovery|09-practical-scenarios|10-log-analysis)$ ]]; then
    echo "❌ Categoria inválida: $CATEGORIA"
    exit 1
fi

# Validar nível
if [[ ! "$NIVEL" =~ ^(fundamentals|intermediate|advanced)$ ]]; then
    echo "❌ Nível inválido: $NIVEL"
    exit 1
fi

# Criar diretório
SALA_DIR="$BASE_DIR/$CATEGORIA/$NIVEL/$NOME_SALA"
mkdir -p "$SALA_DIR/screenshots"

echo "📁 Criando estrutura para: $NOME_DISPLAY"
echo "📂 Diretório: $SALA_DIR"

# Criar README da sala
cat > "$SALA_DIR/README.md" << EOF
# $NOME_DISPLAY - TryHackMe Writeup

## 📊 Informações da Sala
- **Nome**: $NOME_DISPLAY
- **URL**: <https://tryhackme.com/room/$NOME_SALA>
- **Dificuldade**: Easy/Medium/Hard
- **Categoria**: [Categoria]
- **Data de Início**: [Data]
- **Data de Conclusão**: [Data]
- **Tempo Gasto**: [X minutos]
- **Badge Obtida**: ✅/❌
- **Pontos**: [X pontos]

## 🎯 Objetivos da Sala
- [ ] [Objetivo 1]
- [ ] [Objetivo 2]
- [ ] [Objetivo 3]

## 📚 Conceitos Abordados
- [Conceito 1]
- [Conceito 2]
- [Conceito 3]

## 🔧 Ferramentas Utilizadas
- [Ferramenta 1]
- [Ferramenta 2]
- [Ferramenta 3]

## 📋 Walkthrough Detalhado

### Task 1: [Nome da Task]
**Questão**: [Pergunta]  
**Comando**: \`[comando]\`  
**Resposta**: \`[resposta]\`  
**Explicação**: [Explicação]

## 💡 Lições Aprendidas

### ✅ Conhecimentos Adquiridos
1. **[Conceito 1]**: [Explicação]
2. **[Conceito 2]**: [Explicação]

## 🔗 Aplicação no Lab NOC

### 🎯 Conexão com o Laboratório
- **Área Relacionada**: \`[diretório-relacionado]/\`
- **Aplicação Prática**: [Como aplicar no lab]

## 📸 Screenshots
- 📁 \`screenshots/\`

## 🔍 Referências
- [Link relevante]

## 📅 Próximos Passos
- [x] Completar $NOME_DISPLAY
- [ ] [Próxima ação]

---

**⭐ Avaliação**: ⭐⭐⭐⭐⭐ ([X]/5)
EOF

echo ""
echo "✅ Estrutura criada com sucesso!"
echo "📄 Arquivo criado: README.md"
echo "📁 Pasta criada: screenshots/"
echo ""
echo "🚀 Bons estudos!"
