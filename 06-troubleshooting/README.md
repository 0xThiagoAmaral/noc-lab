# Troubleshooting - Laboratório NOC

## Cenários Práticos de Troubleshooting

### 1. Falhas de Backup
### 2. Problemas de Conectividade
### 3. Issues de Performance
### 4. Falhas de Storage
### 5. Problemas de Autenticação

## Cenário 1: Backup Job Failed

### Sintomas
- Jobs de backup falham com erro
- Alertas do Zabbix indicando falha
- Logs mostram erros de conectividade

### Diagnóstico

```bash
#!/bin/bash
# diagnose-backup-failure.sh

echo "=== DIAGNÓSTICO DE FALHA DE BACKUP ==="
echo "Data: $(date)"
echo

# 1. Verificar status dos serviços Bacula
echo "1. Status dos Serviços Bacula:"
services=("bacula-director" "bacula-sd" "bacula-fd")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "  ✓ $service: RUNNING"
    else
        echo "  ✗ $service: STOPPED"
        echo "    Tentando reiniciar..."
        sudo systemctl restart $service
        sleep 2
        if systemctl is-active --quiet $service; then
            echo "    ✓ $service: REINICIADO COM SUCESSO"
        else
            echo "    ✗ $service: FALHA AO REINICIAR"
        fi
    fi
done

echo

# 2. Verificar conectividade com clientes
echo "2. Conectividade com Clientes:"
clients=("192.168.100.20:9102" "192.168.100.30:9102")
for client in "${clients[@]}"; do
    ip=${client%:*}
    port=${client#*:}
    
    if timeout 5 bash -c "</dev/tcp/$ip/$port" 2>/dev/null; then
        echo "  ✓ $client: CONECTADO"
    else
        echo "  ✗ $client: FALHA DE CONEXÃO"
    fi
done

echo

# 3. Verificar espaço em disco
echo "3. Espaço em Disco:"
df -h /backup | awk 'NR==2 {
    if ($5+0 > 90) 
        print "  ✗ Uso do disco: " $5 " (CRÍTICO)"
    else if ($5+0 > 80)
        print "  ! Uso do disco: " $5 " (ATENÇÃO)"
    else
        print "  ✓ Uso do disco: " $5 " (OK)"
}'

echo

# 4. Verificar últimos jobs
echo "4. Últimos Jobs de Backup:"
echo "SELECT JobId, Name, JobStatus, StartTime, EndTime FROM Job ORDER BY JobId DESC LIMIT 5;" | mysql -u bacula -p bacula --skip-column-names | while read job; do
    echo "  $job"
done

echo

# 5. Verificar logs de erro
echo "5. Erros Recentes nos Logs:"
tail -20 /var/log/bacula/bacula.log | grep -i error

echo
echo "=== FIM DO DIAGNÓSTICO ==="
```

### Soluções Comuns

```bash
#!/bin/bash
# fix-backup-issues.sh

ISSUE_TYPE=$1

case $ISSUE_TYPE in
    "disk-full")
        echo "Resolvendo problema de disco cheio..."
        
        # Limpar backups antigos
        find /backup -name "*.bsr" -mtime +30 -delete
        find /backup -name "*-Vol-*" -mtime +60 -delete
        
        # Compactar logs antigos
        find /var/log/bacula -name "*.log" -mtime +7 -exec gzip {} \;
        
        echo "Limpeza concluída. Espaço liberado:"
        df -h /backup
        ;;
        
    "client-unreachable")
        echo "Diagnosticando problemas de conectividade..."
        
        # Verificar firewall
        sudo ufw status | grep 9102
        
        # Testar conectividade
        for client in 192.168.100.20 192.168.100.30; do
            echo "Testando $client..."
            ping -c 3 $client
            telnet $client 9102
        done
        ;;
        
    "service-down")
        echo "Reiniciando serviços Bacula..."
        
        sudo systemctl stop bacula-director bacula-sd bacula-fd
        sleep 5
        sudo systemctl start bacula-director bacula-sd bacula-fd
        
        # Verificar status
        systemctl status bacula-director bacula-sd bacula-fd
        ;;
        
    "permissions")
        echo "Corrigindo permissões..."
        
        sudo chown -R bacula:bacula /var/lib/bacula
        sudo chown -R bacula:bacula /backup
        sudo chmod -R 755 /backup
        ;;
        
    *)
        echo "Uso: $0 {disk-full|client-unreachable|service-down|permissions}"
        exit 1
        ;;
esac
```

