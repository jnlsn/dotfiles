#!/bin/bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

info() { printf '\033[34m[info]\033[0m %s\n' "$1"; }
skip() { printf '\033[33m[skip]\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m[ ok ]\033[0m %s\n' "$1"; }

# Package manager setup & GNU Stow
if [ "$OS" = "Darwin" ]; then
    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)"
        ok "Homebrew installed"
    else
        skip "Homebrew already installed"
    fi

    if ! command -v stow &>/dev/null; then
        info "Installing GNU Stow..."
        brew install stow
        ok "Stow installed"
    else
        skip "Stow already installed"
    fi
else
    if ! command -v stow &>/dev/null; then
        info "Installing GNU Stow..."
        sudo apt-get update -qq && sudo apt-get install -y -qq stow
        ok "Stow installed"
    else
        skip "Stow already installed"
    fi
fi

# Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh My Zsh installed"
else
    skip "Oh My Zsh already installed"
fi

# zsh-autosuggestions
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    info "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
    ok "zsh-autosuggestions installed"
else
    skip "zsh-autosuggestions already installed"
fi

# zsh-syntax-highlighting
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    info "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    ok "zsh-syntax-highlighting installed"
else
    skip "zsh-syntax-highlighting already installed"
fi

# Ghostty terminfo — compile if not already available
if ! infocmp -x xterm-ghostty &>/dev/null; then
    info "Installing Ghostty terminfo..."
    cat << 'TERMINFO' > /tmp/ghostty.terminfo
