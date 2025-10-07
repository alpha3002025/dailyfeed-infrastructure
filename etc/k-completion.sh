source <(kubectl completion zsh)  # 현재 셸에 zsh의 자동 완성 설정
echo '[[ $commands[kubectl] ]] && source <(kubectl completion zsh)' >> ~/.zshrc

echo 'alias k=kubectl' >> ~/.zshrc
echo 'complete -o default -F __start_kubectl k' >> ~/.zshrc
source ~/.zshrc