# Cenários Práticos - Laboratório NOC

## Simulações de Ambiente Real

### Cenário 1: Implementação de Nova Infraestrutura
### Cenário 2: Migração de Backup Legacy
### Cenário 3: Incident Response Completo
### Cenário 4: Capacity Planning
### Cenário 5: Security Breach Response

## Cenário 1: Nova Infraestrutura

### Situação
A empresa adquiriu 5 novos servidores e precisa implementar backup e monitoramento completo em 48 horas.

#### Requisitos
- 3 servidores Linux (Ubuntu 22.04)
- 2 servidores Windows (Server 2022)
- Backup completo configurado
- Monitoramento 24/7 ativo
- Documentação completa

#### Implementação

##### Dia 1: Preparação e Instalação Base

```bash
#!/bin/bash
# deploy-new-infrastructure.sh

NEW_SERVERS=("192.168.100.50" "192.168.100.51" "192.168.100.52" "192.168.100.53" "192.168.100.54")
LINUX_SERVERS=("192.168.100.50" "192.168.100.51" "192.168.100.52")
WINDOWS_SERVERS=("192.168.100.53" "192.168.100.54")

echo "=== IMPLEMENTAÇÃO DE NOVA INFRAESTRUTURA ==="
echo "Data: $(date)"

# Verificar conectividade inicial
for server in "${NEW_SERVERS[@]}"; do
    echo "Testando conectividade com $server..."
    if ping -c 3 $server > /dev/null 2>&1; then
        echo "✅ $server: Conectividade OK"
    else
        echo "❌ $server: Sem conectividade"
        exit 1
    fi
done

# Configurar servidores Linux
for server in "${LINUX_SERVERS[@]}"; do
    echo "Configurando servidor Linux $server..."
    
    ssh root@$server << 'EOF'
# Atualizar sistema
apt update && apt upgrade -y

# Instalar dependências básicas
apt install -y vim htop iotop curl wget git

# Instalar e configurar Bacula FD
apt install -y bacula-client

# Configurar Bacula FD
cat > /etc/bacula/bacula-fd.conf << 'BACULA_EOF'
Director {
  Name = backup-server-dir
  Password = "ClientPassword123"
}

FileDaemon {
  Name = NEW_SERVER_HOSTNAME-fd
  FDport = 9102
  WorkingDirectory = /var/lib/bacula
  Pid Directory = /run/bacula
  Maximum Concurrent Jobs = 20
}

Messages {
  Name = Standard
  director = backup-server-dir = all, !skipped, !restored
}
BACULA_EOF

# Substituir hostname real
sed -i "s/NEW_SERVER_HOSTNAME/$(hostname)/" /etc/bacula/bacula-fd.conf

# Instalar e configurar Zabbix Agent
wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb
dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb
apt update
apt install -y zabbix-agent

# Configurar Zabbix Agent
sed -i 's/Server=127.0.0.1/Server=192.168.100.10/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/ServerActive=127.0.0.1/ServerActive=192.168.100.10/' /etc/zabbix/zabbix_agentd.conf
sed -i "s/Hostname=Zabbix server/Hostname=$(hostname)/" /etc/zabbix/zabbix_agentd.conf

# Habilitar e iniciar serviços
systemctl enable bacula-fd zabbix-agent
systemctl start bacula-fd zabbix-agent

# Configurar firewall
ufw allow from 192.168.100.10
ufw allow ssh
ufw --force enable

echo "Servidor $(hostname) configurado com sucesso"
EOF

    echo "✅ Servidor $server configurado"
done

# Gerar configurações para o Bacula Director
echo "Gerando configurações do Bacula Director..."

for i in "${!LINUX_SERVERS[@]}"; do
    server=${LINUX_SERVERS[$i]}
    hostname="linux-server-0$((i+1))"
    
    cat >> /tmp/new-clients.conf << EOF

# Cliente: $hostname
Client {
  Name = ${hostname}-fd
  Address = $server
  FDPort = 9102
  Catalog = MyCatalog
  Password = "ClientPassword123"
  File Retention = 60 days
  Job Retention = 6 months
  AutoPrune = yes
}

Job {
  Name = "backup-${hostname}"
  Type = Backup
  Level = Incremental
  Client = ${hostname}-fd
  FileSet = "Linux-FS"
  Schedule = "Daily-Schedule"
  Storage = File-Storage
  Messages = Standard
  Pool = Incremental-Pool
  Full Backup Pool = Full-Pool
  Priority = 10
  Write Bootstrap = "/var/lib/bacula/%c.bsr"
}
EOF
done

# Adicionar configurações ao Bacula Director
cat /tmp/new-clients.conf >> /etc/bacula/bacula-dir.conf

# Reiniciar Bacula Director
systemctl restart bacula-director

echo "=== CONFIGURAÇÃO LINUX CONCLUÍDA ==="
```

