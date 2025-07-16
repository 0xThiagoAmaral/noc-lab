# Guia de Setup Rápido - NOC Lab

## Pré-requisitos

### Hardware Mínimo
- **CPU**: 4+ cores
- **RAM**: 16GB (recomendado 32GB)
- **Storage**: 500GB SSD
- **Rede**: Ethernet Gigabit

### Software Base
- **Host OS**: Ubuntu 22.04 LTS ou superior
- **Hypervisor**: VirtualBox, VMware, ou KVM
- **Git**: Para clone do repositório

## Setup Rápido (30 minutos)

### 1. Preparar Ambiente

```bash
# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências básicas
sudo apt install -y git curl wget vim tree htop

# Clonar repositório
git clone https://github.com/seu-usuario/noc-lab.git
cd noc-lab
```

### 2. Executar Script de Setup Automático

```bash
# Tornar script executável
chmod +x scripts/quick-setup.sh

# Executar setup
sudo ./scripts/quick-setup.sh
```

### 3. Configurar Credenciais

```bash
# Editar arquivo de configuração
cp config/lab.conf.example config/lab.conf
vim config/lab.conf

# Definir senhas e IPs
SERVER_IP="192.168.100.10"
MYSQL_ROOT_PASSWORD="RootPass123"
BACULA_PASSWORD="BaculaPass123"
ZABBIX_PASSWORD="ZabbixPass123"
```

### 4. Validar Instalação

```bash
# Executar testes
./scripts/validate-setup.sh

# Verificar serviços
systemctl status bacula-director zabbix-server mysql
```

## Estrutura do Projeto

```
noc-lab/
├── README.md                 # Documentação principal
├── LICENSE                   # Licença do projeto
├── .gitignore               # Arquivos ignorados pelo Git
├── config/                  # Arquivos de configuração
│   ├── lab.conf.example     # Template de configuração
│   ├── bacula/              # Configurações Bacula
│   ├── zabbix/              # Configurações Zabbix
│   └── network/             # Configurações de rede
├── scripts/                 # Scripts de automação
│   ├── quick-setup.sh       # Setup rápido
│   ├── validate-setup.sh    # Validação
│   ├── backup/              # Scripts de backup
│   ├── monitoring/          # Scripts de monitoramento
│   └── troubleshooting/     # Scripts de diagnóstico
├── docs/                    # Documentação detalhada
│   ├── installation.md     # Guia de instalação
│   ├── configuration.md    # Guia de configuração
│   ├── troubleshooting.md  # Guia de solução de problemas
│   └── api-reference.md    # Referência da API
├── tests/                   # Testes automatizados
│   ├── unit/               # Testes unitários
│   ├── integration/        # Testes de integração
│   └── performance/        # Testes de performance
├── examples/               # Exemplos práticos
│   ├── scenarios/          # Cenários de uso
│   ├── configurations/     # Configurações de exemplo
│   └── reports/           # Relatórios de exemplo
└── tools/                 # Ferramentas auxiliares
    ├── generators/        # Geradores de configuração
    ├── analyzers/         # Analisadores de logs
    └── simulators/        # Simuladores de falha
```

## Configurações Importantes

### Endereçamento IP
- **Servidor Principal**: 192.168.100.10
- **Cliente Linux 1**: 192.168.100.20
- **Cliente Linux 2**: 192.168.100.21
- **Cliente Windows**: 192.168.100.30
- **Storage Server**: 192.168.100.40

### Portas de Serviço
- **SSH**: 22
- **HTTP**: 80
- **HTTPS**: 443
- **Bacula Director**: 9101
- **Bacula File Daemon**: 9102
- **Bacula Storage Daemon**: 9103
- **Zabbix Server**: 10051
- **Zabbix Agent**: 10050
- **MySQL**: 3306

### Credenciais Padrão
- **OS Admin**: root / AdminPass123
- **MySQL Root**: root / RootPass123
- **Bacula**: bacula / BaculaPass123
- **Zabbix Admin**: Admin / ZabbixPass123

## Comandos Úteis

### Gerenciar Serviços
```bash
# Status de todos os serviços
systemctl status bacula-director bacula-sd bacula-fd zabbix-server mysql

# Reiniciar serviços
sudo systemctl restart bacula-director zabbix-server

# Logs dos serviços
journalctl -u bacula-director -f
```

### Backup Operations
```bash
# Console do Bacula
bconsole

# Executar backup manual
echo "run job=backup-client-linux level=incremental yes" | bconsole

# Listar jobs recentes
echo "list jobs last=10" | bconsole

# Status do director
echo "status director" | bconsole
```

