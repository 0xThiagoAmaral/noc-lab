# Disaster Recovery - Laboratório NOC

## Plano de Contingência e Disaster Recovery

### Objetivos
- **RTO (Recovery Time Objective)**: 4 horas
- **RPO (Recovery Point Objective)**: 24 horas
- **Disponibilidade Alvo**: 99.9% uptime

## Cenários de Disaster

### DR-001: Falha Completa do Servidor Principal

#### Impacto
- Perda total dos serviços de backup
- Interrupção do monitoramento
- Indisponibilidade do storage central

#### Plano de Recovery

##### Fase 1: Avaliação (0-30 min)
1. **Confirmar a falha**
   ```bash
   # Do servidor secundário ou workstation
   ping -c 10 192.168.100.10
   ssh root@192.168.100.10
   nmap -p 22,80,443,9101-9103 192.168.100.10
   ```

2. **Verificar causa raiz**
   - Hardware failure
   - Corrupção de sistema
   - Problema de rede
   - Ataque/malware

3. **Ativar equipe de DR**
   - Notificar supervisor
   - Acionar equipe técnica
   - Comunicar stakeholders

##### Fase 2: Preparação do Ambiente Secundário (30-60 min)

1. **Preparar servidor de backup**
   ```bash
   # No servidor secundário (192.168.100.11)
   sudo apt update && sudo apt upgrade -y
   
   # Verificar recursos disponíveis
   df -h
   free -h
   lscpu
   ```

2. **Configurar rede temporária**
   ```bash
   # Assumir IP do servidor principal
   sudo ip addr add 192.168.100.10/24 dev eth0
   
   # Ou configurar DNS/proxy reverso
   # Atualizar registros DNS se necessário
   ```

##### Fase 3: Restore de Configurações (1-2 horas)

1. **Instalar serviços básicos**
   ```bash
   #!/bin/bash
   # emergency-install.sh
   
   # MySQL
   sudo apt install -y mysql-server
   
   # Bacula
   sudo apt install -y bacula bacula-client bacula-common-mysql
   
   # Zabbix
   wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb
   sudo dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb
   sudo apt update
   sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf
   
   # Storage services
   sudo apt install -y nfs-kernel-server samba
   ```

2. **Restaurar configurações do backup**
   ```bash
   # Montar storage externo ou acessar backup remoto
   sudo mount -t nfs 192.168.100.40:/srv/nfs/backup /mnt/backup
   
   # Restaurar configurações do Bacula
   sudo cp /mnt/backup/configs/bacula/* /etc/bacula/
   
   # Restaurar configurações do Zabbix
   sudo cp /mnt/backup/configs/zabbix/* /etc/zabbix/
   
   # Restaurar configurações de rede
   sudo cp /mnt/backup/configs/network/* /etc/netplan/
   ```

3. **Restaurar databases**
   ```bash
   # MySQL Bacula
   mysql -u root -p < /mnt/backup/databases/bacula_backup.sql
   
   # MySQL Zabbix
   mysql -u root -p < /mnt/backup/databases/zabbix_backup.sql
   ```

##### Fase 4: Verificação e Testes (2-3 horas)

1. **Verificar serviços**
   ```bash
   # Status dos serviços
   systemctl status bacula-director bacula-sd mysql zabbix-server apache2
   
   # Teste do Bacula
   echo "status director" | bconsole
   
   # Teste do Zabbix
   curl -s http://localhost/zabbix | grep -i zabbix
   ```

2. **Teste de conectividade**
   ```bash
   # Teste com clientes
   for client in 192.168.100.20 192.168.100.30; do
       echo "Testando $client..."
       ping -c 3 $client
       telnet $client 9102
   done
   ```

3. **Teste de backup**
   ```bash
   # Executar job de teste
   echo "run job=backup-client-linux level=incremental yes" | bconsole
   
   # Verificar resultado
   echo "list jobs last=1" | bconsole
   ```

##### Fase 5: Comunicação e Documentação (3-4 horas)

1. **Comunicar restauração**
   - Notificar stakeholders
   - Atualizar status em ferramentas de comunicação
   - Documentar ações tomadas

2. **Monitoramento intensivo**
   - Verificar todas as métricas
   - Confirmar funcionalidade completa
   - Estabelecer monitoramento contínuo

### DR-002: Corrupção de Dados de Backup

#### Sintomas
- Jobs de backup falhando consistentemente
- Erro de checksum em volumes
- Corrupção detectada em media

#### Plano de Recovery

1. **Avaliar extensão da corrupção**
   ```bash
   # Verificar integridade dos volumes
   echo "list media" | bconsole
   
   # Verificar status dos volumes
   for volume in $(echo "list media" | bconsole | grep "Vol-" | awk '{print $1}'); do
       echo "Verificando $volume..."
       echo "llist media=$volume" | bconsole
   done
   ```

2. **Isolar volumes corrompidos**
   ```bash
   # Marcar volumes como Error
   echo "update media=Vol-001 volstatus=Error" | bconsole
   ```

