# MT5 com GE-Proton 10-23 (Wine Wayland + Hyprland-friendly)

Container Docker pra rodar **MetaTrader 5** no Linux usando **GE-Proton 10-23** com driver **Wine Wayland nativo** (sem XWayland).

## ✨ Features

- ✅ **Wine Wayland nativo** (sem X11/XWayland) — ideal pra Hyprland
- ✅ **GE-Proton 10-23** (última versão estável)
- ✅ **Intel/AMD/Nvidia GPU** via DRI
- ✅ **PipeWire/PulseAudio** (som)
- ✅ **Auto-detect de monitor** Wayland
- ✅ **WineD3D (OpenGL)** forçado pro WebView2 funcionar
- ✅ **Múltiplos scripts de manutenção** (reset, fix DPI, fonts, etc)
- ✅ **Idempotente** — pode rodar quantas vezes quiser

## 📋 Requisitos

- Docker 24+ com BuildKit
- Host Linux com Wayland (Hyprland, Sway, GNOME Wayland)
- GPU Intel/AMD/Nvidia com driver funcionando
- ~5GB de espaço em disco (imagem + dados MT5)

## 🚀 Como usar

### Local (Arch/Hyprland)

```bash
# Clona o repo
git clone https://github.com/SEU_USER/mt5-proton.git
cd mt5-proton

# Builda e sobe
./inicio2.sh

# Dentro do container, instala o MT5 (primeira vez)
# 1. Coloque o mt5setup.exe em /home/veris/mt5_installer/ (no host)
# 2. Dentro do container:
/proton/proton run /home/veris/mt5_installer/mt5setup.exe

# Inicia o MT5
/start_mt5.sh
```

### Coolify (VPS)

Veja seção [Coolify](#-coolify-deployment) abaixo.

## 📂 Estrutura

```
.
├── Dockerfile                  # Imagem base Ubuntu 24.04 + GE-Proton
├── docker-compose.yml          # Configuração do serviço
├── inicio2.sh                  # Script de entrada (host)
├── start.sh                    # Entry point (container)
├── start_mt5.sh                # Inicia o MT5
├── install_fonts.sh            # Instala fontes Windows
├── install_webview2.sh         # Instala WebView2 Runtime
├── enable_webview_simple.sh    # ⚠️ Fix DEFINITIVO pro WebView2 (Mercado MQL5)
├── force_wined3d_webview.sh    # Fix alternativo WebView2
├── fix_dpi_resolution.sh       # Fix de DPI/LogPixels
├── force_wayland.sh            # Força driver Wayland
├── reset_all.sh                # Master reset (tudo de uma vez)
├── redock_windows.sh           # Redocka Navigator/Toolbox
├── fix_swapchain.sh            # Fix tamanho do monitor no Wayland
├── check_webview2.sh           # Diagnóstico WebView2
└── install_dlls_proton.sh      # Instala DLLs via winetricks (opcional)
```

## 🔧 Scripts de manutenção

Todos os scripts são **idempotentes** (pode rodar múltiplas vezes).

### Após instalar o MT5

```bash
# 1. Instala fontes (Tahoma, Segoe UI, Calibri)
/install_fonts.sh

# 2. Instala WebView2 Runtime
/install_webview2.sh

# 3. Habilita o WebView2 (corrige o DXVK → WineD3D)
/enable_webview_simple.sh

# 4. Inicia o MT5
/start_mt5.sh
```

### Se algo der errado

```bash
# Master reset (corrige quase tudo)
/reset_all.sh 96    # 96 = DPI padrão

# Diagnóstico WebView2
/check_webview2.sh

# Re-redockar Navigator/Toolbox
/fix_swapchain.sh
```

## 🎯 Configuração do Hyprland

Adicione no seu `~/.config/hypr/hyprland.conf`:

```ini
xwayland {
    force_zero_scaling = true
}
```

## 📊 Variáveis de ambiente

| Variável | Default | Descrição |
|---|---|---|
| `MT5_WINEDPI` | 96 | DPI (96=1.0, 120=1.25, 144=1.5, 192=2.0) |
| `PROTON_WAYLAND_MONITOR` | (auto) | Forçar monitor específico (ex: eDP-1) |
| `MT5_USE_X11` | 0 | 1 = usar X11/XWayland em vez de Wayland nativo |

Exemplo:
```bash
MT5_WINEDPI=144 PROTON_WAYLAND_MONITOR=eDP-1 ./inicio2.sh
```

## 🌐 Coolify Deployment

### Setup

1. Crie um **repositório privado** no GitHub com esses arquivos
2. No Coolify, clique em **+ New Resource** → **Application**
3. Selecione **GitHub** e autorize o acesso
4. Escolha o repositório `mt5-proton`
5. Configure:
   - **Build Pack**: Docker
   - **Port**: 3389 (VNC) ou use um viewer web
   - **Volumes persistentes** (importante!):
     ```
     /var/lib/coolify/mt5/proton_prefix
     /var/lib/coolify/mt5/proton_logs
     /var/lib/coolify/mt5/installer
     ```

### Acesso remoto (VNC)

Pra acessar o MT5 de qualquer lugar, adicione um servidor VNC:

```dockerfile
# Adicione no Dockerfile (após USER ${USER_NAME}):
RUN apt-get install -y x11vnc xvfb
```

Ou use um serviço de streaming (RustDesk, NoMachine, etc).

## 🐛 Troubleshooting

### MT5 não redimensiona a Toolbox

```bash
/reset_all.sh 96
# E se ainda não funcionar:
pkill -f terminal64.exe
pkill -f wineserver
sleep 2
/force_wayland.sh
```

### WebView2 (Mercado MQL5) não abre

```bash
/check_webview2.sh
# Se mostrar score baixo:
/enable_webview_simple.sh
# Reiniciar container:
exit
./inicio2.sh
```

### Janela em 800x600

```bash
/reset_all.sh
```

### "wineserver not found" no winetricks

```bash
export PATH="/proton/dist/bin:$PATH"
winetricks ...
```

## 📜 Licença

MIT

## 🙏 Créditos

- [GloriousEggroll/proton-ge-custom](https://github.com/GloriousEggroll/proton-ge-custom) — GE-Proton
- [WineHQ](https://www.winehq.org/) — Wine/WineD3D
- [MT5](https://www.metatrader5.com/) — MetaTrader 5
- [Hyprland](https://hyprland.org/) — Wayland compositor
