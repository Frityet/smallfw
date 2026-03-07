set -e

echo "Installing Java 17 (Zulu)..."
apt update
apt install -y curl unzip zip

usrexec() {
    printf "$ %s" "$@"
    su - vscode -c "bash -lc '$*'"
}

usrexec "curl -s "https://get.sdkman.io" | bash"
usrexec "source ~/.sdkman/bin/sdkman-init.sh && sdk install java 25.0.2-tem"
usrexec "source ~/.sdkman/bin/sdkman-init.sh && sdk install java 21.0.2-tem"
usrexec "source ~/.sdkman/bin/sdkman-init.sh && sdk install java 17.0.18-zulu"
usrexec "source ~/.sdkman/bin/sdkman-init.sh && sdk default java 21.0.2-tem"
