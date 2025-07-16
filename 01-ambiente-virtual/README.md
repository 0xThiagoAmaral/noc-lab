# Ambiente Virtual - Laboratório NOC

## Especificações das VMs

### VM 1: Backup Server (Ubuntu 22.04)
- **RAM**: 4GB
- **Storage**: 50GB (Sistema) + 200GB (Backup Storage)
- **CPU**: 2 cores
- **Rede**: Bridge + Host-Only
- **Serviços**: Bacula Director, Zabbix Server, NFS Server

### VM 2: Client Linux (CentOS Stream 9)
- **RAM**: 2GB
- **Storage**: 20GB
- **CPU**: 1 core
- **Rede**: Bridge + Host-Only
- **Serviços**: Bacula Client, Zabbix Agent, SMB Client

### VM 3: Client Windows (Windows Server 2022)
- **RAM**: 4GB
- **Storage**: 40GB
- **CPU**: 2 cores
- **Rede**: Bridge + Host-Only
- **Serviços**: Bacula Client, CIFS/SMB Server

### VM 4: Storage Server (Ubuntu 22.04)
- **RAM**: 2GB
- **Storage**: 20GB (Sistema) + 500GB (Storage Pool)
- **CPU**: 1 core
- **Rede**: Bridge + Host-Only
- **Serviços**: NFS, CIFS, FTP, iSCSI Target

## Topologia de Rede

```
Internet
    |
[Router/Gateway]
    |
[Switch Virtual]
    |
+---+---+---+---+
|   |   |   |   |
VM1 VM2 VM3 VM4
```

### Endereçamento IP
- **Rede**: 192.168.100.0/24
- **Gateway**: 192.168.100.1
- **VM1 (Backup Server)**: 192.168.100.10
- **VM2 (Client Linux)**: 192.168.100.20
- **VM3 (Client Windows)**: 192.168.100.30
- **VM4 (Storage Server)**: 192.168.100.40

## Ferramentas de Virtualização

### Opção 1: VirtualBox (Gratuito)
```bash
# Instalação no Ubuntu
sudo apt update
sudo apt install virtualbox virtualbox-ext-pack
```

### Opção 2: VMware Workstation Pro (Trial)
```bash
# Download do site oficial
# Instalar conforme instruções do fabricante
```

### Opção 3: QEMU/KVM (Linux)
```bash
# Instalação no Ubuntu
sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
```

## Scripts de Automação

### Vagrant (Opcional)
```ruby
# Vagrantfile para automação
Vagrant.configure("2") do |config|
  config.vm.define "backup-server" do |bs|
    bs.vm.box = "ubuntu/jammy64"
    bs.vm.network "private_network", ip: "192.168.100.10"
    bs.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = 2
    end
  end
end
```

## Checklist de Preparação

- [ ] Hypervisor instalado e configurado
- [ ] ISOs baixadas (Ubuntu 22.04, CentOS Stream 9, Windows Server 2022)
- [ ] Rede virtual configurada
- [ ] VMs criadas com especificações corretas
- [ ] Sistemas operacionais instalados
- [ ] Conectividade de rede testada
- [ ] SSH/RDP configurado para acesso remoto
- [ ] Snapshots iniciais criados

## Recursos de Hardware Mínimos

### Para o Host
- **CPU**: Intel i5 ou AMD Ryzen 5 (4+ cores)
- **RAM**: 16GB (recomendado 32GB)
- **Storage**: 1TB SSD
- **Rede**: Ethernet Gigabit

## Backup do Ambiente

### Script de Backup das VMs
```bash
#!/bin/bash
# backup-vms.sh

BACKUP_DIR="/backup/vms"
DATE=$(date +%Y%m%d)

# VirtualBox
vboxmanage export "backup-server" -o "${BACKUP_DIR}/backup-server-${DATE}.ova"
vboxmanage export "client-linux" -o "${BACKUP_DIR}/client-linux-${DATE}.ova"
vboxmanage export "client-windows" -o "${BACKUP_DIR}/client-windows-${DATE}.ova"
vboxmanage export "storage-server" -o "${BACKUP_DIR}/storage-server-${DATE}.ova"

echo "Backup das VMs concluído em ${BACKUP_DIR}"
```

## Monitoramento do Ambiente

### Scripts de Verificação
- Monitor de recursos (CPU, RAM, Disk)
- Verificação de conectividade
- Status dos serviços críticos
- Alertas por email/Telegram

## Troubleshooting Comum

### Problemas de Rede
```bash
# Verificar conectividade
ping 192.168.100.10

# Verificar rotas
ip route show

# Testar portas
telnet 192.168.100.10 22
```

### Problemas de Performance
```bash
# Monitorar recursos
htop
iotop
nethogs
```

## Próximos Passos

1. Configurar SSH keys entre as VMs
2. Instalar ferramentas básicas de monitoramento
3. Configurar sincronização de tempo (NTP)
4. Implementar logging centralizado
5. Criar scripts de automação para deploy
