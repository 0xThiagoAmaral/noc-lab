# Documentação Técnica - Laboratório NOC

## Índice

1. [Runbooks Operacionais](#runbooks)
2. [Procedimentos de Backup](#backup-procedures)
3. [Troubleshooting Guide](#troubleshooting)
4. [Configurações de Sistema](#system-configs)
5. [Políticas e Compliance](#policies)

## Runbooks Operacionais

### RB-001: Falha de Job de Backup

**Prioridade:** Alta  
**Tempo de Resposta:** 15 minutos  
**Tempo de Resolução:** 2 horas  

#### Sintomas
- Alert do Zabbix: "Backup Job Failed"
- Email de falha do Bacula
- Status "E" ou "f" no bconsole

#### Diagnóstico
```bash
# Verificar status do director
echo "status director" | bconsole

# Verificar últimos jobs
echo "list jobs last=10" | bconsole

# Verificar logs
tail -50 /var/log/bacula/bacula.log | grep -i error

# Verificar conectividade com cliente
telnet <client_ip> 9102
```

#### Resolução
1. **Verificar serviços**
   ```bash
   systemctl status bacula-director bacula-sd
   systemctl restart bacula-director
   ```

2. **Verificar espaço em disco**
   ```bash
   df -h /backup
   # Se > 90%, executar limpeza
   /opt/scripts/cleanup-backup.sh
   ```

3. **Verificar conectividade do cliente**
   ```bash
   # No cliente
   systemctl status bacula-fd
   systemctl restart bacula-fd
   ```

4. **Re-executar job**
   ```bash
   echo "run job=backup-client-linux level=incremental yes" | bconsole
   ```

#### Escalação
- Se não resolver em 1 hora: Escalar para Supervisor
- Se perda de dados: Escalar para Gerência

### RB-002: Servidor Inacessível

**Prioridade:** Crítica  
**Tempo de Resposta:** 5 minutos  
**Tempo de Resolução:** 30 minutos  

#### Sintomas
- Timeout em ping/ssh
- Alerts de conectividade
- Serviços não respondem

#### Diagnóstico
```bash
# Do servidor de monitoramento
ping -c 5 <target_server>
traceroute <target_server>
nmap -p 22,80,443 <target_server>

# Verificar logs de rede
journalctl -u networking --since "1 hour ago"
```

#### Resolução
1. **Verificar cabo/switch**
2. **Reiniciar interface de rede**
   ```bash
   # Se acesso local disponível
   sudo ip link set eth0 down
   sudo ip link set eth0 up
   ```
3. **Verificar configuração de rede**
   ```bash
   ip addr show
   ip route show
   ```
4. **Se necessário, reiniciar servidor**

### RB-003: Alto Uso de CPU/Memória

**Prioridade:** Média  
**Tempo de Resposta:** 30 minutos  
**Tempo de Resolução:** 1 hora  

#### Diagnóstico
```bash
# CPU
top -bn1 | head -20
ps aux --sort=-%cpu | head -10

# Memória
free -h
ps aux --sort=-%mem | head -10

# I/O
iostat -x 1 5
iotop -o
```

#### Resolução
1. **Identificar processo problemático**
2. **Verificar se é normal (backup, etc.)**
3. **Se necessário, ajustar nice/ionice**
   ```bash
   renice -n 10 -p <PID>
   ionice -c 3 -p <PID>
   ```
4. **Considerar restart do processo**

## Procedimentos de Backup

### PROC-001: Backup Diário

#### Objetivo
Garantir backup incremental diário de todos os sistemas críticos.

#### Escopo
- Servidores Linux: 192.168.100.20, 192.168.100.30
- Servidor Windows: 192.168.100.30
- Dados: /home, /etc, /var/log, /opt

#### Cronograma
- **Incremental**: Segunda a Sábado às 02:00
- **Full**: Domingo às 02:00
- **Differential**: Quarta-feira às 02:00

#### Procedimento
1. **Pré-verificações**
   ```bash
   # Verificar espaço em disco
   df -h /backup
   
   # Verificar serviços
   systemctl status bacula-director bacula-sd
   
   # Verificar conectividade dos clientes
   for client in 192.168.100.20 192.168.100.30; do
       ping -c 1 $client && echo "$client OK" || echo "$client FAILED"
   done
   ```

2. **Execução Manual (se necessário)**
   ```bash
   # Backup incremental
   echo "run job=backup-client-linux level=incremental yes" | bconsole
   
   # Backup full
   echo "run job=backup-client-linux level=full yes" | bconsole
   ```

3. **Verificação Pós-Backup**
   ```bash
   # Verificar status dos jobs
   echo "list jobs last=5" | bconsole
   
   # Verificar logs
   tail -20 /var/log/bacula/bacula.log
   ```

#### Retenção
- **Full**: 3 meses
- **Incremental**: 30 dias
- **Differential**: 45 dias

### PROC-002: Restore de Dados

#### Cenários
1. **Restore de arquivo específico**
2. **Restore de diretório completo**
3. **Restore bare metal**

#### Procedimento de Restore

1. **Identificar backup necessário**
   ```bash
   echo "list jobs client=client-linux-fd" | bconsole
   echo "list files jobid=<jobid>" | bconsole
   ```

2. **Executar restore**
   ```bash
   echo "restore client=client-linux-fd" | bconsole
   # Seguir wizard interativo
   ```

3. **Restore automatizado**
   ```bash
   cat > /tmp/restore.txt << EOF
   restore client=client-linux-fd
   5
   mark *
   done
   yes
   EOF
   
   bconsole < /tmp/restore.txt
   ```

#### Teste de Restore
- **Frequência**: Mensal
- **Procedimento**: Restore de amostra em ambiente de teste
- **Documentação**: Log de todos os testes

### PROC-003: Disaster Recovery

#### RTO: 4 horas
#### RPO: 24 horas

#### Cenário 1: Falha de Hardware do Servidor

1. **Preparar novo hardware**
2. **Instalar sistema operacional base**
3. **Instalar Bacula**
4. **Configurar rede**
5. **Restore de configurações**
   ```bash
   # Restore do /etc
   echo "restore client=backup-server-fd fileset=Config-FS where=/tmp/restore" | bconsole
   
   # Aplicar configurações
   cp -r /tmp/restore/etc/* /etc/
   ```
6. **Restore de dados**
7. **Testes de funcionalidade**

#### Cenário 2: Corrupção de Dados

1. **Parar serviços afetados**
2. **Identificar extent da corrupção**
3. **Selecionar ponto de restore**
4. **Executar restore**
5. **Verificar integridade**
6. **Reiniciar serviços**

## Configurações de Sistema

### Configuração de Rede

#### Interfaces
```bash
# /etc/netplan/00-netcfg.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 192.168.100.10/24
      gateway4: 192.168.100.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

#### Firewall
```bash
# Regras UFW padrão
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow from 192.168.100.0/24
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 9101:9103/tcp  # Bacula
ufw allow 10050:10051/tcp  # Zabbix
ufw --force enable
```

### Configuração de Monitoramento

#### Zabbix Server
```bash
# /etc/zabbix/zabbix_server.conf (principais parâmetros)
LogFile=/var/log/zabbix/zabbix_server.log
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=<senha>
StartPollers=5
StartTrappers=5
CacheSize=64M
HistoryCacheSize=128M
TrendCacheSize=8M
ValueCacheSize=128M
Timeout=4
LogSlowQueries=3000
```

#### Alertas por Email
```bash
# /etc/zabbix/zabbix_server.conf
AlertScriptsPath=/usr/lib/zabbix/alertscripts

# Script de email: /usr/lib/zabbix/alertscripts/email.sh
#!/bin/bash
TO="$1"
SUBJECT="$2"
MESSAGE="$3"

echo "$MESSAGE" | mail -s "$SUBJECT" "$TO"
```

### Configuração de Backup

#### Bacula Director
```bash
# /etc/bacula/bacula-dir.conf (template básico)
Director {
  Name = backup-server-dir
  DIRport = 9101
  QueryFile = "/etc/bacula/query.sql"
  WorkingDirectory = "/var/lib/bacula"
  PidDirectory = "/run/bacula"
  Maximum Concurrent Jobs = 20
  Password = "<senha>"
  Messages = Daemon
}

# Pool de backup
Pool {
  Name = Full-Pool
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Volume Retention = 90 days
  Maximum Volume Bytes = 50G
  Maximum Volumes = 100
  Label Format = "Full-Vol-"
}

# Schedule padrão
Schedule {
  Name = "WeeklyCycle"
  Run = Full 1st sun at 23:05
  Run = Differential 2nd-5th sun at 23:05
  Run = Incremental mon-sat at 23:05
}
```

## Políticas e Compliance

### POL-001: Política de Backup

#### Objetivos
- **RPO**: 24 horas para dados críticos
- **RTO**: 4 horas para restauração completa
- **Disponibilidade**: 99.9% de uptime dos sistemas de backup

#### Classificação de Dados
1. **Críticos**: Backup diário + replicação off-site
2. **Importantes**: Backup diário + retenção 90 dias
3. **Normais**: Backup semanal + retenção 30 dias

#### Responsabilidades
- **NOC**: Monitoramento e operação diária
- **Administrador**: Configuração e manutenção
- **Usuários**: Identificação de dados críticos

### POL-002: Política de Monitoramento

#### Métricas Obrigatórias
- **Disponibilidade**: Uptime de sistemas críticos
- **Performance**: CPU, Memória, Disco, Rede
- **Capacidade**: Uso de disco, crescimento de dados
- **Segurança**: Tentativas de login, alterações de configuração

#### Alertas
- **Crítico**: Resposta imediata (5 min)
- **Alto**: Resposta em 15 minutos
- **Médio**: Resposta em 1 hora
- **Baixo**: Revisão diária

### POL-003: Política de Mudanças

#### Categorias
1. **Emergencial**: Implementação imediata
2. **Padrão**: Aprovação + janela de manutenção
3. **Normal**: Processo completo de mudança

#### Processo
1. **Solicitação**: RFC documentada
2. **Avaliação**: Impacto e risco
3. **Aprovação**: CAB (Change Advisory Board)
4. **Implementação**: Janela aprovada
5. **Verificação**: Testes pós-mudança
6. **Documentação**: Atualização de docs

### Checklist de Compliance

#### Diário
- [ ] Verificar jobs de backup
- [ ] Revisar alertas críticos
- [ ] Confirmar disponibilidade dos sistemas
- [ ] Verificar espaço em disco

#### Semanal
- [ ] Teste de restore
- [ ] Revisão de capacidade
- [ ] Análise de tendências
- [ ] Limpeza de logs antigos

#### Mensal
- [ ] Relatório de disponibilidade
- [ ] Revisão de políticas
- [ ] Teste de disaster recovery
- [ ] Auditoria de acessos

#### Trimestral
- [ ] Revisão de documentação
- [ ] Treinamento da equipe
- [ ] Avaliação de ferramentas
- [ ] Planejamento de capacidade

## Templates de Documentação

### Template de Incidente

```markdown
# INCIDENTE: INC-YYYY-NNNN

## Informações Básicas
- **Data/Hora**: DD/MM/YYYY HH:MM
- **Severidade**: Crítico/Alto/Médio/Baixo
- **Status**: Aberto/Em Progresso/Resolvido/Fechado
- **Responsável**: Nome do técnico

## Descrição
[Descrição detalhada do problema]

## Impacto
- **Sistemas Afetados**: 
- **Usuários Impactados**: 
- **Serviços Indisponíveis**: 

## Cronologia
- **HH:MM** - Evento inicial
- **HH:MM** - Identificação do problema
- **HH:MM** - Início da correção
- **HH:MM** - Resolução

## Root Cause
[Causa raiz identificada]

## Solução
[Passos executados para resolução]

## Prevenção
[Ações para evitar reocorrência]

## Lições Aprendidas
[O que foi aprendido com este incidente]
```

### Template de Mudança

```markdown
# CHANGE REQUEST: CHG-YYYY-NNNN

## Informações Básicas
- **Solicitante**: Nome
- **Data de Solicitação**: DD/MM/YYYY
- **Implementação Planejada**: DD/MM/YYYY HH:MM
- **Categoria**: Emergencial/Padrão/Normal

## Descrição da Mudança
[Detalhes da mudança proposta]

## Justificativa
[Por que a mudança é necessária]

## Impacto
- **Sistemas Afetados**: 
- **Downtime Esperado**: 
- **Usuários Impactados**: 

## Plano de Implementação
1. [Passo 1]
2. [Passo 2]
3. [Passo 3]

## Plano de Rollback
1. [Passo 1 de rollback]
2. [Passo 2 de rollback]

## Testes
[Como verificar se a mudança foi bem-sucedida]

## Aprovações
- [ ] Administrador de Sistema
- [ ] Gerente de TI
- [ ] Usuário Final (se aplicável)
```

## Próximos Passos

1. Implementar documentação colaborativa (Wiki)
2. Criar base de conhecimento
3. Automatizar geração de documentos
4. Integrar com ferramentas ITSM
5. Desenvolver treinamentos online