xterm-ghostty|ghostty|Ghostty,
  am, bce, ccc, hs, km, mc5i, mir, msgr, npc, xenl,
  colors#0x100, cols#80, it#8, lines#24, pairs#0x7fff,
  acsc=``aaffggiijjkkllmmnnooppqqrrssttuuvvwwxxyyzz{{||}}~~,
  bel=^G, blink=\E[5m, bold=\E[1m, cbt=\E[Z,
  civis=\E[?25l, clear=\E[H\E[2J, cnorm=\E[?12l\E[?25h,
  cr=\r, csr=\E[%i%p1%d;%p2%dr, cub=\E[%p1%dD, cub1=^H,
  cud=\E[%p1%dB, cud1=\n, cuf=\E[%p1%dC, cuf1=\E[C,
  cup=\E[%i%p1%d;%p2%dH, cuu=\E[%p1%dA, cuu1=\E[A,
  cvvis=\E[?12;25h, dch=\E[%p1%dP, dch1=\E[P, dim=\E[2m,
  dl=\E[%p1%dM, dl1=\E[M, ech=\E[%p1%dX, ed=\E[J, el=\E[K,
  el1=\E[1K, flash=\E[?5h$<100/>\E[?5l, home=\E[H,
  hpa=\E[%i%p1%dG, ht=\t, hts=\EH, ich=\E[%p1%d@,
  il=\E[%p1%dL, il1=\E[L, ind=\n, indn=\E[%p1%dS,
  invis=\E[8m, is2=\E[!p\E[?3;4l\E[4l\E>,
  kDC=\E[3;2~, kEND=\E[1;2F, kHOM=\E[1;2H, kIC=\E[2;2~,
  kLFT=\E[1;2D, kNXT=\E[6;2~, kPRV=\E[5;2~, kRIT=\E[1;2C,
  ka1=\E[1~, ka3=\E[5~, kb2=\EOE, kbs=\177, kc1=\E[4~,
  kc3=\E[6~, kcbt=\E[Z, kcub1=\EOD, kcud1=\EOB,
  kcuf1=\EOC, kcuu1=\EOA, kdch1=\E[3~, kend=\EOF,
  kent=\EOM, kf1=\EOP, kf10=\E[21~, kf11=\E[23~,
  kf12=\E[24~, kf13=\E[1;2P, kf14=\E[1;2Q, kf15=\E[1;2R,
  kf16=\E[1;2S, kf17=\E[15;2~, kf18=\E[17;2~,
  kf19=\E[18;2~, kf2=\EOQ, kf20=\E[19;2~, kf21=\E[20;2~,
  kf22=\E[21;2~, kf23=\E[23;2~, kf24=\E[24;2~,
  kf25=\E[1;5P, kf26=\E[1;5Q, kf27=\E[1;5R,
  kf28=\E[1;5S, kf29=\E[15;5~, kf3=\EOR, kf30=\E[17;5~,
  kf31=\E[18;5~, kf32=\E[19;5~, kf33=\E[20;5~,
  kf34=\E[21;5~, kf35=\E[23;5~, kf36=\E[24;5~,
  kf37=\E[1;6P, kf38=\E[1;6Q, kf39=\E[1;6R, kf4=\EOS,
  kf40=\E[1;6S, kf41=\E[15;6~, kf42=\E[17;6~,
  kf43=\E[18;6~, kf44=\E[19;6~, kf45=\E[20;6~,
  kf46=\E[21;6~, kf47=\E[23;6~, kf48=\E[24;6~, kf5=\E[15~,
  kf6=\E[17~, kf7=\E[18~, kf8=\E[19~, kf9=\E[20~,
  khome=\EOH, kich1=\E[2~, kmous=\E[<, knp=\E[6~,
  kpp=\E[5~, mc0=\E[i, mc4=\E[4i, mc5=\E[5i, meml=\El,
  memu=\Em, mgc=\E[?69l, oc=\E]104\007,
  op=\E[39;49m, rc=\E8, rep=%p1%c\E[%p2%{1}%-%db,
  rev=\E[7m, ri=\EM, rin=\E[%p1%dT, ritm=\E[23m, rmacs=\E(B,
  rmam=\E[?7l, rmcup=\E[?1049l\E[23;0;0t, rmir=\E[4l,
  rmkx=\E[?1l\E>, rmm=\E[?1034l, rmso=\E[27m, rmul=\E[24m,
  rs1=\Ec\E]104\007,
  sc=\E7,
  setab=\E[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m,
  setaf=\E[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m,
  setb=%p1%{8}%/%{6}%*%{4}%+\E[%d%p1%{8}%m%Pa%?%ga%{1}%=%t4%e%ga%{3}%=%t6%e%ga%{4}%=%t1%e%ga%{6}%=%t3%e%ga%d%;m,
  setf=%p1%{8}%/%{6}%*%{3}%+\E[%d%p1%{8}%m%Pa%?%ga%{1}%=%t4%e%ga%{3}%=%t6%e%ga%{4}%=%t1%e%ga%{6}%=%t3%e%ga%d%;m,
  setrgbb=\E[48;2;%p1%d;%p2%d;%p3%dm,
  setrgbf=\E[38;2;%p1%d;%p2%d;%p3%dm,
  sgr=%?%p9%t\E(0%e\E(B%;\E[0%?%p6%t;1%;%?%p5%t;2%;%?%p2%t;4%;%?%p1%p3%|%t;7%;%?%p4%t;5%;%?%p7%t;8%;m,
  sgr0=\E(B\E[m, sitm=\E[3m, smacs=\E(0, smam=\E[?7h,
  smcup=\E[?1049h\E[22;0;0t, smir=\E[4h, smkx=\E[?1h\E=,
  smm=\E[?1034h, smso=\E[7m, smul=\E[4m, smulx=\E[4:%p1%dm,
  tbc=\E[3g, tsl=\E]2;, u6=\E[%i%d;%dR, u7=\E[6n,
  u8=\E[?%[;0123456789]c, u9=\E[c, vpa=\E[%i%p1%dd,
TERMINFO
    tic -x /tmp/ghostty.terminfo
    rm /tmp/ghostty.terminfo
    ok "Ghostty terminfo installed"
else
    skip "Ghostty terminfo already available"
fi

# Stow packages — only stow macOS-specific packages on Darwin
PACKAGES="claude gh git zsh"
if [ "$OS" = "Darwin" ]; then
    PACKAGES="$PACKAGES ghostty vscode"
fi

# Back up existing files that would conflict with stow symlinks
# (e.g. .zshrc and .zprofile created by the devcontainer base image)
for pkg in $PACKAGES; do
    for f in "$DOTFILES/$pkg"/.*; do
        [ -e "$f" ] || continue
        target="$HOME/$(basename "$f")"
        if [ -f "$target" ] && [ ! -L "$target" ]; then
            info "Backing up $target to $target.bak"
            mv "$target" "$target.bak"
        fi
    done
done

info "Stowing dotfiles ($PACKAGES)..."
cd "$DOTFILES"
stow -t ~ $PACKAGES
ok "All packages stowed"

# Set zsh as default shell
if [ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    info "Setting default shell to zsh..."
    sudo chsh "$(id -un)" --shell "/usr/bin/zsh"
    ok "Default shell set to zsh"
else
    skip "Default shell already zsh"
fi

# EFS network directory — persist credentials across Ona instances.
# Set EFS_MOUNT_POINT in Ona secrets to enable (e.g. /efs).
# Docs: https://docs.google.com/document/d/1sypPRmiGrbh4g2UmbkNNLo8ELKG7mSK_Avs7vyx2KPk
EFS_DIR="${EFS_MOUNT_POINT:-}"
if [ -n "$EFS_DIR" ] && [ -d "$EFS_DIR" ]; then
    info "EFS mount detected at $EFS_DIR — linking credentials..."

    # Links a file or directory from $HOME to $EFS_DIR. Migrates existing
    # content on first run, then creates a symlink for future instances.
    link_to_efs() {
        local name="$1"
        local src="$HOME/$name"
        local dst="$EFS_DIR/$name"

        # Already correct
        if [ -L "$src" ] && [ "$(readlink "$src")" = "$dst" ]; then
            return
        fi

        # Migrate existing file/dir to EFS if destination doesn't exist yet
        if [ ! -e "$dst" ] && [ -e "$src" ] && [ ! -L "$src" ]; then
            mkdir -p "$(dirname "$dst")"
            mv "$src" "$dst"
        fi

        # Remove stale real file/dir or wrong symlink at src
        if [ -e "$src" ] || [ -L "$src" ]; then
            rm -rf "$src"
        fi

        mkdir -p "$(dirname "$src")"
        mkdir -p "$(dirname "$dst")"
        ln -s "$dst" "$src"
    }

    link_to_efs ".claude.json"              # Claude Code OAuth + API key
    link_to_efs ".claude/.credentials.json"  # Claude Code credentials
    link_to_efs ".config/gh/hosts.yml"       # GitHub CLI auth
    link_to_efs ".config/acli"               # Atlassian CLI auth
    link_to_efs ".aws"                       # AWS config
    link_to_efs ".zsh_history"               # Shell history
    link_to_efs ".terminfo"                  # Ghostty terminfo

    ok "EFS credential symlinks configured"
else
    skip "No EFS mount found (set EFS_MOUNT_POINT in Ona secrets to enable)"
fi
