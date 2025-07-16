# Monitoramento - Laboratório NOC

## Ferramentas Implementadas

### 1. Zabbix 6.4
### 2. Nagios Core
### 3. Grafana + Prometheus
### 4. Scripts Customizados

## Zabbix Server - Instalação e Configuração

### Instalação no Ubuntu 22.04

```bash
#!/bin/bash
# install-zabbix.sh

# Adicionar repositório oficial
wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb
sudo dpkg -i zabbix-release_6.4-1+ubuntu22.04_all.deb
sudo apt update

# Instalar Zabbix Server, Frontend e Agent
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

# Instalar MySQL
sudo apt install -y mysql-server

# Configurar banco de dados
sudo mysql -uroot -p
```

### Configuração do Banco de Dados

```sql
-- Comandos MySQL para Zabbix
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'ZabbixDBPass123';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EXIT;
```

```bash
# Importar schema inicial
sudo zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p zabbix

# Desabilitar log_bin_trust_function_creators
sudo mysql -uroot -p -e "SET GLOBAL log_bin_trust_function_creators = 0;"
```

### Configuração do Zabbix Server

```bash
# /etc/zabbix/zabbix_server.conf

LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=10
PidFile=/run/zabbix/zabbix_server.pid

DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=ZabbixDBPass123
DBSocket=/var/run/mysqld/mysqld.sock

StartPollers=5
StartPingers=1
StartTrappers=5
StartHTTPPollers=1
StartPreprocessors=3
StartTimers=1
StartEscalators=1

CacheSize=32M
HistoryCacheSize=64M
HistoryIndexCacheSize=16M
TrendCacheSize=4M
ValueCacheSize=64M

Timeout=4
TrapperTimeout=300
UnreachablePeriod=45
UnavailableDelay=60
UnreachableDelay=15

AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts

LogSlowQueries=3000
StatsAllowedIP=127.0.0.1
```

### Configuração do Apache

```bash
# /etc/zabbix/apache.conf
# Ajustar timezone
sudo sed -i 's/# php_value date.timezone Europe\/Riga/php_value date.timezone America\/Sao_Paulo/' /etc/zabbix/apache.conf

# Reiniciar serviços
sudo systemctl restart zabbix-server zabbix-agent apache2
sudo systemctl enable zabbix-server zabbix-agent apache2
```

## Templates Customizados

### Template para Backup Monitoring

```xml
<?xml version="1.0" encoding="UTF-8"?>
<zabbix_export>
    <version>6.4</version>
    <template_groups>
        <template_group>
            <uuid>backup-templates</uuid>
            <name>Backup Templates</name>
        </template_group>
    </template_groups>
    <templates>
        <template>
            <uuid>backup-monitoring</uuid>
            <template>Backup Monitoring</template>
            <name>Backup Monitoring</name>
            <groups>
                <group>
                    <name>Backup Templates</name>
                </group>
            </groups>
            <items>
                <item>
                    <uuid>backup-job-status</uuid>
                    <name>Backup Job Status</name>
                    <type>EXTERNAL</type>
                    <key>check_backup_status.sh</key>
                    <delay>300s</delay>
                    <value_type>UNSIGNED</value_type>
                    <description>Verifica o status do último job de backup</description>
                </item>
                <item>
                    <uuid>backup-disk-usage</uuid>
                    <name>Backup Disk Usage</name>
                    <type>ZABBIX_AGENT</type>
                    <key>vfs.fs.size[/backup,pused]</key>
                    <delay>300s</delay>
                    <value_type>FLOAT</value_type>
                    <units>%</units>
                    <description>Uso do disco de backup em percentual</description>
                </item>
            </items>
            <triggers>
                <trigger>
                    <uuid>backup-failed-trigger</uuid>
                    <expression>last(/Backup Monitoring/check_backup_status.sh)=0</expression>
                    <name>Backup Job Failed</name>
                    <priority>HIGH</priority>
                    <description>O último job de backup falhou</description>
                </trigger>
                <trigger>
                    <uuid>backup-disk-full-trigger</uuid>
                    <expression>last(/Backup Monitoring/vfs.fs.size[/backup,pused])>90</expression>
                    <name>Backup Disk Almost Full</name>
                    <priority>WARNING</priority>
                    <description>Disco de backup com mais de 90% de uso</description>
                </trigger>
            </triggers>
        </template>
    </templates>
</zabbix_export>
```

### Script de Verificação Externa

