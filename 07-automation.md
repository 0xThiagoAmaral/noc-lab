# Automação - Laboratório NOC

## Scripts de Automação

### 1. Deployment Automático
### 2. Monitoring Automático
### 3. Backup Automático
### 4. Manutenção Automática
### 5. Reporting Automático

## Deployment Automático

### Script de Deploy Completo

```bash
#!/bin/bash
# deploy-noc-lab.sh

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/noc-deploy.log"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função de log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a $LOG_FILE
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a $LOG_FILE
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a $LOG_FILE
}

# Verificar se é executado como root
if [ "$EUID" -ne 0 ]; then
    error "Este script deve ser executado como root"
fi

log "Iniciando deploy do NOC Lab..."

# 1. Atualizar sistema
log "Atualizando sistema..."
apt update && apt upgrade -y || error "Falha ao atualizar sistema"

# 2. Instalar dependências básicas
log "Instalando dependências básicas..."
apt install -y curl wget git vim htop iotop nethogs tree unzip \
    build-essential software-properties-common apt-transport-https \
    ca-certificates gnupg lsb-release || error "Falha ao instalar dependências"

# 3. Configurar hostname
read -p "Digite o hostname para este servidor [noc-lab]: " HOSTNAME
HOSTNAME=${HOSTNAME:-noc-lab}
hostnamectl set-hostname $HOSTNAME
log "Hostname configurado: $HOSTNAME"

# 4. Configurar timezone
timedatectl set-timezone America/Sao_Paulo
log "Timezone configurado: America/Sao_Paulo"

# 5. Configurar NTP
apt install -y ntp
systemctl enable ntp
systemctl start ntp
log "NTP configurado e iniciado"

# 6. Instalar e configurar MySQL
log "Instalando MySQL..."
export DEBIAN_FRONTEND=noninteractive
apt install -y mysql-server
mysql_secure_installation
log "MySQL instalado"

# 7. Instalar Bacula
log "Instalando Bacula..."
apt install -y bacula bacula-client bacula-common-mysql
log "Bacula instalado"

# 8. Instalar Zabbix
log "Instalando Zabbix..."
wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb
dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb
apt update
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
log "Zabbix instalado"

# 9. Instalar Samba
log "Instalando Samba..."
apt install -y samba samba-common-bin
log "Samba instalado"

# 10. Instalar NFS
log "Instalando NFS..."
apt install -y nfs-kernel-server nfs-common
log "NFS instalado"

# 11. Criar estrutura de diretórios
log "Criando estrutura de diretórios..."
mkdir -p /backup/{daily,weekly,monthly}
mkdir -p /srv/{nfs,samba}/{backup,data,logs}
mkdir -p /opt/scripts
mkdir -p /var/log/noc-lab

# 12. Configurar permissões
chown -R bacula:bacula /backup
chown -R nobody:nogroup /srv/nfs
chown -R nobody:nogroup /srv/samba
chmod -R 755 /srv/nfs
chmod -R 755 /srv/samba

log "Estrutura de diretórios criada"

# 13. Configurar firewall básico
log "Configurando firewall..."
ufw --force enable
ufw allow ssh
ufw allow from 192.168.100.0/24
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 10050/tcp  # Zabbix agent
ufw allow 10051/tcp  # Zabbix server
ufw allow 9101:9103/tcp  # Bacula
ufw allow 445/tcp    # SMB
ufw allow 2049/tcp   # NFS
log "Firewall configurado"

# 14. Configurar SSH
log "Configurando SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
log "SSH configurado"

# 15. Instalar scripts de monitoramento
log "Instalando scripts de monitoramento..."
cat > /opt/scripts/system-health.sh << 'EOF'
#!/bin/bash
# system-health.sh - Verificação de saúde do sistema

HOSTNAME=$(hostname)
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# CPU
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

# Memory
MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')

# Disk
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')

# Load
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)

echo "[$DATE] $HOSTNAME - CPU: ${CPU_USAGE}%, MEM: ${MEM_USAGE}%, DISK: ${DISK_USAGE}%, LOAD: ${LOAD_AVG}"
EOF

chmod +x /opt/scripts/system-health.sh

# 16. Configurar crontab para monitoramento
log "Configurando crontab..."
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/scripts/system-health.sh >> /var/log/noc-lab/system-health.log") | crontab -

log "Deploy concluído com sucesso!"
log "Próximos passos:"
log "1. Configurar senhas dos serviços"
log "2. Configurar clientes de backup"
log "3. Testar conectividade"
log "4. Configurar monitoramento"

echo
echo "=== INFORMAÇÕES DE ACESSO ==="
echo "Hostname: $HOSTNAME"
echo "IP: $(hostname -I | awk '{print $1}')"
echo "Zabbix Web: http://$(hostname -I | awk '{print $1}')/zabbix"
echo "Logs: /var/log/noc-deploy.log"
echo "Scripts: /opt/scripts/"
```

