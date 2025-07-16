# Soluções de Backup - Laboratório NOC

## Índice
1. [Bacula Community](#bacula-community)
2. [Scripts de Backup com rsync](#scripts-rsync)
3. [Amanda Backup](#amanda-backup)
4. [Duplicati](#duplicati)
5. [Veeam Community Edition](#veeam)

## Bacula Community

### Instalação no Ubuntu 22.04

```bash
#!/bin/bash
# install-bacula.sh

# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar dependências
sudo apt install -y mysql-server mysql-client postfix

# Configurar MySQL
sudo mysql_secure_installation

# Instalar Bacula
sudo apt install -y bacula bacula-client bacula-common-mysql

# Configurar banco de dados
sudo /usr/share/bacula/create_mysql_database
sudo /usr/share/bacula/make_mysql_tables
sudo /usr/share/bacula/grant_mysql_privileges

echo "Bacula instalado com sucesso!"
```

### Configuração do Director

```bash
# /etc/bacula/bacula-dir.conf

Director {
  Name = backup-server-dir
  DIRport = 9101
  QueryFile = "/etc/bacula/query.sql"
  WorkingDirectory = "/var/lib/bacula"
  PidDirectory = "/run/bacula"
  Maximum Concurrent Jobs = 20
  Password = "SuaSenhaSegura123"
  Messages = Daemon
}

# Pool de Full Backup
Pool {
  Name = Full-Pool
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Volume Retention = 30 days
  Maximum Volume Bytes = 10G
  Maximum Volumes = 50
  Label Format = "Full-Vol-"
}

# Pool de Incremental
Pool {
  Name = Incremental-Pool
  Pool Type = Backup
  Recycle = yes
  AutoPrune = yes
  Volume Retention = 7 days
  Maximum Volume Bytes = 5G
  Maximum Volumes = 30
  Label Format = "Inc-Vol-"
}

# Job de Backup do Cliente Linux
Job {
  Name = "backup-client-linux"
  Type = Backup
  Level = Incremental
  Client = client-linux-fd
  FileSet = "Linux-FS"
  Schedule = "Daily-Schedule"
  Storage = File-Storage
  Messages = Standard
  Pool = Incremental-Pool
  Full Backup Pool = Full-Pool
  Priority = 10
  Write Bootstrap = "/var/lib/bacula/%c.bsr"
}

# Cliente Linux
Client {
  Name = client-linux-fd
  Address = 192.168.100.20
  FDPort = 9102
  Catalog = MyCatalog
  Password = "ClientPassword123"
  File Retention = 60 days
  Job Retention = 6 months
  AutoPrune = yes
}

# FileSet para Linux
FileSet {
  Name = "Linux-FS"
  Include {
    Options {
      signature = MD5
      compression = GZIP
    }
    File = /home
    File = /etc
    File = /var/log
    File = /opt
  }
  Exclude {
    File = /proc
    File = /tmp
    File = /sys
    File = /.journal
    File = /.fsck
  }
}

# Schedule
Schedule {
  Name = "Daily-Schedule"
  Run = Full 1st sun at 02:00
  Run = Incremental mon-sat at 02:00
}

# Storage
Storage {
  Name = File-Storage
  Address = 192.168.100.10
  SDPort = 9103
  Password = "StoragePassword123"
  Device = FileStorage
  Media Type = File
}

# Catalog
Catalog {
  Name = MyCatalog
  dbname = "bacula"
  dbuser = "bacula"
  dbpassword = "BaculaDBPass123"
}
```

### Scripts de Monitoramento

```bash
#!/bin/bash
# monitor-bacula.sh

LOG_FILE="/var/log/bacula-monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Função para log
log_message() {
    echo "[$DATE] $1" >> $LOG_FILE
}

# Verificar status do Director
if systemctl is-active --quiet bacula-director; then
    log_message "Bacula Director: ONLINE"
else
    log_message "ERRO: Bacula Director: OFFLINE"
    # Enviar alerta
    echo "Bacula Director offline em $(hostname)" | mail -s "ALERTA: Bacula Director" admin@empresa.com
fi

# Verificar jobs das últimas 24h
FAILED_JOBS=$(echo "SELECT JobId,Name,JobStatus FROM Job WHERE JobStatus != 'T' AND StartTime > DATE_SUB(NOW(), INTERVAL 24 HOUR);" | mysql -u bacula -p bacula --skip-column-names)

if [ ! -z "$FAILED_JOBS" ]; then
    log_message "ERRO: Jobs falharam nas últimas 24h: $FAILED_JOBS"
    echo "Jobs de backup falharam: $FAILED_JOBS" | mail -s "ALERTA: Backup Failed" admin@empresa.com
fi

# Verificar espaço em disco
DISK_USAGE=$(df /backup | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 85 ]; then
    log_message "AVISO: Uso de disco alto: ${DISK_USAGE}%"
fi
```

## Scripts de Backup com rsync

### Script Principal

```bash
#!/bin/bash
# rsync-backup.sh

# Configurações
SOURCE_DIRS=("/home" "/etc" "/var/log" "/opt")
DEST_BASE="/backup/rsync"
REMOTE_HOST="192.168.100.40"
REMOTE_USER="backup"
LOG_FILE="/var/log/rsync-backup.log"
DATE=$(date '+%Y-%m-%d')
RETENTION_DAYS=30

# Função de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> $LOG_FILE
}

# Verificar conectividade
if ! ping -c 1 $REMOTE_HOST > /dev/null 2>&1; then
    log "ERRO: Não foi possível conectar ao servidor remoto $REMOTE_HOST"
    exit 1
fi

# Criar diretório de destino
DEST_DIR="$DEST_BASE/$DATE"
ssh $REMOTE_USER@$REMOTE_HOST "mkdir -p $DEST_DIR"

log "Iniciando backup para $REMOTE_HOST:$DEST_DIR"

# Executar backup de cada diretório
for dir in "${SOURCE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        log "Fazendo backup de $dir"
        rsync -avz --delete --progress \
              --exclude="*.tmp" \
              --exclude="*.temp" \
              --exclude="/proc/*" \
              --exclude="/sys/*" \
              "$dir/" "$REMOTE_USER@$REMOTE_HOST:$DEST_DIR$(basename $dir)/"
        
        if [ $? -eq 0 ]; then
            log "Backup de $dir concluído com sucesso"
        else
            log "ERRO: Falha no backup de $dir"
        fi
    else
        log "AVISO: Diretório $dir não encontrado"
    fi
done

# Limpeza de backups antigos
log "Removendo backups com mais de $RETENTION_DAYS dias"
ssh $REMOTE_USER@$REMOTE_HOST "find $DEST_BASE -type d -mtime +$RETENTION_DAYS -name '20*' -exec rm -rf {} \;"

log "Backup concluído"

# Gerar relatório
BACKUP_SIZE=$(ssh $REMOTE_USER@$REMOTE_HOST "du -sh $DEST_DIR" | cut -f1)
log "Tamanho total do backup: $BACKUP_SIZE"
```

### Script de Restore

```bash
#!/bin/bash
# rsync-restore.sh

BACKUP_DATE="$1"
RESTORE_DIR="$2"
REMOTE_HOST="192.168.100.40"
REMOTE_USER="backup"
BACKUP_BASE="/backup/rsync"

if [ -z "$BACKUP_DATE" ] || [ -z "$RESTORE_DIR" ]; then
    echo "Uso: $0 <YYYY-MM-DD> <diretório_destino>"
    echo "Exemplo: $0 2025-07-16 /restore"
    exit 1
fi

# Verificar se backup existe
if ! ssh $REMOTE_USER@$REMOTE_HOST "[ -d $BACKUP_BASE/$BACKUP_DATE ]"; then
    echo "ERRO: Backup de $BACKUP_DATE não encontrado"
    exit 1
fi

# Criar diretório de restore
mkdir -p "$RESTORE_DIR"

echo "Restaurando backup de $BACKUP_DATE para $RESTORE_DIR"

# Listar conteúdo do backup
echo "Conteúdo disponível:"
ssh $REMOTE_USER@$REMOTE_HOST "ls -la $BACKUP_BASE/$BACKUP_DATE"

read -p "Continuar com o restore? (s/N): " confirm
if [[ $confirm != [sS] ]]; then
    echo "Restore cancelado"
    exit 0
fi

# Executar restore
rsync -avz --progress \
      "$REMOTE_USER@$REMOTE_HOST:$BACKUP_BASE/$BACKUP_DATE/" \
      "$RESTORE_DIR/"

echo "Restore concluído em $RESTORE_DIR"
```

## Testes de Integridade

### Script de Verificação

```bash
#!/bin/bash
# verify-backup.sh

BACKUP_DIR="/backup/rsync/$(date '+%Y-%m-%d')"
LOG_FILE="/var/log/backup-verification.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Verificar checksums
log "Iniciando verificação de integridade"

# Gerar checksums dos arquivos originais
find /home -type f -exec md5sum {} \; > /tmp/original_checksums.txt

# Comparar com backup
log "Comparando checksums..."
while read checksum file; do
    backup_file="$BACKUP_DIR/home${file#/home}"
    if [ -f "$backup_file" ]; then
        backup_checksum=$(md5sum "$backup_file" | cut -d' ' -f1)
        if [ "$checksum" != "$backup_checksum" ]; then
            log "ERRO: Checksum diferente para $file"
        fi
    else
        log "AVISO: Arquivo $file não encontrado no backup"
    fi
done < /tmp/original_checksums.txt

log "Verificação concluída"
```

## Automação com Cron

```bash
# Adicionar ao crontab
# crontab -e

# Backup diário às 2:00
0 2 * * * /opt/scripts/rsync-backup.sh

# Verificação de integridade às 4:00
0 4 * * * /opt/scripts/verify-backup.sh

# Limpeza semanal aos domingos às 6:00
0 6 * * 0 /opt/scripts/cleanup-old-backups.sh

# Relatório semanal às segundas 8:00
0 8 * * 1 /opt/scripts/backup-report.sh
```

## Relatórios e Alertas

### Script de Relatório

```bash
#!/bin/bash
# backup-report.sh

REPORT_FILE="/tmp/backup-report-$(date '+%Y-%m-%d').txt"
EMAIL_DEST="admin@empresa.com"

# Cabeçalho do relatório
cat > $REPORT_FILE << EOF
RELATÓRIO DE BACKUP - $(date '+%d/%m/%Y')
=====================================

Servidor: $(hostname)
Período: $(date -d '7 days ago' '+%d/%m/%Y') a $(date '+%d/%m/%Y')

EOF

# Status dos serviços
echo "STATUS DOS SERVIÇOS:" >> $REPORT_FILE
echo "-------------------" >> $REPORT_FILE
systemctl is-active bacula-director >> $REPORT_FILE
systemctl is-active bacula-sd >> $REPORT_FILE
systemctl is-active bacula-fd >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Espaço em disco
echo "ESPAÇO EM DISCO:" >> $REPORT_FILE
echo "----------------" >> $REPORT_FILE
df -h /backup >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Jobs da semana
echo "JOBS DA SEMANA:" >> $REPORT_FILE
echo "---------------" >> $REPORT_FILE
grep "$(date -d '7 days ago' '+%Y-%m-%d')" /var/log/bacula-monitor.log >> $REPORT_FILE

# Enviar relatório
mail -s "Relatório Semanal de Backup - $(hostname)" $EMAIL_DEST < $REPORT_FILE
```

## Próximos Passos

1. Implementar backup para Windows Server
2. Configurar replicação off-site
3. Testar procedures de disaster recovery
4. Implementar monitoramento avançado
5. Documentar runbooks de operação