```bash
#!/bin/bash
# /usr/lib/zabbix/externalscripts/check_backup_status.sh

# Verificar status do último job do Bacula
LAST_JOB_STATUS=$(echo "SELECT JobStatus FROM Job ORDER BY JobId DESC LIMIT 1;" | mysql -u zabbix -p'ZabbixDBPass123' bacula -s --skip-column-names)

case $LAST_JOB_STATUS in
    "T")
        echo 1  # Sucesso
        ;;
    "E")
        echo 0  # Erro
        ;;
    "f")
        echo 0  # Fatal error
        ;;
    "A")
        echo 0  # Cancelado
        ;;
    *)
        echo 2  # Status desconhecido
        ;;
esac
```

## Nagios Core - Configuração Complementar

### Instalação

```bash
#!/bin/bash
# install-nagios.sh

# Instalar dependências
sudo apt update
sudo apt install -y autoconf gcc libc6 make wget unzip apache2 php libapache2-mod-php7.4 libgd-dev

# Criar usuário nagios
sudo useradd nagios
sudo groupadd nagcmd
sudo usermod -a -G nagcmd nagios
sudo usermod -a -G nagcmd www-data

# Download e compilação do Nagios
cd /tmp
wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.4.6.tar.gz
tar xzf nagios-4.4.6.tar.gz
cd nagios-4.4.6

./configure --with-command-group=nagcmd
make all
sudo make install
sudo make install-init
sudo make install-config
sudo make install-commandmode
sudo make install-webconf

# Instalar plugins
cd /tmp
wget https://nagios-plugins.org/download/nagios-plugins-2.3.3.tar.gz
tar xzf nagios-plugins-2.3.3.tar.gz
cd nagios-plugins-2.3.3

./configure --with-nagios-user=nagios --with-nagios-group=nagios
make
sudo make install
```

### Configuração para Backup Monitoring

```bash
# /usr/local/nagios/etc/objects/backup-commands.cfg

define command{
    command_name    check_backup_job
    command_line    /usr/local/nagios/libexec/check_backup_job.sh
}

define command{
    command_name    check_backup_disk
    command_line    $USER1$/check_disk -w 20% -c 10% -p /backup
}

define command{
    command_name    check_bacula_director
    command_line    $USER1$/check_procs -c 1:1 -C bacula-dir
}
```

```bash
# /usr/local/nagios/etc/objects/backup-services.cfg

define service{
    use                 generic-service
    host_name           backup-server
    service_description Bacula Director Process
    check_command       check_bacula_director
    check_interval      5
    retry_interval      1
}

define service{
    use                 generic-service
    host_name           backup-server
    service_description Backup Job Status
    check_command       check_backup_job
    check_interval      10
    retry_interval      2
}

define service{
    use                 generic-service
    host_name           backup-server
    service_description Backup Disk Space
    check_command       check_backup_disk
    check_interval      10
    retry_interval      2
}
```

## Grafana + Prometheus

### Instalação do Prometheus

```bash
#!/bin/bash
# install-prometheus.sh

# Criar usuário
sudo useradd --no-create-home --shell /bin/false prometheus

# Criar diretórios
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
sudo chown prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus

# Download e instalação
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz
tar xvf prometheus-2.40.0.linux-amd64.tar.gz

sudo cp prometheus-2.40.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.40.0.linux-amd64/promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

sudo cp -r prometheus-2.40.0.linux-amd64/consoles /etc/prometheus
sudo cp -r prometheus-2.40.0.linux-amd64/console_libraries /etc/prometheus
sudo chown -R prometheus:prometheus /etc/prometheus/consoles
sudo chown -R prometheus:prometheus /etc/prometheus/console_libraries
```

### Configuração do Prometheus

```yaml
# /etc/prometheus/prometheus.yml

global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "backup_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: 
        - 'localhost:9100'
        - '192.168.100.20:9100'
        - '192.168.100.30:9100'
        - '192.168.100.40:9100'

  - job_name: 'backup-metrics'
    static_configs:
      - targets: ['localhost:9110']
```

### Regras de Alerta

```yaml
# /etc/prometheus/backup_rules.yml

groups:
  - name: backup.rules
    rules:
    - alert: BackupJobFailed
      expr: backup_job_status == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Backup job failed"
        description: "Backup job has failed for {{ $labels.instance }}"

    - alert: BackupDiskFull
      expr: (node_filesystem_size_bytes{mountpoint="/backup"} - node_filesystem_avail_bytes{mountpoint="/backup"}) / node_filesystem_size_bytes{mountpoint="/backup"} * 100 > 90
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Backup disk almost full"
        description: "Backup disk usage is above 90% on {{ $labels.instance }}"

    - alert: BackupServiceDown
      expr: up{job="backup-metrics"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Backup service is down"
        description: "Backup monitoring service is down on {{ $labels.instance }}"
```