##### Configuração Windows PowerShell

```powershell
# configure-windows-servers.ps1

$WindowsServers = @("192.168.100.53", "192.168.100.54")
$BaculaDirectorIP = "192.168.100.10"

foreach ($Server in $WindowsServers) {
    Write-Host "Configurando servidor Windows: $Server"
    
    # Criar sessão remota
    $Session = New-PSSession -ComputerName $Server -Credential (Get-Credential)
    
    Invoke-Command -Session $Session -ScriptBlock {
        param($DirectorIP)
        
        # Criar diretório temporário
        New-Item -ItemType Directory -Force -Path C:\temp
        
        # Download do Bacula Windows Client
        $BaculaURL = "https://www.bacula.org/packages/windows/bacula-win64-13.0.1.exe"
        $BaculaInstaller = "C:\temp\bacula-installer.exe"
        
        Invoke-WebRequest -Uri $BaculaURL -OutFile $BaculaInstaller
        
        # Instalação silenciosa
        Start-Process -FilePath $BaculaInstaller -ArgumentList "/S" -Wait
        
        # Configuração do Bacula FD
        $BaculaConfig = @"
Director {
  Name = backup-server-dir
  Password = "ClientPassword123"
}

FileDaemon {
  Name = $env:COMPUTERNAME-fd
  FDport = 9102
  WorkingDirectory = "C:\Bacula\working"
  Pid Directory = "C:\Bacula\working"
  Maximum Concurrent Jobs = 20
}

Messages {
  Name = Standard
  director = backup-server-dir = all, !skipped, !restored
}
"@

        $BaculaConfig | Out-File -FilePath "C:\Bacula\bacula-fd.conf" -Encoding ASCII
        
        # Reiniciar serviço
        Restart-Service -Name "Bacula File Daemon"
        
        # Configurar Windows Firewall
        New-NetFirewallRule -DisplayName "Bacula FD" -Direction Inbound -Protocol TCP -LocalPort 9102 -Action Allow
        New-NetFirewallRule -DisplayName "Bacula from Director" -Direction Inbound -Protocol TCP -RemoteAddress $DirectorIP -Action Allow
        
        Write-Host "Servidor $env:COMPUTERNAME configurado com sucesso"
        
    } -ArgumentList $BaculaDirectorIP
    
    Remove-PSSession $Session
}

Write-Host "Configuração Windows concluída"
```

##### Dia 2: Testes e Validação

```bash
#!/bin/bash
# validate-new-infrastructure.sh

echo "=== VALIDAÇÃO DA NOVA INFRAESTRUTURA ==="

ALL_SERVERS=("192.168.100.50" "192.168.100.51" "192.168.100.52" "192.168.100.53" "192.168.100.54")

# Teste de conectividade
echo "1. Testando conectividade..."
for server in "${ALL_SERVERS[@]}"; do
    if ping -c 3 $server > /dev/null 2>&1; then
        echo "✅ $server: Conectividade OK"
    else
        echo "❌ $server: Falha de conectividade"
    fi
done

# Teste de serviços Bacula
echo
echo "2. Testando clientes Bacula..."
for server in "${ALL_SERVERS[@]}"; do
    if timeout 5 bash -c "</dev/tcp/$server/9102" 2>/dev/null; then
        echo "✅ $server: Bacula FD OK"
    else
        echo "❌ $server: Bacula FD não responde"
    fi
done

# Teste de backup
echo
echo "3. Executando testes de backup..."
for i in {1..5}; do
    hostname="server-0$i"
    echo "Testando backup de $hostname..."
    
    # Executar job de teste
    echo "run job=backup-$hostname level=incremental yes" | bconsole
    
    # Aguardar conclusão
    sleep 30
    
    # Verificar resultado
    result=$(echo "list jobs client=${hostname}-fd last=1" | bconsole | grep "T\|E\|f")
    if [[ $result == *"T"* ]]; then
        echo "✅ Backup de $hostname: SUCESSO"
    else
        echo "❌ Backup de $hostname: FALHA"
    fi
done

# Teste de monitoramento Zabbix
echo
echo "4. Verificando monitoramento Zabbix..."
for server in "${ALL_SERVERS[@]}"; do
    if timeout 5 bash -c "</dev/tcp/$server/10050" 2>/dev/null; then
        echo "✅ $server: Zabbix Agent OK"
    else
        echo "❌ $server: Zabbix Agent não responde"
    fi
done

echo
echo "=== VALIDAÇÃO CONCLUÍDA ==="
```