3. **Restaurar de backup off-site**
   ```bash
   # Acessar backup remoto
   rsync -avz backup@remote-site:/backup/volumes/ /backup/
   
   # Reimportar volumes
   echo "import" | bconsole
   ```

### DR-003: Falha de Rede/Conectividade

#### Cenário
- Perda de conectividade com clientes
- Falha de switch/router
- Problema de ISP

#### Plano de Recovery

1. **Diagnóstico de rede**
   ```bash
   # Verificar interfaces locais
   ip addr show
   ip route show
   
   # Testar conectividade externa
   ping 8.8.8.8
   traceroute 8.8.8.8
   
   # Verificar ARP table
   arp -a
   ```

2. **Implementar conectividade alternativa**
   ```bash
   # Configurar interface secundária
   sudo ip addr add 192.168.200.10/24 dev eth1
   sudo ip route add default via 192.168.200.1
   
   # Atualizar configurações de clientes se necessário
   ```

3. **Failover para rede backup**
   - Ativar VPN site-to-site
   - Configurar túnel SSH para acesso temporário
   - Implementar 4G/LTE backup se disponível

## Scripts de Disaster Recovery

### Script de Backup Emergencial

```bash
#!/bin/bash
# emergency-backup.sh

EMERGENCY_DEST="/mnt/emergency"
DATE=$(date '+%Y%m%d_%H%M%S')

echo "=== BACKUP EMERGENCIAL - $DATE ==="

# Criar diretório de destino
mkdir -p $EMERGENCY_DEST/$DATE

# Backup de configurações críticas
echo "Fazendo backup de configurações..."
tar -czf $EMERGENCY_DEST/$DATE/configs.tar.gz \
    /etc/bacula/ \
    /etc/zabbix/ \
    /etc/netplan/ \
    /etc/fstab \
    /etc/hosts \
    /etc/network/

# Backup de databases
echo "Fazendo backup de databases..."
mysqldump -u root -p bacula > $EMERGENCY_DEST/$DATE/bacula_db.sql
mysqldump -u root -p zabbix > $EMERGENCY_DEST/$DATE/zabbix_db.sql

# Backup de scripts críticos
echo "Fazendo backup de scripts..."
tar -czf $EMERGENCY_DEST/$DATE/scripts.tar.gz /opt/scripts/

# Backup de logs importantes
echo "Fazendo backup de logs..."
tar -czf $EMERGENCY_DEST/$DATE/logs.tar.gz \
    /var/log/bacula/ \
    /var/log/zabbix/ \
    /var/log/noc-lab/

# Criar checksum
cd $EMERGENCY_DEST/$DATE
find . -type f -exec sha256sum {} \; > checksums.txt

echo "Backup emergencial concluído em: $EMERGENCY_DEST/$DATE"
```

### Script de Restore Rápido

```bash
#!/bin/bash
# quick-restore.sh

BACKUP_SOURCE=$1
if [ -z "$BACKUP_SOURCE" ]; then
    echo "Uso: $0 <caminho_do_backup>"
    exit 1
fi

echo "=== RESTORE RÁPIDO ==="
echo "Fonte: $BACKUP_SOURCE"

# Verificar checksums
echo "Verificando integridade..."
cd $BACKUP_SOURCE
sha256sum -c checksums.txt || {
    echo "ERRO: Falha na verificação de integridade!"
    exit 1
}

# Restaurar configurações
echo "Restaurando configurações..."
tar -xzf configs.tar.gz -C /

# Restaurar databases
echo "Restaurando databases..."
mysql -u root -p bacula < bacula_db.sql
mysql -u root -p zabbix < zabbix_db.sql

# Restaurar scripts
echo "Restaurando scripts..."
tar -xzf scripts.tar.gz -C /

# Reiniciar serviços
echo "Reiniciando serviços..."
systemctl restart bacula-director bacula-sd zabbix-server mysql apache2

echo "Restore concluído!"
```

### Script de Validação Pós-DR