### Script de Configuração de Clientes

```bash
#!/bin/bash
# setup-client.sh

CLIENT_TYPE=$1  # linux ou windows
CLIENT_IP=$2
CLIENT_NAME=$3

if [ -z "$CLIENT_TYPE" ] || [ -z "$CLIENT_IP" ] || [ -z "$CLIENT_NAME" ]; then
    echo "Uso: $0 <linux|windows> <IP> <nome>"
    echo "Exemplo: $0 linux 192.168.100.20 client-linux"
    exit 1
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

case $CLIENT_TYPE in
    "linux")
        log "Configurando cliente Linux: $CLIENT_NAME ($CLIENT_IP)"
        
        # SSH para o cliente e instalar Bacula client
        ssh root@$CLIENT_IP << EOF
apt update
apt install -y bacula-client zabbix-agent

# Configurar Bacula FD
cat > /etc/bacula/bacula-fd.conf << 'BACULA_FD_EOF'
Director {
  Name = backup-server-dir
  Password = "ClientPassword123"
}

FileDaemon {
  Name = ${CLIENT_NAME}-fd
  FDport = 9102
  WorkingDirectory = /var/lib/bacula
  Pid Directory = /run/bacula
  Maximum Concurrent Jobs = 20
  Plugin Directory = /usr/lib/bacula
}

Messages {
  Name = Standard
  director = backup-server-dir = all, !skipped, !restored
}
BACULA_FD_EOF

# Configurar Zabbix Agent
sed -i 's/Server=127.0.0.1/Server=192.168.100.10/' /etc/zabbix/zabbix_agentd.conf
sed -i 's/ServerActive=127.0.0.1/ServerActive=192.168.100.10/' /etc/zabbix/zabbix_agentd.conf
sed -i "s/Hostname=Zabbix server/Hostname=$CLIENT_NAME/" /etc/zabbix/zabbix_agentd.conf

# Reiniciar serviços
systemctl restart bacula-fd zabbix-agent
systemctl enable bacula-fd zabbix-agent

echo "Cliente Linux configurado com sucesso"
EOF
        ;;
        
    "windows")
        log "Configurando cliente Windows: $CLIENT_NAME ($CLIENT_IP)"
        
        # Criar script PowerShell para Windows
        cat > /tmp/setup-windows-client.ps1 << 'PS1_EOF'
# Download e instalação do Bacula Windows Client
$url = "https://www.bacula.org/packages/windows/bacula-win64-13.0.1.exe"
$output = "C:\temp\bacula-installer.exe"

New-Item -ItemType Directory -Force -Path C:\temp
Invoke-WebRequest -Uri $url -OutFile $output
Start-Process -FilePath $output -ArgumentList "/S" -Wait

# Configuração básica
$config = @"
Director {
  Name = backup-server-dir
  Password = "ClientPassword123"
}

FileDaemon {
  Name = ${CLIENT_NAME}-fd
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

$config | Out-File -FilePath "C:\Bacula\bacula-fd.conf" -Encoding ASCII

# Reiniciar serviço
Restart-Service -Name "Bacula File Daemon"
PS1_EOF

        log "Script PowerShell criado em /tmp/setup-windows-client.ps1"
        log "Execute este script no servidor Windows $CLIENT_IP"
        ;;
        
    *)
        echo "Tipo de cliente inválido. Use 'linux' ou 'windows'"
        exit 1
        ;;
esac

# Adicionar cliente ao Bacula Director
log "Adicionando cliente ao Bacula Director..."

cat >> /etc/bacula/bacula-dir.conf << EOF

# Cliente: $CLIENT_NAME
Client {
  Name = ${CLIENT_NAME}-fd
  Address = $CLIENT_IP
  FDPort = 9102
  Catalog = MyCatalog
  Password = "ClientPassword123"
  File Retention = 60 days
  Job Retention = 6 months
  AutoPrune = yes
}

Job {
  Name = "backup-${CLIENT_NAME}"
  Type = Backup
  Level = Incremental
  Client = ${CLIENT_NAME}-fd
  FileSet = "${CLIENT_TYPE^}-FS"
  Schedule = "Daily-Schedule"
  Storage = File-Storage
  Messages = Standard
  Pool = Incremental-Pool
  Full Backup Pool = Full-Pool
  Priority = 10
  Write Bootstrap = "/var/lib/bacula/%c.bsr"
}
EOF

# Reiniciar Bacula Director
systemctl restart bacula-director

log "Cliente $CLIENT_NAME configurado com sucesso!"
```