## Cenário 2: Migração de Backup Legacy

### Situação
Empresa possui sistema de backup antigo (tape-based) e precisa migrar para solução moderna sem perder dados históricos.

#### Desafios
- Migração de 10TB de dados históricos
- Zero downtime durante migração
- Manutenção da conformidade regulatória
- Treinamento da equipe

#### Plano de Migração

##### Fase 1: Assessment e Planejamento

```bash
#!/bin/bash
# assess-legacy-backup.sh

echo "=== ASSESSMENT DO SISTEMA LEGACY ==="

# Inventário de tapes
echo "1. Inventário de Tapes:"
mtx -f /dev/sg0 status | grep "Full"

# Análise de dados
echo "2. Análise de volume de dados:"
for tape in $(mtx -f /dev/sg0 status | grep "Full" | awk '{print $3}'); do
    echo "Tape $tape:"
    tar -tzf /dev/st0 | wc -l
    tar -tzf /dev/st0 | du -ch | tail -1
done

# Mapeamento de retention policies
echo "3. Políticas de retenção atuais:"
cat > /tmp/legacy-retention.txt << EOF
Dados Financeiros: 7 anos
Dados Operacionais: 3 anos
Logs de Sistema: 1 ano
Backups de Email: 5 anos
EOF

# Análise de compliance
echo "4. Requisitos de compliance:"
echo "- SOX: Dados financeiros por 7 anos"
echo "- LGPD: Logs de acesso por 2 anos"
echo "- ISO 27001: Evidências de backup por 3 anos"
```

##### Fase 2: Migração Gradual

```bash
#!/bin/bash
# migrate-legacy-data.sh

LEGACY_MOUNT="/mnt/legacy"
NEW_BACKUP="/backup/migrated"
PARALLEL_JOBS=4

echo "=== MIGRAÇÃO DE DADOS LEGACY ==="

# Criar estrutura de destino
mkdir -p $NEW_BACKUP/{2020,2021,2022,2023,2024,2025}

# Função de migração paralela
migrate_tape() {
    local tape_id=$1
    local year=$2
    
    echo "Migrando tape $tape_id (ano $year)..."
    
    # Carregar tape
    mtx -f /dev/sg0 load $tape_id
    
    # Criar diretório específico
    mkdir -p $NEW_BACKUP/$year/tape_$tape_id
    
    # Extrair dados
    tar -xf /dev/st0 -C $NEW_BACKUP/$year/tape_$tape_id/
    
    # Gerar checksum
    find $NEW_BACKUP/$year/tape_$tape_id/ -type f -exec sha256sum {} \; > $NEW_BACKUP/$year/tape_$tape_id/checksums.txt
    
    # Comprimir para economia de espaço
    tar -czf $NEW_BACKUP/$year/tape_$tape_id.tar.gz -C $NEW_BACKUP/$year/ tape_$tape_id/
    rm -rf $NEW_BACKUP/$year/tape_$tape_id/
    
    echo "✅ Tape $tape_id migrado com sucesso"
}

# Lista de tapes por ano
declare -A TAPES_BY_YEAR
TAPES_BY_YEAR[2020]="001 002 003"
TAPES_BY_YEAR[2021]="004 005 006 007"
TAPES_BY_YEAR[2022]="008 009 010 011 012"
TAPES_BY_YEAR[2023]="013 014 015 016"
TAPES_BY_YEAR[2024]="017 018 019 020"

# Migração com controle de paralelismo
for year in "${!TAPES_BY_YEAR[@]}"; do
    echo "Migrando dados de $year..."
    
    for tape in ${TAPES_BY_YEAR[$year]}; do
        # Controlar número de jobs paralelos
        while [ $(jobs -r | wc -l) -ge $PARALLEL_JOBS ]; do
            sleep 10
        done
        
        migrate_tape $tape $year &
    done
    
    # Aguardar conclusão do ano
    wait
    echo "✅ Ano $year migrado completamente"
done

echo "=== MIGRAÇÃO CONCLUÍDA ==="
```

