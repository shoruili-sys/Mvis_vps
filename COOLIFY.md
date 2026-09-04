# Deploy no Coolify

Guia completo pra rodar o MT5 na sua VPS via Coolify.

## 🎯 Pré-requisitos

- VPS com Coolify instalado
- GitHub com o repo do mt5-proton (privado ou público)
- Domínio (opcional, mas recomendado)

## 📋 Passo a passo

### 1. Setup do GitHub

```bash
# No seu PC local
cd /home/veris/dock/mt5_33

# Inicializa o git
git init
git add .
git commit -m "MT5 Proton GE-Proton 10-23 + Wine Wayland"

# Conecta ao GitHub (crie o repo primeiro em https://github.com/new)
git remote add origin https://github.com/SEU_USER/mt5-proton.git
git branch -M main
git push -u origin main
```

### 2. Cria o recurso no Coolify

1. Acesse o painel do Coolify (geralmente `http://IP_DA_VPS:8000`)
2. Vá em **+ New Resource** → **Application**
3. Escolha **GitHub** como source
4. Autorize o acesso ao GitHub (se ainda não fez)
5. Selecione o repositório `mt5-proton`
6. Configure:

#### Build Configuration

| Campo | Valor |
|---|---|
| **Build Pack** | `Docker` |
| **Dockerfile Location** | `Dockerfile.vps` (não o normal!) |
| **Docker Compose Location** | `docker-compose.vps.yml` (não o normal!) |

#### Port Configuration

| Porta | Descrição |
|---|---|
| `5900` | VNC (acesso via cliente VNC) |
| `6080` | noVNC (acesso via browser) |

Coolify vai expor essas portas automaticamente.

#### Environment Variables

Adicione:

```
VNC_PASSWORD=uma_senha_forte_aqui
VNC_RESOLUTION=1920x1080x24
```

#### Persistent Volumes (IMPORTANTE!)

No Coolify, configure os volumes pra persistirem:

| Volume interno | Path no host |
|---|---|
| `/home/veris/proton_prefix` | `/var/lib/coolify/mt5/proton_prefix` |
| `/home/veris/proton_logs` | `/var/lib/coolify/mt5/proton_logs` |
| `/home/veris/mt5_installer` | `/var/lib/coolify/mt5/installer` |

Ou, se o Coolify usar **named volumes** (default), eles são gerenciados automaticamente.

#### Domain (Opcional)

Você pode mapear:
- `mt5.seudominio.com` → porta 6080 (noVNC web)
- `mt5-vnc.seudominio.com` → porta 5900 (VNC direto)

### 3. Deploy

1. Clique em **Deploy**
2. Acompanhe o build (5-10 min na primeira vez — vai baixar GE-Proton 500MB)
3. Quando terminar, status fica **Running**

### 4. Instalar o MT5

Você tem 2 opções:

#### Opção A: Via shell do Coolify

1. No Coolify, vá em **Execute Command**
2. Selecione o container `mt5-vps`
3. Cole:
   ```bash
   # 1. Copia o instalador via wget
   wget -O /home/veris/mt5_installer/mt5setup.exe \
     https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe
   
   # 2. Roda o instalador
   /proton/proton run /home/veris/mt5_installer/mt5setup.exe
   ```
4. Siga o instalador visualmente (via VNC/noVNC)

#### Opção B: Via upload noVNC

1. Acesse `http://IP_DA_VPS:6080/vnc.html`
2. Senha: a que você configurou em `VNC_PASSWORD`
3. Você vai ver a tela do container
4. Abra um terminal e rode os comandos acima

### 5. Configurar o MT5

1. Após instalar, rode o instalador (passo anterior)
2. MT5 vai abrir no display virtual
3. Faça login com sua conta do broker
4. Configure o que precisar

### 6. Acessar de qualquer lugar

#### Via noVNC (browser)

Abra no navegador:
```
http://IP_DA_VPS:6080/vnc.html
```

Cole a senha do VNC. Você vai ver a tela do MT5 rodando.

#### Via cliente VNC

Use qualquer cliente VNC (RealVNC, TigerVNC, Remmina):
```
IP_DA_VPS:5900
```

## 🔧 Comandos úteis no Coolify

### Entrar no shell do container

No painel, vá em **Execute Command** → **bash**

### Ver logs

No painel, clique em **Logs**

### Reiniciar o container

**Restart Container** no painel

### Atualizar o MT5

Quando sair nova versão do MT5, faça:
1. Abra o shell do container
2. Rode: `/start_mt5.sh --update` (ou baixe o instalador novo e rode)

## 📱 Acesso mobile

### iOS / Android

Instale um cliente VNC:
- **iOS**: Remmina (App Store) ou VNC Viewer
- **Android**: VNC Viewer (Google Play)

Conecta em `IP_DA_VPS:5900` com a senha configurada.

### Acesso via browser (noVNC)

Funciona em qualquer dispositivo com browser moderno (Chrome, Firefox, Safari).

## 🔐 Segurança

### Recomendações básicas

1. **Senha forte do VNC** (não use `mt5vps` em produção)
2. **Não exponha porta 5900 na internet** — só use via VPN ou Cloudflare Tunnel
3. **Use HTTPS pro noVNC** (via proxy reverso com Caddy/Nginx)
4. **Fail2ban** no servidor (protege contra brute force)

### Setup com Cloudflare Tunnel (recomendado)

```bash
# Na VPS
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared noble main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install cloudflared

# Autentica
cloudflared tunnel login
cloudflared tunnel create mt5
cloudflared tunnel route dns mt5 mt5.seudominio.com

# Config
cat > ~/.cloudflared/config.yml <<EOF
url: http://localhost:6080
tunnel: <TUNNEL_ID>
credentials-file: /home/veris/.cloudflared/<TUNNEL_ID>.json
ingress:
  - hostname: mt5.seudominio.com
    service: http_status:200
EOF

# Roda
cloudflared tunnel run mt5
```

Agora `https://mt5.seudominio.com` mostra o noVNC com HTTPS.

## 💰 Custos estimados

| Recurso | Custo/mês |
|---|---|
| VPS básica (2 vCPU, 4GB RAM) | R$ 25-50 |
| VPS média (4 vCPU, 8GB RAM) | R$ 50-100 |
| Cloudflare Tunnel | Grátis |
| Domínio | R$ 5-15/mês (se não tiver) |

Recomendado: VPS com **4 vCPU + 8GB RAM** (MT5 pode consumir bastante).

## 🐛 Troubleshooting

### Container não inicia

```bash
# Verifica os logs
docker logs mt5-vps

# Se reclamar de porta em uso
netstat -tlnp | grep 5900
```

### noVNC não carrega

```bash
# Verifica se websockify tá rodando
docker exec mt5-vps ps aux | grep websockify

# Reinicia
docker restart mt5-vps
```

### MT5 não inicia

```bash
# Entra no container
docker exec -it mt5-vps bash

# Roda diagnóstico
/check_webview2.sh
/reset_all.sh
```

## 📚 Mais informações

- [Documentação do Coolify](https://coolify.io/docs)
- [noVNC](https://novnc.com/info.html)
- [GE-Proton no GitHub](https://github.com/GloriousEggroll/proton-ge-custom)

## ⚠️ Aviso

MT5 rodando 24/7 na VPS:
- Mantém a sessão aberta (broker pode desconectar depois de horas)
- Consome recursos continuamente
- Recomendado desligar quando não usar
