# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[ -f /usr/share/cachyos-zsh-config/cachyos-config.zsh ] && source /usr/share/cachyos-zsh-config/cachyos-config.zsh


alias yt="ytdl.sh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
alias fix="echo 'WINEDLLOVERRIDES=\"winmm=n,b;steam_api64=n,b;OnlineFix64=n,b\" %command%' | wl-copy && echo \"Texte copié dans le presse-papier !\""
alias bios="systemctl reboot --firmware-setup"
alias dotf='nocorrect git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
alias cheat='cd ~/Linux-CS2-External/build && ./LinuxCS2'
alias deban='sudo timedatectl set-ntp false && sudo date -s "+8 days"'
alias normaltime='sudo timedatectl set-ntp true'
alias thefinals='/home/ulysse/Documents/Codex/2026-10-23/kingfisher-you-re-kingfisher-the-maker-5/outputs/kingfisher-finals/run.sh'

# Added by LM Studio CLI tool (lms)
export PATH="$PATH:/home/ulysse/.lmstudio/bin"