##### Fase 3: Validação e Cutover

```bash
#!/bin/bash
# validate-migration.sh

NEW_BACKUP="/backup/migrated"

echo "=== VALIDAÇÃO DA MIGRAÇÃO ==="

# Verificar integridade de todos os arquivos
echo "1. Verificando integridade de dados..."
find $NEW_BACKUP -name "checksums.txt" | while read checksum_file; do
    dir=$(dirname $checksum_file)
    echo "Verificando $dir..."
    
    cd $dir
    if sha256sum -c checksums.txt > /dev/null 2>&1; then
        echo "✅ $dir: Integridade OK"
    else
        echo "❌ $dir: Falha de integridade"
    fi
done

# Comparar tamanhos totais
echo "2. Comparando volumes de dados..."
LEGACY_SIZE=$(cat /var/log/legacy-backup.log | grep "Total:" | tail -1 | awk '{print $2}')
NEW_SIZE=$(du -sb $NEW_BACKUP | awk '{print $1}')

echo "Legacy: $(numfmt --to=iec $LEGACY_SIZE)"
echo "Novo: $(numfmt --to=iec $NEW_SIZE)"

# Teste de restore pontual
echo "3. Testando restore de amostra..."
SAMPLE_FILE="$NEW_BACKUP/2024/tape_020.tar.gz"
RESTORE_DIR="/tmp/restore-test"

mkdir -p $RESTORE_DIR
tar -xzf $SAMPLE_FILE -C $RESTORE_DIR

if [ -d "$RESTORE_DIR/tape_020" ]; then
    echo "✅ Teste de restore: SUCESSO"
    rm -rf $RESTORE_DIR
else
    echo "❌ Teste de restore: FALHA"
fi

# Atualizar Bacula com novos volumes
echo "4. Integrando com Bacula..."
for year in 2020 2021 2022 2023 2024; do
    for tape_file in $NEW_BACKUP/$year/*.tar.gz; do
        volume_name=$(basename $tape_file .tar.gz)
        
        echo "UPDATE Media SET VolumeName='$volume_name', MediaType='File' WHERE VolumeName LIKE '%$(echo $volume_name | cut -d'_' -f2)%';" | mysql -u bacula -p bacula
    done
done

echo "=== VALIDAÇÃO CONCLUÍDA ==="
```

## Cenário 3: Incident Response Completo

### Situação
Sexta-feira, 18:30 - Múltiplos alertas indicam possível comprometimento de segurança e falha sistêmica.

#### Alertas Recebidos
- Zabbix: "High CPU usage on all servers"
- Bacula: "Multiple backup jobs failed"
- Firewall: "Unusual outbound traffic detected"
- Antivirus: "Suspicious file detected"

#### Resposta ao Incidente

##### Minuto 0-5: Triagem Inicial

```bash
#!/bin/bash
# incident-response-initial.sh

INCIDENT_ID="INC-$(date +%Y%m%d-%H%M%S)"
INCIDENT_DIR="/var/log/incidents/$INCIDENT_ID"
mkdir -p $INCIDENT_DIR

echo "=== RESPOSTA AO INCIDENTE: $INCIDENT_ID ==="
echo "Início: $(date)" | tee $INCIDENT_DIR/timeline.log

# Snapshot imediato do estado do sistema
echo "[$(date)] Coletando evidências iniciais..." | tee -a $INCIDENT_DIR/timeline.log

# Processos em execução
ps aux > $INCIDENT_DIR/processes.txt

# Conexões de rede
netstat -tulpn > $INCIDENT_DIR/connections.txt
ss -tulpn > $INCIDENT_DIR/sockets.txt

# Logs recentes
journalctl --since "30 minutes ago" > $INCIDENT_DIR/system-logs.txt

# Status dos serviços
systemctl list-units --failed > $INCIDENT_DIR/failed-services.txt

# Verificações de segurança rápidas
echo "[$(date)] Verificando indicadores de comprometimento..." | tee -a $INCIDENT_DIR/timeline.log

# Verificar logins suspeitos
lastlog | grep -v "Never" | tail -20 > $INCIDENT_DIR/recent-logins.txt

# Verificar alterações recentes em arquivos críticos
find /etc /bin /usr/bin -mtime -1 -type f > $INCIDENT_DIR/recent-changes.txt

# Verificar uso de CPU por processo
top -bn1 | head -20 > $INCIDENT_DIR/cpu-usage.txt

echo "[$(date)] Evidências iniciais coletadas" | tee -a $INCIDENT_DIR/timeline.log
```