## Cenário 2: Network Connectivity Issues

### Sintomas
- Timeouts de conexão
- Montagens de rede falhando
- Transferências lentas ou interrompidas

### Diagnóstico de Rede

```bash
#!/bin/bash
# network-diagnosis.sh

TARGET_HOST=$1

if [ -z "$TARGET_HOST" ]; then
    echo "Uso: $0 <IP_do_host>"
    exit 1
fi

echo "=== DIAGNÓSTICO DE CONECTIVIDADE: $TARGET_HOST ==="
echo

# 1. Teste básico de conectividade
echo "1. Teste de Ping:"
if ping -c 4 -W 3 $TARGET_HOST > /dev/null 2>&1; then
    echo "  ✓ Host está respondendo ao ping"
    
    # Estatísticas detalhadas
    ping -c 10 $TARGET_HOST | tail -2
else
    echo "  ✗ Host não responde ao ping"
    echo "  Verificando rota..."
    traceroute $TARGET_HOST
fi

echo

# 2. Teste de portas específicas
echo "2. Teste de Portas:"
ports=("22:SSH" "445:SMB" "2049:NFS" "21:FTP" "9101:Bacula-Dir" "9102:Bacula-FD")

for port_info in "${ports[@]}"; do
    port=${port_info%:*}
    service=${port_info#*:}
    
    if timeout 5 bash -c "</dev/tcp/$TARGET_HOST/$port" 2>/dev/null; then
        echo "  ✓ $service (porta $port): ABERTA"
    else
        echo "  ✗ $service (porta $port): FECHADA/FILTRADA"
    fi
done

echo

# 3. Análise de DNS
echo "3. Resolução DNS:"
if host $TARGET_HOST > /dev/null 2>&1; then
    echo "  ✓ DNS está resolvendo corretamente"
    host $TARGET_HOST
else
    echo "  ! DNS não está resolvendo (usando IP direto)"
fi

echo

# 4. Análise de MTU
echo "4. Teste de MTU:"
for size in 1500 1472 1464; do
    if ping -c 1 -M do -s $size $TARGET_HOST > /dev/null 2>&1; then
        echo "  ✓ MTU $size: OK"
        break
    else
        echo "  ! MTU $size: Fragmentação necessária"
    fi
done

echo

# 5. Verificar ARP
echo "5. Tabela ARP:"
arp -a | grep $TARGET_HOST

echo

# 6. Estatísticas de rede
echo "6. Estatísticas de Interface:"
ip -s link show | grep -A 5 "state UP"
```

### Soluções de Conectividade

```bash
#!/bin/bash
# fix-connectivity.sh

PROBLEM_TYPE=$1
TARGET_HOST=$2

case $PROBLEM_TYPE in
    "dns")
        echo "Corrigindo problemas de DNS..."
        
        # Flush DNS cache
        sudo systemctl flush-dns
        
        # Verificar /etc/hosts
        echo "Verificando /etc/hosts para $TARGET_HOST..."
        grep $TARGET_HOST /etc/hosts
        
        # Testar servidores DNS
        for dns in 8.8.8.8 1.1.1.1; do
            echo "Testando DNS $dns..."
            nslookup $TARGET_HOST $dns
        done
        ;;
        
    "firewall")
        echo "Verificando configurações de firewall..."
        
        # Status do UFW
        sudo ufw status verbose
        
        # Verificar iptables
        sudo iptables -L -n
        
        # Sugerir regras
        echo "Para permitir tráfego de backup, execute:"
        echo "sudo ufw allow from 192.168.100.0/24"
        echo "sudo ufw allow 9101:9103/tcp"
        ;;
        
    "routing")
        echo "Verificando rotas de rede..."
        
        # Mostrar tabela de rotas
        ip route show
        
        # Verificar gateway padrão
        ip route show default
        
        # Teste de traceroute
        traceroute $TARGET_HOST
        ;;
        
    "mtu")
        echo "Corrigindo problemas de MTU..."
        
        # Descobrir MTU ótimo
        for interface in $(ip link show | grep "state UP" | awk -F: '{print $2}' | tr -d ' '); do
            echo "Interface $interface:"
            ip link show $interface | grep mtu
        done
        
        echo "Para ajustar MTU: sudo ip link set dev eth0 mtu 1450"
        ;;
        
    *)
        echo "Uso: $0 {dns|firewall|routing|mtu} [target_host]"
        exit 1
        ;;
esac
```

## Cenário 3: Performance Issues