```bash
#!/bin/bash
# validate-dr.sh

echo "=== VALIDAÇÃO PÓS-DISASTER RECOVERY ==="
echo "Data: $(date)"

ERRORS=0

# Função para reportar erro
report_error() {
    echo "❌ ERRO: $1"
    ERRORS=$((ERRORS + 1))
}

# Função para reportar sucesso
report_success() {
    echo "✅ OK: $1"
}

# Verificar serviços
echo
echo "1. Verificando Serviços:"
SERVICES=("bacula-director" "bacula-sd" "bacula-fd" "mysql" "zabbix-server" "apache2")

for service in "${SERVICES[@]}"; do
    if systemctl is-active --quiet $service; then
        report_success "Serviço $service está rodando"
    else
        report_error "Serviço $service está parado"
    fi
done

# Verificar conectividade
echo
echo "2. Verificando Conectividade:"
CLIENTS=("192.168.100.20" "192.168.100.30" "192.168.100.40")

for client in "${CLIENTS[@]}"; do
    if ping -c 1 -W 3 $client > /dev/null 2>&1; then
        report_success "Cliente $client acessível"
    else
        report_error "Cliente $client inacessível"
    fi
done

# Verificar portas de serviço
echo
echo "3. Verificando Portas:"
PORTS=("9101:Bacula-Dir" "9102:Bacula-FD" "9103:Bacula-SD" "10051:Zabbix" "80:Apache")

for port_info in "${PORTS[@]}"; do
    port=${port_info%:*}
    service=${port_info#*:}
    
    if netstat -ln | grep ":$port " > /dev/null; then
        report_success "Porta $port ($service) está listening"
    else
        report_error "Porta $port ($service) não está listening"
    fi
done

# Teste funcional do Bacula
echo
echo "4. Teste Funcional Bacula:"
if echo "status director" | bconsole | grep "Running Jobs" > /dev/null; then
    report_success "Bacula Director respondendo"
else
    report_error "Bacula Director não está respondendo"
fi

# Teste funcional do Zabbix
echo
echo "5. Teste Funcional Zabbix:"
if curl -s http://localhost/zabbix | grep -i "zabbix" > /dev/null; then
    report_success "Zabbix Web Interface acessível"
else
    report_error "Zabbix Web Interface inacessível"
fi

# Verificar espaço em disco
echo
echo "6. Verificando Recursos:"
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -lt 80 ]; then
    report_success "Uso de disco: ${DISK_USAGE}%"
else
    report_error "Uso de disco alto: ${DISK_USAGE}%"
fi

MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
if (( $(echo "$MEM_USAGE < 80" | bc -l) )); then
    report_success "Uso de memória: ${MEM_USAGE}%"
else
    report_error "Uso de memória alto: ${MEM_USAGE}%"
fi

# Resultado final
echo
echo "=== RESULTADO DA VALIDAÇÃO ==="
if [ $ERRORS -eq 0 ]; then
    echo "✅ SUCESSO: Todos os testes passaram!"
    echo "Sistema pronto para operação normal."
    exit 0
else
    echo "❌ FALHA: $ERRORS erro(s) encontrado(s)."
    echo "Revisar e corrigir problemas antes de retomar operação normal."
    exit 1
fi
```

## Procedimentos de Comunicação

### Matriz de Comunicação

| Severidade | Stakeholder | Método | Tempo |
|------------|-------------|---------|-------|
| Crítico | Gerência | Telefone + Email | 15 min |
| Alto | Supervisor | Telefone + Slack | 30 min |
| Médio | Equipe | Email + Slack | 1 hora |
| Baixo | Equipe | Email | 4 horas |

### Template de Comunicação

```markdown
# ALERTA DR: [SEVERIDADE] - [TÍTULO]

## Informações Básicas
- **Data/Hora**: DD/MM/YYYY HH:MM
- **Severidade**: Crítico/Alto/Médio/Baixo  
- **Status**: Iniciado/Em Progresso/Resolvido
- **ETA Resolução**: HH:MM

## Impacto
- **Sistemas Afetados**: [Lista]
- **Serviços Indisponíveis**: [Lista]
- **Usuários Impactados**: [Número/Grupos]

## Ações em Andamento
- [Ação 1]
- [Ação 2]
- [Ação 3]

## Próxima Atualização
[Horário da próxima comunicação]

## Contato
[Nome e telefone do responsável]
```

## Testes de DR

### Cronograma de Testes

- **Teste Parcial**: Mensal (1 componente)
- **Teste Completo**: Trimestral
- **Simulação Full**: Semestral

### Checklist de Teste

```markdown
# TESTE DE DISASTER RECOVERY

## Pré-Teste
- [ ] Ambiente de teste preparado
- [ ] Backups verificados
- [ ] Equipe notificada
- [ ] Documentação revisada

## Durante o Teste
- [ ] Simular falha
- [ ] Executar procedimento de DR
- [ ] Documentar tempos
- [ ] Registrar problemas

## Pós-Teste
- [ ] Validar funcionalidade
- [ ] Medir RTO/RPO
- [ ] Documentar lições aprendidas
- [ ] Atualizar procedimentos

## Métricas
- **Tempo Total de Recovery**: _____ horas
- **RTO Alcançado**: Sim/Não
- **RPO Alcançado**: Sim/Não
- **Problemas Encontrados**: _____
```

## Melhoria Contínua

### KPIs de DR

1. **RTO Real vs. Objetivo**
2. **RPO Real vs. Objetivo**
3. **Sucesso dos Testes de DR**
4. **Tempo de Detecção de Falhas**
5. **Efetividade da Comunicação**

### Revisão Trimestral

1. **Análise de Incidentes**
2. **Atualização de Procedimentos**
3. **Treinamento da Equipe**
4. **Revisão de Tecnologias**
5. **Atualização de Contatos**

## Próximos Passos

1. Automatizar testes de DR
2. Implementar DR site secundário
3. Integrar com cloud backup
4. Desenvolver DR dashboard
5. Criar simuladores de falha