##### Minuto 5-15: Isolamento e Contenção

```bash
#!/bin/bash
# incident-containment.sh

INCIDENT_DIR="/var/log/incidents/$INCIDENT_ID"

echo "[$(date)] Iniciando contenção..." | tee -a $INCIDENT_DIR/timeline.log

# Identificar processos suspeitos (alto CPU)
SUSPICIOUS_PIDS=$(ps aux --sort=-%cpu | head -10 | awk 'NR>1 && $3>50 {print $2}')

if [ ! -z "$SUSPICIOUS_PIDS" ]; then
    echo "[$(date)] Processos suspeitos identificados: $SUSPICIOUS_PIDS" | tee -a $INCIDENT_DIR/timeline.log
    
    for pid in $SUSPICIOUS_PIDS; do
        # Coletar informações detalhadas antes de matar
        ps -p $pid -o pid,ppid,user,cmd > $INCIDENT_DIR/process-$pid-details.txt
        lsof -p $pid > $INCIDENT_DIR/process-$pid-files.txt 2>/dev/null
        
        # Isolamento do processo (primeiro pausar, depois analisar)
        kill -STOP $pid
        echo "[$(date)] Processo $pid pausado" | tee -a $INCIDENT_DIR/timeline.log
    done
fi

# Bloquear tráfego suspeito
echo "[$(date)] Implementando bloqueios de rede..." | tee -a $INCIDENT_DIR/timeline.log

# Analisar conexões suspeitas
netstat -tulpn | grep ESTABLISHED | while read line; do
    remote_ip=$(echo $line | awk '{print $5}' | cut -d: -f1)
    
    # Verificar se é IP externo suspeito (não RFC1918)
    if [[ ! $remote_ip =~ ^192\.168\. ]] && [[ ! $remote_ip =~ ^10\. ]] && [[ ! $remote_ip =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        echo "Conexão suspeita para $remote_ip" | tee -a $INCIDENT_DIR/suspicious-connections.txt
        
        # Bloquear temporariamente
        iptables -A OUTPUT -d $remote_ip -j DROP
        echo "[$(date)] Bloqueado tráfego para $remote_ip" | tee -a $INCIDENT_DIR/timeline.log
    fi
done

# Isolar serviços críticos se necessário
if [ "$(echo $SUSPICIOUS_PIDS | wc -w)" -gt 5 ]; then
    echo "[$(date)] Múltiplos processos suspeitos - isolando serviços críticos" | tee -a $INCIDENT_DIR/timeline.log
    
    # Parar serviços não essenciais
    systemctl stop apache2 nginx vsftpd
    
    # Modo de manutenção
    touch /etc/maintenance-mode
fi

echo "[$(date)] Contenção implementada" | tee -a $INCIDENT_DIR/timeline.log
```

##### Minuto 15-45: Análise Forense