### Monitoramento
```bash
# Verificar alertas Zabbix
curl -s "http://localhost/zabbix/api_jsonrpc.php" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"trigger.get","params":{"output":"extend","filter":{"status":"0"}},"id":1}'

# Monitor de sistema
htop
iotop
nethogs
```

### Troubleshooting
```bash
# Verificar conectividade
ping 192.168.100.20

# Testar portas
telnet 192.168.100.20 9102

# Verificar logs de erro
grep -i error /var/log/bacula/bacula.log
grep -i error /var/log/zabbix/zabbix_server.log
```

## Cenários de Teste

### 1. Teste de Backup
```bash
# Criar arquivo de teste
echo "Test file $(date)" > /tmp/test-backup.txt

# Executar backup
echo "run job=backup-client-linux level=incremental yes" | bconsole

# Verificar sucesso
echo "list jobs last=1" | bconsole
```

### 2. Teste de Restore
```bash
# Executar restore
echo "restore client=client-linux-fd select" | bconsole

# Seguir wizard interativo para selecionar arquivos
```

### 3. Simulação de Falha
```bash
# Parar serviço
sudo systemctl stop bacula-fd

# Verificar alertas
# Aguardar alerta no Zabbix

# Restaurar serviço
sudo systemctl start bacula-fd
```

## Monitoramento e Alertas

### Dashboards Zabbix
- **Acesso**: http://192.168.100.10/zabbix
- **Usuário**: Admin
- **Senha**: zabbix (alterar após primeiro login)

### Métricas Importantes
- **CPU Usage**: < 80%
- **Memory Usage**: < 85%
- **Disk Usage**: < 90%
- **Backup Success Rate**: > 95%
- **Service Availability**: > 99%

### Configurar Alertas
1. Acessar Zabbix Web Interface
2. Configuration → Actions
3. Configurar email/SMS notifications
4. Definir triggers críticos

## Backup e Recovery

### Política de Backup Padrão
- **Full**: Domingos às 02:00
- **Incremental**: Segunda a Sábado às 02:00
- **Retenção**: 30 dias incrementais, 90 dias full

### Procedimento de Emergency Recovery
```bash
# 1. Verificar últimos backups
echo "list jobs" | bconsole

# 2. Identificar backup necessário
echo "list files jobid=XXX" | bconsole

# 3. Executar restore
echo "restore client=client-fd" | bconsole

# 4. Validar restore
ls -la /bacula-restores/
```

## Manutenção Regular

### Diária
- [ ] Verificar status de backups
- [ ] Revisar alertas críticos
- [ ] Monitorar uso de disco

### Semanal
- [ ] Executar teste de restore
- [ ] Verificar logs de erro
- [ ] Limpar arquivos temporários

### Mensal
- [ ] Revisar capacidade de storage
- [ ] Atualizar documentação
- [ ] Teste de disaster recovery

## Troubleshooting Rápido

### Backup Falha
```bash
# 1. Verificar serviços
systemctl status bacula-director bacula-sd

# 2. Verificar conectividade cliente
ping <client_ip>
telnet <client_ip> 9102

# 3. Verificar logs
tail -f /var/log/bacula/bacula.log

# 4. Reiniciar se necessário
sudo systemctl restart bacula-director
```

### Zabbix Não Monitora
```bash
# 1. Verificar serviço
systemctl status zabbix-server

# 2. Verificar agent no cliente
systemctl status zabbix-agent

# 3. Testar conectividade
telnet <client_ip> 10050

# 4. Verificar configuração
cat /etc/zabbix/zabbix_agentd.conf | grep Server
```

### Performance Baixa
```bash
# 1. Verificar recursos
htop
iotop
df -h

# 2. Verificar processos
ps aux --sort=-%cpu | head -10

# 3. Verificar I/O
iostat -x 1 5

# 4. Otimizar se necessário
nice -n 10 <comando>
ionice -c 3 <comando>
```

## Contatos e Suporte

### Documentação
- **Wiki**: [Link para wiki interna]
- **Runbooks**: /docs/runbooks/
- **API Docs**: /docs/api/

### Escalação
- **Nível 1**: Técnico NOC
- **Nível 2**: Administrador Senior
- **Nível 3**: Arquiteto de Infraestrutura

### Comunicação
- **Slack**: #noc-alerts
- **Email**: noc@empresa.com
- **Telefone**: +55 11 9999-9999

---

**Versão**: 1.0  
**Última Atualização**: $(date)  
**Mantido por**: Equipe NOC