## Automação de Monitoramento

### Script de Health Check Automático

```bash
#!/bin/bash
# automated-health-check.sh

SCRIPT_DIR="/opt/scripts"
LOG_DIR="/var/log/noc-lab"
ALERT_EMAIL="admin@empresa.com"
TELEGRAM_BOT_TOKEN="SEU_BOT_TOKEN"
TELEGRAM_CHAT_ID="SEU_CHAT_ID"

# Criar diretórios se não existirem
mkdir -p $LOG_DIR

# Função de envio de alertas
send_alert() {
    local message="$1"
    local severity="$2"
    
    # Email
    echo "$message" | mail -s "NOC Alert [$severity]" $ALERT_EMAIL
    
    # Telegram
    if [ ! -z "$TELEGRAM_BOT_TOKEN" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
             -d chat_id="$TELEGRAM_CHAT_ID" \
             -d text="🚨 NOC Alert [$severity]
$message
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Server: $(hostname)"
    fi
}

# Verificações de saúde
health_checks() {
    local issues=()
    
    # 1. Verificar serviços críticos
    SERVICES=("bacula-director" "bacula-sd" "bacula-fd" "zabbix-server" "zabbix-agent" "mysql" "apache2")
    
    for service in "${SERVICES[@]}"; do
        if ! systemctl is-active --quiet $service; then
            issues+=("Service $service is DOWN")
        fi
    done
    
    # 2. Verificar uso de disco
    while read output; do
        usage=$(echo $output | awk '{print $5}' | sed 's/%//')
        partition=$(echo $output | awk '{print $6}')
        
        if [ $usage -gt 90 ]; then
            issues+=("Disk usage on $partition is ${usage}% (CRITICAL)")
        elif [ $usage -gt 80 ]; then
            issues+=("Disk usage on $partition is ${usage}% (WARNING)")
        fi
    done < <(df -h | grep -vE '^Filesystem|tmpfs|cdrom')
    
    # 3. Verificar uso de memória
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    if (( $(echo "$MEM_USAGE > 90" | bc -l) )); then
        issues+=("Memory usage is ${MEM_USAGE}% (CRITICAL)")
    elif (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
        issues+=("Memory usage is ${MEM_USAGE}% (WARNING)")
    fi
    
    # 4. Verificar load average
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
    LOAD_THRESHOLD=4  # Ajustar conforme número de CPUs
    
    if (( $(echo "$LOAD_AVG > $LOAD_THRESHOLD" | bc -l) )); then
        issues+=("Load average is $LOAD_AVG (HIGH)")
    fi
    
    # 5. Verificar conectividade com clientes
    CLIENTS=("192.168.100.20" "192.168.100.30" "192.168.100.40")
    
    for client in "${CLIENTS[@]}"; do
        if ! ping -c 1 -W 3 $client > /dev/null 2>&1; then
            issues+=("Client $client is unreachable")
        fi
    done
    
    # 6. Verificar jobs de backup recentes
    FAILED_JOBS=$(echo "SELECT COUNT(*) FROM Job WHERE JobStatus != 'T' AND StartTime > DATE_SUB(NOW(), INTERVAL 24 HOUR);" | mysql -u bacula -p bacula --skip-column-names 2>/dev/null)
    
    if [ "$FAILED_JOBS" -gt 0 ]; then
        issues+=("$FAILED_JOBS backup jobs failed in the last 24 hours")
    fi
    
    # Processar issues encontrados
    if [ ${#issues[@]} -gt 0 ]; then
        local alert_message="Health check found ${#issues[@]} issues:
"
        for issue in "${issues[@]}"; do
            alert_message+="- $issue
"
        done
        
        # Determinar severidade
        local severity="WARNING"
        for issue in "${issues[@]}"; do
            if [[ $issue == *"CRITICAL"* ]] || [[ $issue == *"DOWN"* ]]; then
                severity="CRITICAL"
                break
            fi
        done
        
        send_alert "$alert_message" "$severity"
        echo "$alert_message" >> $LOG_DIR/health-issues.log
        
        return 1
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] All health checks passed" >> $LOG_DIR/health-check.log
        return 0
    fi
}

# Executar verificações
health_checks
```