```bash
#!/bin/bash
# incident-forensics.sh

INCIDENT_DIR="/var/log/incidents/$INCIDENT_ID"

echo "[$(date)] Iniciando análise forense..." | tee -a $INCIDENT_DIR/timeline.log

# Análise de malware
echo "[$(date)] Escaneando malware..." | tee -a $INCIDENT_DIR/timeline.log
clamscan -r /tmp /var/tmp /home > $INCIDENT_DIR/malware-scan.txt 2>&1

# Análise de logs de autenticação
echo "[$(date)] Analisando logs de autenticação..." | tee -a $INCIDENT_DIR/timeline.log
grep -E "(Failed|Invalid|Authentication failure)" /var/log/auth.log | tail -100 > $INCIDENT_DIR/auth-failures.txt

# Análise de tráfego de rede
echo "[$(date)] Analisando padrões de rede..." | tee -a $INCIDENT_DIR/timeline.log
if command -v tcpdump > /dev/null; then
    # Capturar amostra de tráfego
    timeout 60 tcpdump -i any -w $INCIDENT_DIR/network-sample.pcap &
fi

# Verificar integridade de arquivos críticos
echo "[$(date)] Verificando integridade de arquivos..." | tee -a $INCIDENT_DIR/timeline.log
for file in /etc/passwd /etc/shadow /etc/sudoers /etc/ssh/sshd_config; do
    if [ -f "$file" ]; then
        stat "$file" > $INCIDENT_DIR/file-$(basename $file)-stat.txt
        sha256sum "$file" > $INCIDENT_DIR/file-$(basename $file)-hash.txt
    fi
done

# Verificar histórico de comandos
echo "[$(date)] Coletando histórico de comandos..." | tee -a $INCIDENT_DIR/timeline.log
for user_home in /home/*; do
    if [ -f "$user_home/.bash_history" ]; then
        user=$(basename $user_home)
        tail -100 "$user_home/.bash_history" > $INCIDENT_DIR/history-$user.txt
    fi
done

# Análise de logs do Bacula
echo "[$(date)] Analisando falhas de backup..." | tee -a $INCIDENT_DIR/timeline.log
grep -E "(Error|Fatal|Failed)" /var/log/bacula/bacula.log | tail -50 > $INCIDENT_DIR/bacula-errors.txt

echo "[$(date)] Análise forense concluída" | tee -a $INCIDENT_DIR/timeline.log
```

##### Minuto 45-90: Recovery e Limpeza

```bash
#!/bin/bash
# incident-recovery.sh

INCIDENT_DIR="/var/log/incidents/$INCIDENT_ID"

echo "[$(date)] Iniciando recovery..." | tee -a $INCIDENT_DIR/timeline.log

# Análise dos achados
MALWARE_FOUND=$(grep -c "FOUND" $INCIDENT_DIR/malware-scan.txt 2>/dev/null || echo 0)
SUSPICIOUS_LOGINS=$(wc -l < $INCIDENT_DIR/auth-failures.txt 2>/dev/null || echo 0)

echo "Malware encontrado: $MALWARE_FOUND" | tee -a $INCIDENT_DIR/summary.txt
echo "Logins suspeitos: $SUSPICIOUS_LOGINS" | tee -a $INCIDENT_DIR/summary.txt

if [ "$MALWARE_FOUND" -gt 0 ]; then
    echo "[$(date)] Removendo malware detectado..." | tee -a $INCIDENT_DIR/timeline.log
    
    # Remover arquivos infectados
    grep "FOUND" $INCIDENT_DIR/malware-scan.txt | while read line; do
        infected_file=$(echo $line | awk '{print $1}' | cut -d: -f1)
        if [ -f "$infected_file" ]; then
            mv "$infected_file" "$INCIDENT_DIR/quarantine/"
            echo "[$(date)] Arquivo $infected_file movido para quarentena" | tee -a $INCIDENT_DIR/timeline.log
        fi
    done
fi

# Limpar processos suspeitos
if [ ! -z "$SUSPICIOUS_PIDS" ]; then
    echo "[$(date)] Terminando processos suspeitos..." | tee -a $INCIDENT_DIR/timeline.log
    
    for pid in $SUSPICIOUS_PIDS; do
        if ps -p $pid > /dev/null; then
            kill -TERM $pid
            sleep 5
            if ps -p $pid > /dev/null; then
                kill -KILL $pid
            fi
            echo "[$(date)] Processo $pid terminado" | tee -a $INCIDENT_DIR/timeline.log
        fi
    done
fi

# Restaurar serviços
echo "[$(date)] Restaurando serviços..." | tee -a $INCIDENT_DIR/timeline.log

# Remover bloqueios de rede temporários
iptables -F OUTPUT

# Reiniciar serviços críticos
systemctl restart bacula-director bacula-sd zabbix-server

# Verificar se serviços estão funcionando
for service in bacula-director bacula-sd zabbix-server mysql; do
    if systemctl is-active --quiet $service; then
        echo "[$(date)] Serviço $service: OK" | tee -a $INCIDENT_DIR/timeline.log
    else
        echo "[$(date)] Serviço $service: FALHA" | tee -a $INCIDENT_DIR/timeline.log
        systemctl restart $service
    fi
done

# Remover modo de manutenção
rm -f /etc/maintenance-mode

# Executar backup de verificação
echo "[$(date)] Executando backup de verificação..." | tee -a $INCIDENT_DIR/timeline.log
echo "run job=backup-client-linux level=incremental yes" | bconsole

echo "[$(date)] Recovery concluído" | tee -a $INCIDENT_DIR/timeline.log
```