### Diagnóstico de Performance

```bash
#!/bin/bash
# performance-analysis.sh

echo "=== ANÁLISE DE PERFORMANCE DO SISTEMA ==="
echo "Data: $(date)"
echo

# 1. CPU Usage
echo "1. Uso de CPU:"
top -bn1 | grep "Cpu(s)" | awk '{print "  CPU Usage: " $2 " user, " $4 " system, " $8 " idle"}'

# Top 5 processos por CPU
echo "  Top 5 processos por CPU:"
ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "    %s: %.1f%%\n", $11, $3}'

echo

# 2. Memory Usage
echo "2. Uso de Memória:"
free -h | awk 'NR==2{printf "  Usado: %s/%s (%.1f%%)\n", $3, $2, $3*100/$2}'

# Top 5 processos por memória
echo "  Top 5 processos por memória:"
ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf "    %s: %.1f%%\n", $11, $4}'

echo

# 3. Disk I/O
echo "3. I/O de Disco:"
iostat -x 1 2 | tail -n +4 | awk 'NF>0 && $1!="Device" {
    if ($1 != "avg-cpu:") 
        printf "  %s: %s%% utilization, %.1f r/s, %.1f w/s\n", $1, $10, $4, $5
}'

echo

# 4. Network I/O
echo "4. I/O de Rede:"
for interface in $(ip link show | grep "state UP" | awk -F: '{print $2}' | tr -d ' '); do
    rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes)
    tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes)
    echo "  $interface: RX $(numfmt --to=iec $rx_bytes), TX $(numfmt --to=iec $tx_bytes)"
done

echo

# 5. Load Average
echo "5. Load Average:"
uptime | awk -F'load average:' '{print "  " $2}'

echo

# 6. Disk Space
echo "6. Espaço em Disco:"
df -h | grep -E "^/dev/" | awk '{printf "  %s: %s usado de %s (%s)\n", $6, $3, $2, $5}'
```

### Otimização de Performance

```bash
#!/bin/bash
# optimize-performance.sh

COMPONENT=$1

case $COMPONENT in
    "backup")
        echo "Otimizando performance de backup..."
        
        # Ajustar configurações do Bacula
        sudo tee -a /etc/bacula/bacula-sd.conf << EOF

# Otimizações de performance
Device {
  Name = FileStorage
  Media Type = File
  Archive Device = /backup
  LabelMedia = yes
  Random Access = Yes
  AutomaticMount = yes
  RemovableMedia = no
  AlwaysOpen = no
  Maximum Concurrent Jobs = 10
  Spool Directory = /tmp
  Maximum Spool Size = 5GB
  Maximum Network Buffer Size = 65536
}
EOF

        echo "Configurações de performance aplicadas ao Bacula"
        ;;
        
    "network")
        echo "Otimizando performance de rede..."
        
        # Ajustar buffers de rede
        sudo tee -a /etc/sysctl.conf << EOF

# Otimizações de rede
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_congestion_control = bbr
EOF

        sudo sysctl -p
        echo "Otimizações de rede aplicadas"
        ;;
        
    "disk")
        echo "Otimizando performance de disco..."
        
        # Verificar scheduler de I/O
        for disk in $(lsblk -dno NAME | grep -E "^(sd|nvme)"); do
            current_scheduler=$(cat /sys/block/$disk/queue/scheduler)
            echo "Disk $disk scheduler: $current_scheduler"
            
            # Sugerir mq-deadline para SSDs, cfq para HDDs
            echo "Para SSD: echo mq-deadline > /sys/block/$disk/queue/scheduler"
            echo "Para HDD: echo cfq > /sys/block/$disk/queue/scheduler"
        done
        ;;
        
    "memory")
        echo "Otimizando uso de memória..."
        
        # Ajustar swappiness
        echo "vm.swappiness = 10" | sudo tee -a /etc/sysctl.conf
        
        # Cache settings
        echo "vm.vfs_cache_pressure = 50" | sudo tee -a /etc/sysctl.conf
        
        sudo sysctl -p
        echo "Otimizações de memória aplicadas"
        ;;
        
    *)
        echo "Uso: $0 {backup|network|disk|memory}"
        exit 1
        ;;
esac
```

## Cenário 4: Storage Issues

### Diagnóstico de Storage

