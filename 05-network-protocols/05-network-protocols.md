# Protocolos de Rede - Laboratório NOC

## Protocolos Implementados

### 1. CIFS/SMB - Compartilhamento Windows
### 2. NFS - Network File System
### 3. FTP/SFTP - File Transfer Protocol
### 4. iSCSI - Internet Small Computer Systems Interface

## CIFS/SMB Configuration

### Instalação do Samba (Ubuntu)

```bash
#!/bin/bash
# install-samba.sh

# Instalar Samba
sudo apt update
sudo apt install -y samba samba-common-bin

# Backup da configuração original
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.backup

# Criar diretórios de compartilhamento
sudo mkdir -p /srv/samba/backup
sudo mkdir -p /srv/samba/public
sudo mkdir -p /srv/samba/secure

# Definir permissões
sudo chown -R nobody:nogroup /srv/samba/public
sudo chmod -R 0775 /srv/samba/public

sudo chown -R root:sambashare /srv/samba/secure
sudo chmod -R 0770 /srv/samba/secure

# Reiniciar serviços
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd
```

### Configuração do SMB

```ini
# /etc/samba/smb.conf

[global]
   workgroup = NOCLABGROUP
   server string = NOC Lab Samba Server %v
   netbios name = noclab-storage
   security = user
   map to guest = bad user
   dns proxy = no
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d

# Compartilhamento para backup
[backup]
   comment = Backup Storage
   path = /srv/samba/backup
   browseable = yes
   read only = no
   guest ok = no
   valid users = backupuser
   write list = backupuser
   create mask = 0664
   directory mask = 0775

# Compartilhamento público
[public]
   comment = Public Storage
   path = /srv/samba/public
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0664
   directory mask = 0775

# Compartilhamento seguro
[secure]
   comment = Secure Storage
   path = /srv/samba/secure
   browseable = no
   read only = no
   guest ok = no
   valid users = @sambashare
   write list = @sambashare
   create mask = 0660
   directory mask = 0770
```

### Scripts de Gerenciamento SMB

```bash
#!/bin/bash
# manage-smb-users.sh

ACTION=$1
USERNAME=$2

case $ACTION in
    "add")
        if [ -z "$USERNAME" ]; then
            echo "Uso: $0 add <username>"
            exit 1
        fi
        
        # Criar usuário do sistema
        sudo adduser --no-create-home --disabled-login --gecos "" $USERNAME
        
        # Adicionar ao grupo sambashare
        sudo usermod -a -G sambashare $USERNAME
        
        # Configurar senha do Samba
        sudo smbpasswd -a $USERNAME
        
        echo "Usuário $USERNAME criado com sucesso"
        ;;
        
    "delete")
        if [ -z "$USERNAME" ]; then
            echo "Uso: $0 delete <username>"
            exit 1
        fi
        
        # Remover do Samba
        sudo smbpasswd -x $USERNAME
        
        # Remover usuário do sistema
        sudo deluser $USERNAME
        
        echo "Usuário $USERNAME removido com sucesso"
        ;;
        
    "list")
        echo "Usuários Samba:"
        sudo pdbedit -L
        ;;
        
    "test")
        echo "Testando configuração Samba:"
        testparm -s
        ;;
        
    *)
        echo "Uso: $0 {add|delete|list|test} [username]"
        exit 1
        ;;
esac
```

### Cliente SMB - Montagem

```bash
#!/bin/bash
# mount-smb-shares.sh

SERVER_IP="192.168.100.40"
MOUNT_BASE="/mnt/smb"
USERNAME="backupuser"

# Criar pontos de montagem
sudo mkdir -p $MOUNT_BASE/backup
sudo mkdir -p $MOUNT_BASE/public
sudo mkdir -p $MOUNT_BASE/secure

# Instalar cliente CIFS
sudo apt install -y cifs-utils

# Arquivo de credenciais
sudo tee /etc/samba/credentials > /dev/null << EOF
username=$USERNAME
password=SuaSenha123
domain=NOCLABGROUP
EOF

sudo chmod 600 /etc/samba/credentials

# Montar compartilhamentos
sudo mount -t cifs //$SERVER_IP/backup $MOUNT_BASE/backup -o credentials=/etc/samba/credentials,uid=$(id -u),gid=$(id -g),iocharset=utf8

sudo mount -t cifs //$SERVER_IP/public $MOUNT_BASE/public -o guest,uid=$(id -u),gid=$(id -g),iocharset=utf8

# Adicionar ao fstab para montagem automática
echo "//$SERVER_IP/backup $MOUNT_BASE/backup cifs credentials=/etc/samba/credentials,uid=$(id -u),gid=$(id -g),iocharset=utf8,_netdev 0 0" | sudo tee -a /etc/fstab

echo "Compartilhamentos SMB montados em $MOUNT_BASE"
```