##### Pós-Incidente: Relatório e Lições Aprendidas

```bash
#!/bin/bash
# incident-report.sh

INCIDENT_DIR="/var/log/incidents/$INCIDENT_ID"

# Gerar relatório final
cat > $INCIDENT_DIR/final-report.md << EOF
# RELATÓRIO DE INCIDENTE: $INCIDENT_ID

## Resumo Executivo
- **Início**: $(head -1 $INCIDENT_DIR/timeline.log | cut -d']' -f1 | tr -d '[')
- **Fim**: $(date)
- **Duração**: $(($(date +%s) - $(date -d "$(head -1 $INCIDENT_DIR/timeline.log | cut -d']' -f1 | tr -d '[')" +%s))) segundos
- **Severidade**: $([ "$MALWARE_FOUND" -gt 0 ] && echo "ALTA" || echo "MÉDIA")
- **Status**: RESOLVIDO

## Cronologia
$(cat $INCIDENT_DIR/timeline.log)

## Achados Técnicos
- Malware detectado: $MALWARE_FOUND arquivos
- Logins suspeitos: $SUSPICIOUS_LOGINS eventos
- Processos suspeitos: $(echo $SUSPICIOUS_PIDS | wc -w)
- Serviços afetados: $(cat $INCIDENT_DIR/failed-services.txt | wc -l)

## Ações Tomadas
1. Coleta de evidências forenses
2. Isolamento de processos suspeitos
3. Bloqueio de tráfego malicioso
4. Remoção de malware
5. Restauração de serviços

## Causa Raiz
$([ "$MALWARE_FOUND" -gt 0 ] && echo "Infecção por malware" || echo "Sobrecarga de sistema")

## Prevenção
1. Atualizar definições de antivírus
2. Implementar monitoramento de comportamento
3. Revisar políticas de acesso
4. Melhorar alertas proativos

## Lições Aprendidas
1. Resposta foi efetiva mas pode ser mais rápida
2. Necessário melhor isolamento automático
3. Documentação forense adequada
4. Comunicação com stakeholders foi eficiente
EOF

echo "Relatório de incidente gerado: $INCIDENT_DIR/final-report.md"
```

## Conclusão do Laboratório

Este laboratório NOC fornece uma base sólida para desenvolvimento de competências em:

### Competências Técnicas Desenvolvidas

1. **Administração de Sistemas**
   - Linux (Ubuntu, CentOS)
   - Windows Server
   - Virtualização

2. **Backup e Recovery**
   - Bacula Community
   - Scripts automatizados
   - Disaster Recovery

3. **Monitoramento**
   - Zabbix
   - Nagios
   - Grafana/Prometheus

4. **Protocolos de Rede**
   - CIFS/SMB
   - NFS
   - FTP/SFTP
   - iSCSI

5. **Troubleshooting**
   - Diagnóstico sistemático
   - Análise de logs
   - Performance tuning

6. **Automação**
   - Shell scripting
   - Cron jobs
   - Monitoring automation

### Competências Operacionais

1. **Documentação Técnica**
2. **Incident Response**
3. **Change Management**
4. **Capacity Planning**
5. **Security Operations**

### Próximos Níveis

1. **Cloud Integration**
   - AWS/Azure backup
   - Hybrid monitoring
   - Container orchestration

2. **Advanced Automation**
   - Ansible/Terraform
   - CI/CD pipelines
   - Infrastructure as Code

3. **Security Enhancement**
   - SIEM integration
   - Threat hunting
   - Compliance automation

4. **Performance Optimization**
   - Machine learning analytics
   - Predictive maintenance
   - Auto-scaling

Este laboratório oferece uma excelente base para apresentar em entrevistas e demonstrar competências práticas em ambiente NOC!