```bash
#!/bin/bash
# storage-diagnosis.sh

echo "=== DIAGNÓSTICO DE STORAGE ==="
echo

# 1. Espaço em disco
echo "1. Uso de Espaço:"
df -h | grep -E "(backup|storage)" | awk '{
    usage = $5 + 0
    if (usage > 90) 
        print "  ⚠️  " $0 " (CRÍTICO)"
    else if (usage > 80)
        print "  ⚠️  " $0 " (ATENÇÃO)"
    else
        print "  ✓ " $0 " (OK)"
}'

echo

# 2. Inodes
echo "2. Uso de Inodes:"
df -i | grep -E "(backup|storage)" | awk '{
    usage = $5 + 0
    if (usage > 90)
        print "  ⚠️  " $0 " (CRÍTICO)"
    else
        print "  ✓ " $0 " (OK)"
}'

echo

# 3. Verificar montagens
echo "3. Pontos de Montagem:"
mount | grep -E "(nfs|cifs|fuse)" | while read mount_info; do
    echo "  $mount_info"
done

echo

# 4. Teste de I/O
echo "4. Teste de Performance de I/O:"
for mount_point in /backup /srv/nfs /srv/samba; do
    if [ -d "$mount_point" ]; then
        echo "  Testando $mount_point..."
        
        # Teste de escrita
        write_speed=$(dd if=/dev/zero of=$mount_point/test_write bs=1M count=100 2>&1 | grep "MB/s" | awk '{print $8 " " $9}')
        echo "    Escrita: $write_speed"
        
        # Teste de leitura
        read_speed=$(dd if=$mount_point/test_write of=/dev/null bs=1M 2>&1 | grep "MB/s" | awk '{print $8 " " $9}')
        echo "    Leitura: $read_speed"
        
        # Limpeza
        rm -f $mount_point/test_write
    fi
done

echo

# 5. Verificar erros de hardware
echo "5. Erros de Hardware:"
dmesg | grep -i "error\|fail" | grep -E "(disk|storage|mount)" | tail -5
```

### Correção de Problemas de Storage

```bash
#!/bin/bash
# fix-storage-issues.sh

ISSUE_TYPE=$1

case $ISSUE_TYPE in
    "cleanup")
        echo "Executando limpeza de storage..."
        
        # Limpar arquivos temporários
        find /tmp -type f -mtime +7 -delete 2>/dev/null
        
        # Limpar logs antigos
        journalctl --vacuum-time=30d
        
        # Limpar cache de pacotes
        sudo apt-get clean
        
        # Limpar backups antigos
        find /backup -name "*.bsr" -mtime +30 -delete
        find /backup -name "*-Vol-*" -mtime +90 -delete
        
        echo "Limpeza concluída"
        df -h
        ;;
        
    "remount")
        echo "Remontando sistemas de arquivos..."
        
        # Remontar NFS
        for mount_point in $(mount | grep nfs | awk '{print $3}'); do
            echo "Remontando $mount_point..."
            sudo umount $mount_point
            sleep 2
            sudo mount $mount_point
        done
        
        # Remontar CIFS
        for mount_point in $(mount | grep cifs | awk '{print $3}'); do
            echo "Remontando $mount_point..."
            sudo umount $mount_point
            sleep 2
            sudo mount $mount_point
        done
        ;;
        
    "fsck")
        echo "Verificando sistemas de arquivos..."
        echo "ATENÇÃO: Esta operação deve ser feita com sistemas desmontados!"
        
        # Listar sistemas de arquivos para verificação
        lsblk -f | grep -E "ext[234]|xfs" | while read line; do
            device=$(echo $line | awk '{print $1}')
            echo "Para verificar $device: sudo fsck -f /dev/$device"
        done
        ;;
        
    "expand")
        echo "Expandindo storage..."
        
        # Verificar LVM
        if command -v lvs > /dev/null; then
            echo "Volumes LVM disponíveis:"
            sudo lvs
            echo "Para expandir: sudo lvextend -L +10G /dev/vg/lv && sudo resize2fs /dev/vg/lv"
        fi
        
        # Verificar partições
        echo "Partições disponíveis:"
        lsblk
        ;;
        
    *)
        echo "Uso: $0 {cleanup|remount|fsck|expand}"
        exit 1
        ;;
esac
```

## Cenário 5: Authentication Problems

### Diagnóstico de Autenticação

