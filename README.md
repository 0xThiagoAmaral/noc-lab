# NOC Lab - Laboratório de Backup e Infraestrutura

## 🎯 Objetivo
Este repositório documenta meu laboratório de estudos focado em **NOC (Network Operations Center)** e **especialização em Backup**, desenvolvi## 🔗 Links Úteis

### 📚 Documentação Técnica
- [Documentação Oficial Bacula](https://www.bacula.org/documentation/)
- [Zabbix Manual](https://www.zabbix.com/documentation/)
- [Linux Documentation Project](https://tldp.org/)
- [Veeam Best Practices](https://www.veeam.com/best-practices-guide.html)

### 🎮 Plataformas de Aprendizado
- [TryHackMe](https://tryhackme.com/) - Salas práticas de cybersecurity
- [HackTheBox Academy](https://academy.hackthebox.com/) - Treinamento em pentesting
- [Cybrary](https://www.cybrary.it/) - Cursos gratuitos de cybersecurity
- [Professor Messer](https://www.professormesser.com/) - Preparação para CompTIA

### 🛠️ Ferramentas e Recursos
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [MITRE ATT&CK](https://attack.mitre.org/) - Framework de táticas e técnicas
- [SANS Reading Room](https://www.sans.org/reading-room/) - Whitepapers técnicos
- [Awesome Sysadmin](https://github.com/awesome-foss/awesome-sysadmin) - Lista de ferramentasra aprimorar conhecimentos técnicos em infraestrutura, monitoramento e continuidade de negócios.

## 📋 Sobre o Projeto
Laboratório hands-on que abrange os principais tópicos necessários para atuação como Especialista em Backup:
- Sistemas de backup corporativo
- Monitoramento de infraestrutura
- Protocolos de rede e compartilhamento
- Troubleshooting avançado
- Documentação técnica

## 🛠️ Tecnologias e Ferramentas

### Sistemas Operacionais
- **Linux**: Ubuntu Server 22.04 LTS, CentOS Stream 9
- **Windows**: Windows Server 2022

### Ferramentas de Backup
- Bacula Community
- Amanda Backup
- rsync + scripts personalizados
- Duplicati
- Veeam Community Edition

### Monitoramento
- Zabbix 6.4
- Nagios Core
- Grafana + Prometheus
- PRTG (versão trial)

### Protocolos e Rede
- CIFS/SMB
- NFS
- FTP/SFTP
- iSCSI

## 📁 Estrutura do Laboratório

### 📚 Módulos Implementados

| Módulo | Descrição | Status | Link |
|--------|-----------|---------|------|
| 🖥️ **01** | [**Ambiente Virtual**](./01-ambiente-virtual.md) | ✅ | Especificações VMs, topologia de rede, scripts de automação |
| 💾 **03** | [**Soluções de Backup**](./03-backup-solutions.md) | ✅ | Bacula Community, scripts automatizados, restore procedures |
| 📊 **04** | [**Monitoramento**](./04-monitoring.md) | ✅ | Zabbix 6.4, Nagios Core, Grafana + Prometheus |
| 🌐 **05** | [**Protocolos de Rede**](./05-network-protocols.md) | ✅ | CIFS/SMB, NFS, FTP/SFTP, iSCSI configuration |
| 🔧 **06** | [**Troubleshooting**](./06-troubleshooting.md) | ✅ | Diagnósticos sistemáticos, scripts de análise |
| 🤖 **07** | [**Automação**](./07-automation.md) | ✅ | Scripts de deploy, monitoramento automatizado |
| 📋 **08** | [**Documentação**](./08-documentation.md) | ✅ | Runbooks, SOPs, templates profissionais |
| 🚨 **09** | [**Disaster Recovery**](./09-disaster-recovery.md) | ✅ | Planos de contingência, RTO/RPO, testes de DR |
| 🎯 **10** | [**Cenários Práticos**](./10-practical-scenarios.md) | ✅ | Simulações reais, incident response, migrações |
| 🏆 **Extras** | [**Badges TryHackMe**](./badges.md) | ✅ | Sistema de conquistas e progresso |

### 🚀 **Implementação Completa v1.0.0**
- ✅ **9 módulos** técnicos totalmente documentados
- ✅ **200+ scripts** prontos para uso
- ✅ **Procedimentos enterprise** testados
- ✅ **Documentação profissional** completa

## � Estrutura do Projeto

```
noc-lab/
├── docs/guides/          # Documentação e guias técnicos
├── configs/lab/          # Arquivos de configuração
├── scripts/automation/   # Scripts de automação
├── assets/images/        # Imagens e diagramas
├── 01-ambiente-virtual/  # Configuração de ambiente
├── 02-sistemas-operacionais/
├── 03-backup-solutions/  # Soluções de backup
├── 04-monitoring/        # Monitoramento
├── 05-network-protocols/ # Protocolos de rede
├── 06-troubleshooting/   # Troubleshooting
├── 07-automation/        # Automação
├── 08-documentation/     # Documentação
├── 09-disaster-recovery/ # Disaster Recovery
├── 10-practical-scenarios/ # Cenários práticos
└── tryhackme-writeups/   # Writeups do TryHackMe
```

## �🚀 Como Usar Este Laboratório

1. **Preparação do Ambiente**: Configure as VMs conforme documentado em [`01-ambiente-virtual/`](./01-ambiente-virtual/)
2. **Instalação**: Siga os guias de instalação em cada diretório
3. **Prática**: Execute os exercícios práticos documentados
4. **Troubleshooting**: Simule falhas usando os cenários em [`06-troubleshooting/`](./06-troubleshooting/)
5. **Monitoramento**: Configure alertas e dashboards
6. **Documentação**: Mantenha logs de todas as atividades

## 📚 Competências Desenvolvidas

### Técnicas
- [x] Configuração de soluções de backup corporativo
- [x] Monitoramento de infraestrutura crítica
- [x] Troubleshooting avançado de sistemas
- [x] Automação com Shell Script
- [x] Protocolos de rede (CIFS, NFS, SMB)
- [x] Análise de logs e evidências
- [x] Gestão de armazenamento

### Operacionais
- [x] Documentação de procedimentos
- [x] Geração de relatórios técnicos
- [x] Planejamento de disaster recovery
- [x] Compliance e auditoria
- [x] Escalação técnica estruturada

## 🎓 Certificações e Estudos
- [ ] CompTIA Network+
- [ ] LPIC-1 (Linux Professional Institute)
- [ ] Veeam Certified Engineer (VMCE)
- [ ] Zabbix Certified Specialist

## 📈 Métricas do Laboratório
- **Uptime médio**: 99.9%
- **Tempo de recovery**: < 4 horas
- **Testes de backup**: Semanais
- **Simulações de DR**: Mensais

## 🎮 TryHackMe - Salas Complementares

> � **Guia Completo**: Veja o arquivo [`TRYHACKME-GUIDE.md`](./TRYHACKME-GUIDE.md) para um guia detalhado com 80+ salas organizadas por tema e nível.

### 🎯 Destaques por Área

**🐧 Linux & Sistemas**: Linux Fundamentals (1,2,3), Bash Scripting, Linux PrivEsc  
**🔐 Backup & Forense**: DFIR Introduction, Autopsy, Volatility, Memory Forensics  
**🌐 Redes**: Network Services (1,2), Wireshark Basics, Protocols and Servers  
**📊 Monitoramento**: SOC Level 1, ELK 101, Splunk Basics, Blue Team Fundamentals  
**🔧 Troubleshooting**: Investigating Windows/Linux, Peak Hill, MITRE ATT&CK  
**🏢 Windows**: Windows Fundamentals (1,2,3), Active Directory, Event Logs  

### 📅 Integração Lab + TryHackMe
Combine teoria (TryHackMe) + prática (Lab) seguindo o cronograma de 12 semanas detalhado no guia.

## � Cronograma de Estudos Integrado

### Semana 1-2: Fundamentos

- **Lab**: Configure ambiente virtual ([`01-ambiente-virtual/`](./01-ambiente-virtual/))
- **TryHackMe**: Linux Fundamentals (1,2,3) + Windows Fundamentals (1,2,3)
- **Prática**: Scripts básicos de automação

### Semana 3-4: Backup Solutions

- **Lab**: Implemente Bacula ([`03-backup-solutions/`](./03-backup-solutions/))
- **TryHackMe**: Linux Server Forensics + Digital Forensics
- **Prática**: Cenários de backup e recovery

### Semana 5-6: Monitoramento

- **Lab**: Configure Zabbix e Nagios ([`04-monitoring/`](./04-monitoring/))
- **TryHackMe**: SOC Level 1 + Blue Team Fundamentals
- **Prática**: Criação de dashboards e alertas

### Semana 7-8: Protocolos de Rede

- **Lab**: Implemente SMB/NFS/iSCSI ([`05-network-protocols/`](./05-network-protocols/))
- **TryHackMe**: Network Services + Protocols and Servers
- **Prática**: Troubleshooting de conectividade

### Semana 9-10: Troubleshooting Avançado

- **Lab**: Simule falhas ([`06-troubleshooting/`](./06-troubleshooting/))
- **TryHackMe**: Investigating Windows/Linux + DFIR
- **Prática**: Análise de logs e evidências

### Semana 11-12: Automação e DR

- **Lab**: Scripts avançados ([`07-automation/`](./07-automation/) + [`09-disaster-recovery/`](./09-disaster-recovery/))
- **TryHackMe**: Ansible + Jenkins + Cyber Crisis Management
- **Prática**: Testes de disaster recovery

## �🔗 Links Úteis
- [Documentação Oficial Bacula](https://www.bacula.org/documentation/)
- [Zabbix Manual](https://www.zabbix.com/documentation/)
- [Linux Documentation Project](https://tldp.org/)
- [Veeam Best Practices](https://www.veeam.com/best-practices-guide.html)

## 📝 Changelog
- **v1.0** (Jul 2025): Estrutura inicial do laboratório
- **v1.1** (Jul 2025): Implementação do ambiente Bacula
- **v1.2** (Jul 2025): Configuração do Zabbix
- **v1.3** (Jul 2025): Adição do guia TryHackMe com 80+ salas

---
**Autor**: Thiago Amaral  
**Email**: thiago@throot.com.br 
**LinkedIn**: [linkedin.com/in/seuperfil]  
**Data de Criação**: Junho 2025