### Script de Coleta de Métricas

```bash
#!/bin/bash
# collect-metrics.sh

METRICS_DIR="/var/log/noc-lab/metrics"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

mkdir -p $METRICS_DIR

# Função para coletar métricas do sistema
collect_system_metrics() {
    local output_file="$METRICS_DIR/system_${TIMESTAMP}.json"
    
    # CPU
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # Memory
    MEM_TOTAL=$(free -b | grep Mem | awk '{print $2}')
    MEM_USED=$(free -b | grep Mem | awk '{print $3}')
    MEM_USAGE=$(echo "scale=2; $MEM_USED * 100 / $MEM_TOTAL" | bc)
    
    # Disk I/O
    DISK_READ=$(iostat -d 1 2 | tail -n +4 | awk 'END {print $3}')
    DISK_WRITE=$(iostat -d 1 2 | tail -n +4 | awk 'END {print $4}')
    
    # Network I/O
    NET_RX=$(cat /proc/net/dev | grep eth0 | awk '{print $2}')
    NET_TX=$(cat /proc/net/dev | grep eth0 | awk '{print $10}')
    
    # Load Average
    LOAD_1MIN=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | xargs)
    
    # Criar JSON
    cat > $output_file << EOF
{
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "hostname": "$(hostname)",
  "metrics": {
    "cpu": {
      "usage_percent": $CPU_USAGE
    },
    "memory": {
      "total_bytes": $MEM_TOTAL,
      "used_bytes": $MEM_USED,
      "usage_percent": $MEM_USAGE
    },
    "disk_io": {
      "read_per_sec": $DISK_READ,
      "write_per_sec": $DISK_WRITE
    },
    "network": {
      "rx_bytes": $NET_RX,
      "tx_bytes": $NET_TX
    },
    "load": {
      "avg_1min": $LOAD_1MIN
    }
  }
}
EOF

    echo "System metrics collected: $output_file"
}

# Função para coletar métricas de backup
collect_backup_metrics() {
    local output_file="$METRICS_DIR/backup_${TIMESTAMP}.json"
    
    # Status dos últimos jobs
    SUCCESSFUL_JOBS=$(echo "SELECT COUNT(*) FROM Job WHERE JobStatus = 'T' AND StartTime > DATE_SUB(NOW(), INTERVAL 24 HOUR);" | mysql -u bacula -p bacula --skip-column-names 2>/dev/null)
    FAILED_JOBS=$(echo "SELECT COUNT(*) FROM Job WHERE JobStatus != 'T' AND StartTime > DATE_SUB(NOW(), INTERVAL 24 HOUR);" | mysql -u bacula -p bacula --skip-column-names 2>/dev/null)
    
    # Tamanho total dos backups
    BACKUP_SIZE=$(du -sb /backup | awk '{print $1}')
    
    # Número de volumes
    VOLUME_COUNT=$(echo "SELECT COUNT(*) FROM Media;" | mysql -u bacula -p bacula --skip-column-names 2>/dev/null)
    
    cat > $output_file << EOF
{
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "backup_metrics": {
    "jobs_24h": {
      "successful": $SUCCESSFUL_JOBS,
      "failed": $FAILED_JOBS
    },
    "storage": {
      "total_size_bytes": $BACKUP_SIZE,
      "volume_count": $VOLUME_COUNT
    }
  }
}
EOF

    echo "Backup metrics collected: $output_file"
}

# Função para coletar métricas de rede
collect_network_metrics() {
    local output_file="$METRICS_DIR/network_${TIMESTAMP}.json"
    
    # Conectividade com hosts
    HOSTS=("192.168.100.20" "192.168.100.30" "192.168.100.40")
    
    cat > $output_file << EOF
{
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')",
  "network_metrics": {
    "connectivity": [
EOF

    first=true
    for host in "${HOSTS[@]}"; do
        if [ "$first" = false ]; then
            echo "," >> $output_file
        fi
        first=false
        
        if ping -c 1 -W 3 $host > /dev/null 2>&1; then
            status="up"
            # Medir latência
            latency=$(ping -c 3 $host | tail -1 | awk -F'/' '{print $5}')
        else
            status="down"
            latency="null"
        fi
        
        cat >> $output_file << EOF
      {
        "host": "$host",
        "status": "$status",
        "latency_ms": $latency
      }
EOF
    done
    
    cat >> $output_file << EOF
    ]
  }
}
EOF

    echo "Network metrics collected: $output_file"
}

# Executar coletas
collect_system_metrics
collect_backup_metrics
collect_network_metrics

# Limpeza de arquivos antigos (manter apenas 7 dias)
find $METRICS_DIR -name "*.json" -mtime +7 -delete

echo "Metrics collection completed at $(date)"
```