## NFS Configuration

### Servidor NFS (Ubuntu)

```bash
#!/bin/bash
# install-nfs-server.sh

# Instalar NFS Server
sudo apt update
sudo apt install -y nfs-kernel-server

# Criar diretórios de exportação
sudo mkdir -p /srv/nfs/backup
sudo mkdir -p /srv/nfs/data
sudo mkdir -p /srv/nfs/logs

# Configurar permissões
sudo chown -R nobody:nogroup /srv/nfs/
sudo chmod -R 755 /srv/nfs/

# Configurar exports
sudo tee /etc/exports > /dev/null << EOF
/srv/nfs/backup    192.168.100.0/24(rw,sync,no_subtree_check,no_root_squash)
/srv/nfs/data      192.168.100.0/24(rw,sync,no_subtree_check,root_squash)
/srv/nfs/logs      192.168.100.0/24(ro,sync,no_subtree_check,root_squash)
EOF

# Aplicar configurações
sudo exportfs -a

# Reiniciar serviços
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# Configurar firewall
sudo ufw allow from 192.168.100.0/24 to any port nfs

echo "Servidor NFS configurado com sucesso"
```

### Cliente NFS

```bash
#!/bin/bash
# mount-nfs-shares.sh

NFS_SERVER="192.168.100.40"
MOUNT_BASE="/mnt/nfs"

# Instalar cliente NFS
sudo apt install -y nfs-common

# Criar pontos de montagem
sudo mkdir -p $MOUNT_BASE/backup
sudo mkdir -p $MOUNT_BASE/data
sudo mkdir -p $MOUNT_BASE/logs

# Montar compartilhamentos NFS
sudo mount -t nfs $NFS_SERVER:/srv/nfs/backup $MOUNT_BASE/backup
sudo mount -t nfs $NFS_SERVER:/srv/nfs/data $MOUNT_BASE/data
sudo mount -t nfs $NFS_SERVER:/srv/nfs/logs $MOUNT_BASE/logs

# Adicionar ao fstab
cat << EOF | sudo tee -a /etc/fstab
$NFS_SERVER:/srv/nfs/backup $MOUNT_BASE/backup nfs defaults,_netdev 0 0
$NFS_SERVER:/srv/nfs/data $MOUNT_BASE/data nfs defaults,_netdev 0 0
$NFS_SERVER:/srv/nfs/logs $MOUNT_BASE/logs nfs ro,defaults,_netdev 0 0
EOF

echo "Compartilhamentos NFS montados em $MOUNT_BASE"
```

### Monitoramento NFS

```bash
#!/bin/bash
# monitor-nfs.sh

LOG_FILE="/var/log/nfs-monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# Verificar serviço NFS
if systemctl is-active --quiet nfs-kernel-server; then
    log "NFS Server: RUNNING"
else
    log "ERROR: NFS Server: STOPPED"
fi

# Verificar exports
log "Active NFS Exports:"
showmount -e localhost >> $LOG_FILE

# Verificar conexões ativas
log "Active NFS Connections:"
ss -tn | grep :2049 >> $LOG_FILE

# Verificar performance
log "NFS Statistics:"
nfsstat -s >> $LOG_FILE
```

## FTP/SFTP Configuration

### Servidor FTP (vsftpd)

```bash
#!/bin/bash
# install-ftp-server.sh

# Instalar vsftpd
sudo apt update
sudo apt install -y vsftpd

# Backup da configuração original
sudo cp /etc/vsftpd.conf /etc/vsftpd.conf.backup

# Configurar vsftpd
sudo tee /etc/vsftpd.conf > /dev/null << EOF
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=YES
pasv_enable=Yes
pasv_min_port=10000
pasv_max_port=11000
allow_writeable_chroot=YES
user_sub_token=$USER
local_root=/srv/ftp/$USER
userlist_enable=YES
userlist_file=/etc/vsftpd.userlist
userlist_deny=NO
EOF

# Criar diretório FTP
sudo mkdir -p /srv/ftp

# Reiniciar serviço
sudo systemctl restart vsftpd
sudo systemctl enable vsftpd

echo "Servidor FTP configurado com sucesso"
```

### Gerenciamento de Usuários FTP