## Scripts de Monitoramento Customizado

### Monitor Geral do Sistema

```bash
#!/bin/bash
# system-monitor.sh

HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="/var/log/system-monitor.log"

# Função de log
log() {
    echo "[$TIMESTAMP] $1" >> $LOG_FILE
}

# CPU Usage
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
log "CPU Usage: ${CPU_USAGE}%"

# Memory Usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}')
log "Memory Usage: ${MEM_USAGE}%"

# Disk Usage
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
log "Disk Usage: ${DISK_USAGE}%"

# Load Average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
log "Load Average:${LOAD_AVG}"

# Network Connections
NET_CONNECTIONS=$(netstat -tn | grep ESTABLISHED | wc -l)
log "Active Connections: $NET_CONNECTIONS"

# Backup Process Status
if pgrep -f "bacula-dir" > /dev/null; then
    log "Bacula Director: RUNNING"
else
    log "Bacula Director: STOPPED"
fi

# Alertas
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    echo "ALERTA: CPU usage alto ($CPU_USAGE%) em $HOSTNAME" | mail -s "CPU Alert" admin@empresa.com
fi

if (( $(echo "$MEM_USAGE > 90" | bc -l) )); then
    echo "ALERTA: Memory usage alto ($MEM_USAGE%) em $HOSTNAME" | mail -s "Memory Alert" admin@empresa.com
fi

if [ "$DISK_USAGE" -gt 85 ]; then
    echo "ALERTA: Disk usage alto ($DISK_USAGE%) em $HOSTNAME" | mail -s "Disk Alert" admin@empresa.com
fi
```

### Monitor de Rede

```bash
#!/bin/bash
# network-monitor.sh

HOSTS=("192.168.100.10" "192.168.100.20" "192.168.100.30" "192.168.100.40")
SERVICES=("22" "80" "443" "9101" "9102" "9103")

for host in "${HOSTS[@]}"; do
    if ping -c 1 "$host" > /dev/null 2>&1; then
        echo "[$host] ONLINE"
        
        # Verificar serviços
        for port in "${SERVICES[@]}"; do
            if timeout 3 bash -c "</dev/tcp/$host/$port" > /dev/null 2>&1; then
                echo "  Port $port: OPEN"
            fi
        done
    else
        echo "[$host] OFFLINE"
        echo "Host $host está offline" | mail -s "Network Alert" admin@empresa.com
    fi
done
```

## Dashboard Grafana

### Configuração de Data Source

```json
{
  "name": "Prometheus",
  "type": "prometheus",
  "url": "http://localhost:9090",
  "access": "proxy",
  "isDefault": true
}
```

### Dashboard JSON para Backup

```json
{
  "dashboard": {
    "title": "Backup Monitoring Dashboard",
    "panels": [
      {
        "title": "Backup Job Status",
        "type": "stat",
        "targets": [
          {
            "expr": "backup_job_status",
            "legendFormat": "Job Status"
          }
        ]
      },
      {
        "title": "Backup Disk Usage",
        "type": "gauge",
        "targets": [
          {
            "expr": "(node_filesystem_size_bytes{mountpoint=\"/backup\"} - node_filesystem_avail_bytes{mountpoint=\"/backup\"}) / node_filesystem_size_bytes{mountpoint=\"/backup\"} * 100",
            "legendFormat": "Disk Usage %"
          }
        ]
      },
      {
        "title": "Backup Volume Size",
        "type": "graph",
        "targets": [
          {
            "expr": "backup_volume_size_bytes",
            "legendFormat": "Volume Size"
          }
        ]
      }
    ]
  }
}
```

## Automação e Alertas

### Configuração de Email

```bash
# /etc/postfix/main.cf
relayhost = smtp.gmail.com:587
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
smtp_sasl_security_options = noanonymous

# /etc/postfix/sasl_passwd
smtp.gmail.com:587 seu_email@gmail.com:sua_senha_app
```

### Script de Alerta via Telegram

```bash
#!/bin/bash
# telegram-alert.sh

BOT_TOKEN="SEU_BOT_TOKEN"
CHAT_ID="SEU_CHAT_ID"
MESSAGE="$1"

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
     -d chat_id="$CHAT_ID" \
     -d text="🚨 ALERTA NOC 🚨
$MESSAGE
Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Servidor: $(hostname)"
```

## Próximos Passos

1. Configurar SNMP monitoring
2. Implementar logs centralizados (ELK Stack)
3. Criar dashboards móveis
4. Configurar alertas avançados
5. Implementar machine learning para anomaly detection