## Automação de Relatórios

### Gerador de Relatórios

```bash
#!/bin/bash
# generate-reports.sh

REPORT_TYPE=$1
OUTPUT_DIR="/var/reports"
DATE=$(date '+%Y-%m-%d')

mkdir -p $OUTPUT_DIR

case $REPORT_TYPE in
    "daily")
        REPORT_FILE="$OUTPUT_DIR/daily-report-$DATE.html"
        
        cat > $REPORT_FILE << EOF
<!DOCTYPE html>
<html>
<head>
    <title>NOC Daily Report - $DATE</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f4f4f4; padding: 10px; border-radius: 5px; }
        .section { margin: 20px 0; }
        .good { color: green; }
        .warning { color: orange; }
        .critical { color: red; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>NOC Daily Report</h1>
        <p>Data: $DATE | Servidor: $(hostname) | IP: $(hostname -I | awk '{print $1}')</p>
    </div>
    
    <div class="section">
        <h2>Resumo Executivo</h2>
        <ul>
            <li><strong>Uptime:</strong> $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')</li>
            <li><strong>Load Average:</strong> $(uptime | awk -F'load average:' '{print $2}')</li>
            <li><strong>Uso de Memória:</strong> $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')</li>
            <li><strong>Uso de Disco (/):</strong> $(df -h / | awk 'NR==2 {print $5}')</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Status dos Serviços</h2>
        <table>
            <tr><th>Serviço</th><th>Status</th></tr>
EOF

        # Adicionar status dos serviços
        SERVICES=("bacula-director" "bacula-sd" "bacula-fd" "zabbix-server" "mysql" "apache2")
        for service in "${SERVICES[@]}"; do
            if systemctl is-active --quiet $service; then
                status="<span class='good'>RUNNING</span>"
            else
                status="<span class='critical'>STOPPED</span>"
            fi
            echo "            <tr><td>$service</td><td>$status</td></tr>" >> $REPORT_FILE
        done
        
        cat >> $REPORT_FILE << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Jobs de Backup (Últimas 24h)</h2>
        <table>
            <tr><th>Job Name</th><th>Status</th><th>Start Time</th><th>End Time</th><th>Files</th><th>Bytes</th></tr>
EOF

        # Adicionar jobs de backup
        echo "SELECT Name, JobStatus, StartTime, EndTime, JobFiles, JobBytes FROM Job WHERE StartTime > DATE_SUB(NOW(), INTERVAL 24 HOUR) ORDER BY StartTime DESC;" | mysql -u bacula -p bacula --skip-column-names 2>/dev/null | while read job; do
            echo "            <tr><td>$(echo $job | awk '{print $1}')</td><td>$(echo $job | awk '{print $2}')</td><td>$(echo $job | awk '{print $3 " " $4}')</td><td>$(echo $job | awk '{print $5 " " $6}')</td><td>$(echo $job | awk '{print $7}')</td><td>$(echo $job | awk '{print $8}')</td></tr>" >> $REPORT_FILE
        done
        
        cat >> $REPORT_FILE << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Conectividade de Rede</h2>
        <table>
            <tr><th>Host</th><th>Status</th><th>Latência</th></tr>
EOF

        # Teste de conectividade
        HOSTS=("192.168.100.20" "192.168.100.30" "192.168.100.40")
        for host in "${HOSTS[@]}"; do
            if ping -c 1 -W 3 $host > /dev/null 2>&1; then
                status="<span class='good'>UP</span>"
                latency=$(ping -c 3 $host | tail -1 | awk -F'/' '{print $5}' 2>/dev/null || echo "N/A")
            else
                status="<span class='critical'>DOWN</span>"
                latency="N/A"
            fi
            echo "            <tr><td>$host</td><td>$status</td><td>${latency}ms</td></tr>" >> $REPORT_FILE
        done
        
        cat >> $REPORT_FILE << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Uso de Recursos</h2>
        <h3>Espaço em Disco</h3>
        <table>
            <tr><th>Filesystem</th><th>Size</th><th>Used</th><th>Available</th><th>Use%</th><th>Mounted on</th></tr>
EOF

        df -h | grep -vE '^Filesystem|tmpfs|cdrom' | while read output; do
            echo "            <tr><td>$(echo $output | awk '{print $1}')</td><td>$(echo $output | awk '{print $2}')</td><td>$(echo $output | awk '{print $3}')</td><td>$(echo $output | awk '{print $4}')</td><td>$(echo $output | awk '{print $5}')</td><td>$(echo $output | awk '{print $6}')</td></tr>" >> $REPORT_FILE
        done
        
        cat >> $REPORT_FILE << EOF
        </table>
    </div>
    
    <div class="section">
        <h2>Top 10 Processos (CPU)</h2>
        <table>
            <tr><th>PID</th><th>User</th><th>CPU%</th><th>Memory%</th><th>Command</th></tr>
EOF

        ps aux --sort=-%cpu | head -11 | tail -10 | while read process; do
            echo "            <tr><td>$(echo $process | awk '{print $2}')</td><td>$(echo $process | awk '{print $1}')</td><td>$(echo $process | awk '{print $3}')</td><td>$(echo $process | awk '{print $4}')</td><td>$(echo $process | awk '{print $11}')</td></tr>" >> $REPORT_FILE
        done
        
        cat >> $REPORT_FILE << EOF
        </table>
    </div>
    
    <footer style="margin-top: 50px; text-align: center; color: #666;">
        <p>Relatório gerado automaticamente em $(date '+%Y-%m-%d %H:%M:%S')</p>
    </footer>
</body>
</html>
EOF

        echo "Relatório diário gerado: $REPORT_FILE"
        
        # Enviar por email
        echo "Relatório diário NOC em anexo" | mail -s "NOC Daily Report - $DATE" -A $REPORT_FILE admin@empresa.com
        ;;
        
    "weekly")
        echo "Gerando relatório semanal..."
        # Implementar relatório semanal
        ;;
        
    "monthly")
        echo "Gerando relatório mensal..."
        # Implementar relatório mensal
        ;;
        
    *)
        echo "Uso: $0 {daily|weekly|monthly}"
        exit 1
        ;;
esac
```