```bash
#!/bin/bash
# manage-ftp-users.sh

ACTION=$1
USERNAME=$2

case $ACTION in
    "add")
        if [ -z "$USERNAME" ]; then
            echo "Uso: $0 add <username>"
            exit 1
        fi
        
        # Criar usuário
        sudo adduser --home /srv/ftp/$USERNAME --shell /bin/bash $USERNAME
        
        # Adicionar à lista de usuários permitidos
        echo $USERNAME | sudo tee -a /etc/vsftpd.userlist
        
        # Criar estrutura de diretórios
        sudo mkdir -p /srv/ftp/$USERNAME/{upload,download,backup}
        sudo chown -R $USERNAME:$USERNAME /srv/ftp/$USERNAME
        
        echo "Usuário FTP $USERNAME criado com sucesso"
        ;;
        
    "delete")
        if [ -z "$USERNAME" ]; then
            echo "Uso: $0 delete <username>"
            exit 1
        fi
        
        # Remover da lista de usuários
        sudo sed -i "/^$USERNAME$/d" /etc/vsftpd.userlist
        
        # Remover usuário
        sudo deluser --remove-home $USERNAME
        
        echo "Usuário FTP $USERNAME removido com sucesso"
        ;;
        
    "list")
        echo "Usuários FTP permitidos:"
        cat /etc/vsftpd.userlist
        ;;
        
    *)
        echo "Uso: $0 {add|delete|list} [username]"
        exit 1
        ;;
esac
```

### Cliente FTP/SFTP

```bash
#!/bin/bash
# ftp-backup-client.sh

FTP_SERVER="192.168.100.40"
FTP_USER="backupuser"
FTP_PASS="SuaSenha123"
LOCAL_DIR="/backup/daily"
REMOTE_DIR="/upload"

# Função para FTP upload
ftp_upload() {
    local file=$1
    
    ftp -n $FTP_SERVER << EOF
user $FTP_USER $FTP_PASS
binary
cd $REMOTE_DIR
put $file
quit
EOF
}

# Função para SFTP upload (mais seguro)
sftp_upload() {
    local file=$1
    
    sshpass -p "$FTP_PASS" sftp $FTP_USER@$FTP_SERVER << EOF
cd $REMOTE_DIR
put $file
quit
EOF
}

# Upload dos arquivos de backup
for file in $LOCAL_DIR/*.tar.gz; do
    if [ -f "$file" ]; then
        echo "Uploading $(basename $file)..."
        sftp_upload "$file"
        echo "Upload concluído: $(basename $file)"
    fi
done
```

## iSCSI Configuration

### Target iSCSI (Servidor)

```bash
#!/bin/bash
# install-iscsi-target.sh

# Instalar targetcli
sudo apt update
sudo apt install -y targetcli-fb

# Criar diretório para storage
sudo mkdir -p /srv/iscsi

# Criar arquivo de imagem para LUN
sudo dd if=/dev/zero of=/srv/iscsi/backup-lun1.img bs=1M count=10240

# Configurar target via targetcli
sudo targetcli << EOF
cd backstores/fileio
create backup-lun1 /srv/iscsi/backup-lun1.img 10G
cd /iscsi
create iqn.2025-07.com.noclab:backup-target
cd iqn.2025-07.com.noclab:backup-target/tpg1/luns
create /backstores/fileio/backup-lun1
cd ../acls
create iqn.2025-07.com.noclab:backup-initiator
cd iqn.2025-07.com.noclab:backup-initiator
set auth userid=backup-user
set auth password=BackupPass123
cd /iscsi/iqn.2025-07.com.noclab:backup-target/tpg1
set attribute authentication=1
set attribute demo_mode_write_protect=0
set attribute generate_node_acls=0
saveconfig
exit
EOF

# Habilitar serviços
sudo systemctl enable target
sudo systemctl start target

echo "iSCSI Target configurado com sucesso"
```

### Initiator iSCSI (Cliente)

```bash
#!/bin/bash
# iscsi-initiator.sh

TARGET_IP="192.168.100.40"
TARGET_IQN="iqn.2025-07.com.noclab:backup-target"
INITIATOR_IQN="iqn.2025-07.com.noclab:backup-initiator"

# Instalar initiator
sudo apt install -y open-iscsi

# Configurar initiator name
echo "InitiatorName=$INITIATOR_IQN" | sudo tee /etc/iscsi/initiatorname.iscsi

# Configurar autenticação
sudo tee -a /etc/iscsi/iscsid.conf << EOF
node.session.auth.authmethod = CHAP
node.session.auth.username = backup-user
node.session.auth.password = BackupPass123
EOF

# Reiniciar serviço
sudo systemctl restart open-iscsi

# Descobrir targets
sudo iscsiadm -m discovery -t st -p $TARGET_IP

# Conectar ao target
sudo iscsiadm -m node --targetname "$TARGET_IQN" --portal "$TARGET_IP:3260" --login

# Verificar discos disponíveis
lsblk

echo "iSCSI Initiator configurado. Novo disco disponível para uso."
```