```bash
#!/bin/bash
# auth-diagnosis.sh

SERVICE=$1

case $SERVICE in
    "samba")
        echo "=== DIAGNÓSTICO DE AUTENTICAÇÃO SAMBA ==="
        
        # Verificar usuários Samba
        echo "1. Usuários Samba:"
        sudo pdbedit -L
        
        echo
        echo "2. Configuração Samba:"
        testparm -s | grep -A 10 -B 5 "security\|auth"
        
        echo
        echo "3. Logs de autenticação:"
        tail -20 /var/log/samba/log.smbd | grep -i auth
        ;;
        
    "nfs")
        echo "=== DIAGNÓSTICO DE AUTENTICAÇÃO NFS ==="
        
        # Verificar exports
        echo "1. Exports ativos:"
        showmount -e localhost
        
        echo
        echo "2. Permissões de export:"
        cat /etc/exports
        
        echo
        echo "3. Clientes conectados:"
        showmount -a localhost
        ;;
        
    "bacula")
        echo "=== DIAGNÓSTICO DE AUTENTICAÇÃO BACULA ==="
        
        # Verificar configuração de passwords
        echo "1. Configuração de senhas (Bacula):"
        grep -n "Password" /etc/bacula/bacula-*.conf
        
        echo
        echo "2. Status de conexão com clientes:"
        echo "status client" | bconsole
        ;;
        
    *)
        echo "Uso: $0 {samba|nfs|bacula}"
        exit 1
        ;;
esac
```

## Scripts de Recovery Automático

### Recovery Automático

```bash
#!/bin/bash
# auto-recovery.sh

LOG_FILE="/var/log/auto-recovery.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# 1. Verificar serviços críticos
CRITICAL_SERVICES=("bacula-director" "bacula-sd" "smbd" "nfs-kernel-server")

for service in "${CRITICAL_SERVICES[@]}"; do
    if ! systemctl is-active --quiet $service; then
        log "RECOVERY: Serviço $service está parado, tentando reiniciar..."
        sudo systemctl restart $service
        
        sleep 5
        
        if systemctl is-active --quiet $service; then
            log "RECOVERY: Serviço $service reiniciado com sucesso"
        else
            log "ERROR: Falha ao reiniciar $service"
            # Enviar alerta
            echo "Falha crítica no serviço $service em $(hostname)" | mail -s "CRITICAL: Service Failure" admin@empresa.com
        fi
    fi
done

# 2. Verificar espaço em disco
DISK_USAGE=$(df /backup | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
    log "RECOVERY: Disk usage crítico ($DISK_USAGE%), executando limpeza..."
    
    # Limpeza automática
    find /backup -name "*.bsr" -mtime +7 -delete
    find /tmp -type f -mtime +1 -delete
    
    # Verificar novamente
    NEW_USAGE=$(df /backup | awk 'NR==2 {print $5}' | sed 's/%//')
    log "RECOVERY: Uso de disco após limpeza: $NEW_USAGE%"
fi

# 3. Verificar conectividade de rede
CRITICAL_HOSTS=("192.168.100.20" "192.168.100.30" "192.168.100.40")

for host in "${CRITICAL_HOSTS[@]}"; do
    if ! ping -c 3 -W 3 $host > /dev/null 2>&1; then
        log "WARNING: Host $host não está respondendo"
        
        # Tentar flush de ARP
        sudo ip neigh flush dev eth0
        
        # Tentar novamente
        if ping -c 3 -W 3 $host > /dev/null 2>&1; then
            log "RECOVERY: Conectividade com $host restaurada"
        else
            log "ERROR: Host $host permanece inacessível"
        fi
    fi
done

log "Auto-recovery check completed"
```

## Documentação de Runbooks

### Runbook Template

```markdown
# RUNBOOK: [Nome do Problema]

## Descrição
Breve descrição do problema e impacto nos serviços.

## Sintomas
- Lista dos sintomas observados
- Alertas relacionados
- Comportamentos anômalos

## Diagnóstico Rápido
```bash
# Comandos para diagnóstico inicial
systemctl status service-name
journalctl -u service-name --since "10 minutes ago"
```

## Resolução
### Passo 1: [Descrição]
```bash
# Comandos específicos
```

### Passo 2: [Descrição]
```bash
# Comandos específicos
```

## Verificação
Como confirmar que o problema foi resolvido.

## Prevenção
Medidas para evitar reocorrência.

## Escalação
Quando e para quem escalar se não resolver.
```

## Próximos Passos

1. Implementar machine learning para detecção de anomalias
2. Criar dashboards de troubleshooting em tempo real
3. Automatizar mais cenários de recovery
4. Integrar com ferramentas de ITSM
5. Desenvolver chatbot para troubleshooting básico