## Configuração de Crontab Completa

```bash
#!/bin/bash
# setup-cron-jobs.sh

echo "Configurando jobs do cron para automação NOC..."

# Backup do crontab atual
crontab -l > /tmp/crontab.backup 2>/dev/null

# Criar novo crontab
cat > /tmp/noc-crontab << EOF
# NOC Lab - Jobs de Automação

# Coleta de métricas a cada 5 minutos
*/5 * * * * /opt/scripts/collect-metrics.sh

# Health check a cada 10 minutos
*/10 * * * * /opt/scripts/automated-health-check.sh

# Backup automático diário às 2:00
0 2 * * * /opt/scripts/automated-backup.sh

# Relatório diário às 6:00
0 6 * * * /opt/scripts/generate-reports.sh daily

# Relatório semanal aos domingos às 7:00
0 7 * * 0 /opt/scripts/generate-reports.sh weekly

# Limpeza de logs antigos às 3:00 todos os domingos
0 3 * * 0 /opt/scripts/cleanup-logs.sh

# Verificação de segurança diária às 4:00
0 4 * * * /opt/scripts/security-check.sh

# Atualização de sistema aos domingos às 5:00
0 5 * * 0 /opt/scripts/system-update.sh

# Teste de conectividade a cada hora
0 * * * * /opt/scripts/connectivity-test.sh

# Monitoramento de performance a cada 15 minutos
*/15 * * * * /opt/scripts/performance-monitor.sh
EOF

# Aplicar novo crontab
crontab /tmp/noc-crontab

echo "Crontab configurado com sucesso!"
echo "Para verificar: crontab -l"
```

## Próximos Passos

1. Implementar CI/CD pipeline
2. Criar templates Ansible/Terraform
3. Integrar com Docker/Kubernetes
4. Implementar GitOps workflow
5. Desenvolver API para automação
