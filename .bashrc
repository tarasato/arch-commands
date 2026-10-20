#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias windows='sudo grub-reboot efi-bootnext-000'
alias bios='sudo systemctl reboot --firmware-setup'
alias ff='clear && fastfetch'
alias cls='clear'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
fastfetch
