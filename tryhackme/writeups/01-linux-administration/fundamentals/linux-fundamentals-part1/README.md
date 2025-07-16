# Linux Fundamentals Part 1 - TryHackMe Writeup

## 📊 Informações da Sala
- **Nome**: Linux Fundamentals Part 1
- **URL**: <https://tryhackme.com/room/linuxfundamentalspart1>
- **Dificuldade**: Info/Easy
- **Categoria**: Linux Administration
- **Data de Início**: [Data]
- **Data de Conclusão**: [Data]
- **Tempo Gasto**: [X minutos]
- **Badge Obtida**: ✅/❌
- **Pontos**: 0 pontos (sala gratuita)

## 🎯 Objetivos da Sala
- [ ] Navegar pelo sistema de arquivos Linux
- [ ] Executar comandos básicos
- [ ] Entender a estrutura de diretórios
- [ ] Gerenciar arquivos e pastas

## 📚 Conceitos Abordados
- Comandos básicos do terminal
- Sistema de arquivos Linux
- Navegação em diretórios
- Listagem e manipulação de arquivos

## 🔧 Comandos Praticados
- `ls` - Listar arquivos e diretórios
- `cd` - Navegar entre diretórios  
- `pwd` - Mostrar diretório atual
- `mkdir` - Criar diretórios
- `touch` - Criar arquivos
- `cat` - Visualizar conteúdo de arquivos

## 📋 Walkthrough Detalhado

### Task 1: Introduction
**Questão**: What year was the first release of a Linux operating system?  
**Resposta**: `1991`  
**Explicação**: Linux foi criado por Linus Torvalds em 1991

### Task 2: A Bit of Background on Linux
**Questão**: What is the size of the file "biscuits"?  
**Comando**: `ls -la biscuits`  
**Resposta**: `13`

### Task 3: Interacting With Your First Linux Machine  
**Questão**: If we wanted to output the file "helloworld", what Linux command would we use?  
**Resposta**: `cat`

### Task 4: Running Your First few Commands
**Questão**: What is the username of who you're logged in as on your deployed Linux machine?  
**Comando**: `whoami`  
**Resposta**: `tryhackme`

### Task 5: Interacting With the Filesystem!
**Questão**: On the Linux machine, how many folders are there?  
**Comando**: `ls`  
**Resposta**: `4`

## 💡 Lições Aprendidas

### ✅ Conhecimentos Adquiridos
1. **Estrutura do Sistema Linux**: Entendi a hierarquia de diretórios
2. **Comandos Básicos**: Dominei navegação e listagem básica
3. **Terminal Linux**: Primeira experiência prática com shell

### 🔧 Comandos Essenciais Memorizados
- `ls -la`: Lista detalhada com arquivos ocultos
- `pwd`: Sempre saber onde estou
- `cd ../`: Voltar um diretório
- `cat arquivo`: Ver conteúdo rapidamente

## 🔗 Aplicação no Lab NOC

### 🎯 Conexão com o Laboratório
- **Área Relacionada**: `02-sistemas-operacionais/`
- **Scripts Criados**: `basic_navigation.sh`
- **Aplicação Prática**: Navegação em servidores Ubuntu/CentOS

### 📝 Scripts Derivados
```bash
#!/bin/bash
# Script básico de navegação - inspirado na sala
echo "=== Sistema de Arquivos ==="
pwd
echo "=== Arquivos no diretório atual ==="
ls -la
echo "=== Usuário atual ==="
whoami
```

## 📸 Screenshots
- 📁 `screenshots/` (criar pasta e adicionar prints)
  - `task1_introduction.png`
  - `task4_whoami.png`
  - `task5_filesystem.png`

## 🔍 Referências
- [Manual do comando ls](https://man7.org/linux/man-pages/man1/ls.1.html)
- [Hierarquia do sistema de arquivos](https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)

## 📅 Próximos Passos
- [x] Completar Linux Fundamentals Part 1
- [ ] Avançar para Part 2
- [ ] Aplicar comandos no lab Ubuntu
- [ ] Criar scripts de automação básicos

---

**📝 Notas**: Excelente introdução ao Linux. Base fundamental para administração de servidores no lab.

**⭐ Avaliação**: ⭐⭐⭐⭐⭐ (5/5) - Perfeita para iniciantes