## Scripts de Teste e Troubleshooting

### Teste de Conectividade

```bash
#!/bin/bash
# network-connectivity-test.sh

SERVERS=("192.168.100.10" "192.168.100.20" "192.168.100.30" "192.168.100.40")
PROTOCOLS=("SMB:445" "NFS:2049" "FTP:21" "SSH:22" "iSCSI:3260")

echo "=== TESTE DE CONECTIVIDADE DE REDE ==="
echo "Data: $(date)"
echo

for server in "${SERVERS[@]}"; do
    echo "Testando servidor: $server"
    
    # Ping test
    if ping -c 3 -W 3 $server > /dev/null 2>&1; then
        echo "  ✓ Ping: OK"
        
        # Port tests
        for protocol in "${PROTOCOLS[@]}"; do
            proto_name=${protocol%:*}
            port=${protocol#*:}
            
            if timeout 5 bash -c "</dev/tcp/$server/$port" 2>/dev/null; then
                echo "  ✓ $proto_name (porta $port): OK"
            else
                echo "  ✗ $proto_name (porta $port): FALHA"
            fi
        done
    else
        echo "  ✗ Ping: FALHA - Servidor inacessível"
    fi
    echo
done
```

### Teste de Performance

```bash
#!/bin/bash
# protocol-performance-test.sh

TEST_FILE="/tmp/test-1gb.bin"
TEST_SIZE="1G"

# Criar arquivo de teste
echo "Criando arquivo de teste ($TEST_SIZE)..."
dd if=/dev/zero of=$TEST_FILE bs=1M count=1024 2>/dev/null

echo "=== TESTE DE PERFORMANCE DE PROTOCOLOS ==="

# Teste SMB
echo "Testando SMB..."
START_TIME=$(date +%s)
cp $TEST_FILE /mnt/smb/backup/
END_TIME=$(date +%s)
SMB_TIME=$((END_TIME - START_TIME))
echo "SMB Transfer: ${SMB_TIME}s"

# Teste NFS
echo "Testando NFS..."
START_TIME=$(date +%s)
cp $TEST_FILE /mnt/nfs/backup/
END_TIME=$(date +%s)
NFS_TIME=$((END_TIME - START_TIME))
echo "NFS Transfer: ${NFS_TIME}s"

# Teste FTP
echo "Testando FTP..."
START_TIME=$(date +%s)
curl -T $TEST_FILE ftp://backup-user:SuaSenha123@192.168.100.40/upload/
END_TIME=$(date +%s)
FTP_TIME=$((END_TIME - START_TIME))
echo "FTP Transfer: ${FTP_TIME}s"

# Cleanup
rm -f $TEST_FILE

echo
echo "=== RESULTADOS ==="
echo "SMB: ${SMB_TIME}s"
echo "NFS: ${NFS_TIME}s"  
echo "FTP: ${FTP_TIME}s"
```

### Troubleshooting Script

```bash
#!/bin/bash
# network-troubleshoot.sh

echo "=== DIAGNÓSTICO DE REDE ==="
echo

# Informações de rede
echo "Interfaces de rede:"
ip addr show

echo
echo "Tabela de roteamento:"
ip route show

echo
echo "Servidores DNS:"
cat /etc/resolv.conf

echo
echo "Conexões ativas:"
ss -tuln

echo
echo "Processos de rede:"
netstat -tlnp | grep -E "(445|2049|21|3260)"

echo
echo "Status dos serviços:"
for service in smbd nmbd nfs-kernel-server vsftpd target; do
    if systemctl is-active --quiet $service; then
        echo "$service: RUNNING"
    else
        echo "$service: STOPPED"
    fi
done

echo
echo "Logs recentes:"
journalctl --since "1 hour ago" | grep -i -E "(smb|nfs|ftp|iscsi)" | tail -20
```

## Automação e Monitoramento

### Crontab para Monitoramento

```bash
# Adicionar ao crontab
# crontab -e

# Teste de conectividade a cada 5 minutos
*/5 * * * * /opt/scripts/network-connectivity-test.sh

# Teste de performance diário às 3:00
0 3 * * * /opt/scripts/protocol-performance-test.sh

# Backup de configurações semanalmente
0 2 * * 0 /opt/scripts/backup-network-configs.sh

# Limpeza de logs mensalmente
0 1 1 * * /opt/scripts/cleanup-network-logs.sh
```

## Próximos Passos

1. Implementar SSL/TLS para FTP (FTPS)
2. Configurar autenticação centralizada (LDAP)
3. Implementar QoS para priorização de tráfego
4. Configurar VPN para acesso remoto seguro
5. Implementar load balancing para alta disponibilidade
