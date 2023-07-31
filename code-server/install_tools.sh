#!/bin/bash
set -euo pipefail
cd /tmp
DEBIAN_FRONTEND=noninteractive
CURL_OPTS=""

echo "Install tools"
apt-get update >/dev/null
apt-get install --no-install-recommends -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb buster main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
chmod a+r /usr/share/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update >/dev/null
apt-get dist-upgrade -y
apt-get install --no-install-recommends -y vim pwgen jq unzip pass zsh fonts-powerline \
    htop software-properties-common gpg netcat-openbsd uuid-runtime dnsutils exa fd-find skopeo bzip2 \
    trivy iproute2 nmap iperf3 docker-ce-cli docker-buildx-plugin docker-compose-plugin

echo "Install Ansible and ansible-modules-hashivault"
# https://www.linuxuprising.com/2023/03/next-debianubuntu-releases-will-likely.html?m=1
export PIP_BREAK_SYSTEM_PACKAGES=1
apt-get install -y --no-install-recommends python3-pip python3-setuptools python3-ldap python3-docker python3-venv twine python3-psycopg2
pip3 install --no-cache-dir ansible ansible-modules-hashivault openshift passlib hvac elasticsearch virtualenv ipykernel checkov opensearch-py


ln -s $(which fdfind) /usr/local/bin/fd

echo "Install Oh My Zsh"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
mv /root/.oh-my-zsh /usr/share/oh-my-zsh

echo "Install kubectl"
curl ${CURL_OPTS} -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    -o /usr/local/bin/kubectl >/dev/null
chmod +x /usr/local/bin/kubectl

echo "Install helm"
latest_release_url="https://github.com/helm/helm/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/helm/helm/releases/tag/v3.' | grep -v beta | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
curl ${CURL_OPTS} -L "https://get.helm.sh/helm-$TAG-linux-amd64.tar.gz" \
    -o /tmp/helm.tar.gz >/dev/null
tar zxf /tmp/helm.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/linux-amd64/helm /usr/local/bin/helm
chown 0755 /usr/local/bin/helm
rm /tmp/helm.tar.gz
rm -Rf /tmp/linux-amd64/

echo "Install krew"
OS="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
KREW="krew-${OS}_${ARCH}"
curl -L "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" -o /tmp/krew.tar.gz >/dev/null
tar zxvf "krew.tar.gz" -C /tmp/ >/dev/null
mv -f /tmp/krew-linux_amd64 /usr/local/bin/krew
chown 0755 /usr/local/bin/krew
rm /tmp/krew.tar.gz /tmp/LICENSE

echo "Install Gadget"
TAG=$(curl https://api.github.com/repos/inspektor-gadget/inspektor-gadget/releases/latest | jq -r .tag_name)
curl -L "https://github.com/inspektor-gadget/inspektor-gadget/releases/download/${TAG}/kubectl-gadget-linux-amd64-${TAG}.tar.gz" -o /tmp/kubectl-gadget.tar.gz >/dev/null
tar zxf /tmp/kubectl-gadget.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/kubectl-gadget /usr/local/bin/kubectl-gadget
chown 0755 /usr/local/bin/kubectl-gadget
rm /tmp/kubectl-gadget.tar.gz /tmp/LICENSE

echo "Install Packer"
latest_release_url="https://github.com/hashicorp/packer/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hashicorp/packer/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
curl ${CURL_OPTS} -L "https://releases.hashicorp.com/packer/${TAG}/packer_${TAG}_linux_amd64.zip" \
    -o /tmp/packer.zip >/dev/null
unzip /tmp/packer.zip -d /tmp/ >/dev/null
mv -f /tmp/packer /usr/local/bin/packer
rm /tmp/packer.zip
packer -autocomplete-install

echo "Install Terraform"
latest_release_url="https://github.com/hashicorp/terraform/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hashicorp/terraform/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
curl ${CURL_OPTS} -L "https://releases.hashicorp.com/terraform/${TAG}/terraform_${TAG}_linux_amd64.zip" \
    -o /tmp/terraform.zip >/dev/null
unzip /tmp/terraform.zip -d /tmp/ >/dev/null
mv -f /tmp/terraform /usr/local/bin/terraform
chown 0755 /usr/local/bin/terraform
rm /tmp/terraform.zip
terraform -install-autocomplete

echo "Install Vault"
latest_release_url="https://github.com/hashicorp/vault/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/hashicorp/vault/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
curl ${CURL_OPTS} -L "https://releases.hashicorp.com/vault/${TAG}/vault_${TAG}_linux_amd64.zip" \
    -o /tmp/vault.zip >/dev/null
unzip /tmp/vault.zip -d /tmp/ >/dev/null
mv -f /tmp/vault /usr/local/bin/vault
chown 0755 /usr/local/bin/vault
rm /tmp/vault.zip
vault -autocomplete-install

echo "Install k9s"
latest_release_url="https://github.com/derailed/k9s/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/derailed/k9s/releases/tag/v' | grep -v beta  | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
curl ${CURL_OPTS} -L "https://github.com/derailed/k9s/releases/download/${TAG}/k9s_Linux_amd64.tar.gz" \
    -o /tmp/k9s.tar.gz >/dev/null
tar zxf /tmp/k9s.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/k9s /usr/local/bin/k9s
chown 0755 /usr/local/bin/k9s
rm /tmp/k9s.tar.gz

echo "Install popeye"
latest_release_url="https://github.com/derailed/popeye/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/derailed/popeye/releases/tag/v' | grep -v beta  | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
curl ${CURL_OPTS} -L "https://github.com/derailed/popeye/releases/download/${TAG}/popeye_Linux_x86_64.tar.gz" \
    -o /tmp/popeye.tar.gz >/dev/null
tar zxf /tmp/popeye.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/popeye /usr/local/bin/popeye
chown 0755 /usr/local/bin/popeye
rm /tmp/popeye.tar.gz

echo "Install havener"
latest_release_url="https://github.com/homeport/havener/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/homeport/havener/releases/tag/v' | grep -v beta  | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
curl ${CURL_OPTS} -L "https://github.com/homeport/havener/releases/download/v${TAG}/havener_${TAG}_linux_amd64.tar.gz" \
    -o /tmp/havener.tar.gz >/dev/null
tar zxf /tmp/havener.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/havener /usr/local/bin/havener
chown 0755 /usr/local/bin/havener
rm /tmp/havener.tar.gz

echo "Install kubectx and kubens"
latest_release_url="https://github.com/ahmetb/kubectx/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/ahmetb/kubectx/releases/tag/v' | grep -v beta  | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
curl ${CURL_OPTS} -L "https://github.com/ahmetb/kubectx/releases/download/v${TAG}/kubectx_v${TAG}_linux_x86_64.tar.gz" \
    -o /tmp/kubectx.tar.gz >/dev/null
tar zxf /tmp/kubectx.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/kubectx /usr/local/bin/kubectx
chown 0755 /usr/local/bin/kubectx
rm /tmp/kubectx.tar.gz
curl ${CURL_OPTS} -L "https://github.com/ahmetb/kubectx/releases/download/v${TAG}/kubens_v${TAG}_linux_x86_64.tar.gz" \
    -o /tmp/kubens.tar.gz >/dev/null
tar zxf /tmp/kubens.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/kubens /usr/local/bin/kubens
chown 0755 /usr/local/bin/kubens
rm /tmp/kubens.tar.gz

# echo "Install dog"
# latest_release_url="https://github.com/ogham/dog/releases"
# TAG=$(curl -Ls $latest_release_url | grep 'href="/ogham/dog/releases/tag/v' | grep -v beta  | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
# curl ${CURL_OPTS} -L "https://github.com/ogham/dog/releases/download/v${TAG}/dog-v${TAG}-x86_64-unknown-linux-gnu.zip" \
#     -o /tmp/dog.zip >/dev/null
# unzip /tmp/dog.zip -d /tmp/ >/dev/null
# mv -f /tmp/bin/dog /usr/local/bin/dog
# chown 0755 /usr/local/bin/dog
# rm /tmp/dog.zip

echo "Install duf"
latest_release_url="https://github.com/muesli/duf/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/muesli/duf/releases/tag/v' | grep -v beta  | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
curl ${CURL_OPTS} -L "https://github.com/muesli/duf/releases/download/v${TAG}/duf_${TAG}_linux_amd64.deb" \
    -o /tmp/duf.deb >/dev/null
dpkg -i /tmp/duf.deb
rm /tmp/duf.deb

echo "Install Minio mc client"
curl ${CURL_OPTS} -L "https://dl.min.io/client/mc/release/linux-amd64/mc" \
    -o /usr/local/bin/mc >/dev/null
chmod 0755 /usr/local/bin/mc

echo "Install Restic cli"
latest_release_url="https://github.com/restic/restic/releases/"
TAG=$(curl -Ls $latest_release_url | grep 'href="/restic/restic/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
wget "https://github.com/restic/restic/releases/download/v${TAG}/restic_${TAG}_linux_amd64.bz2" -O /tmp/restic.bz2 >/dev/null
bzip2 -d /tmp/restic.bz2
mv /tmp/restic /usr/local/bin/restic
chmod 0755 /usr/local/bin/restic

echo "Install Scaleway scw cli"
export SCW_VERSION=$(curl -sL "https://api.github.com/repos/scaleway/scaleway-cli/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
wget "https://github.com/scaleway/scaleway-cli/releases/download/v${SCW_VERSION}/scaleway-cli_${SCW_VERSION}_linux_amd64" -O /usr/local/bin/scw >/dev/null
chmod 0755 /usr/local/bin/scw

echo "Install Hadolint"
export HADOLINT_VERSION=$(curl -sL "https://api.github.com/repos/hadolint/hadolint/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
wget "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" -O /usr/local/bin/hadolint >/dev/null
chmod 0755 /usr/local/bin/hadolint

echo "Install bat"
latest_release_url="https://github.com/sharkdp/bat/releases"
TAG=$(curl -Ls $latest_release_url | grep 'href="/sharkdp/bat/releases/tag/v.' | grep -v beta | grep -v rc | head -n 1 | cut -d '"' -f 6 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}' | cut -d 'v' -f2)
curl ${CURL_OPTS} -L "https://github.com/sharkdp/bat/releases/download/v${TAG}/bat_${TAG}_amd64.deb" \
    -o /tmp/bat.deb >/dev/null
dpkg -i /tmp/bat.deb
rm /tmp/bat.deb

echo "Install cosign"
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
mv cosign-linux-amd64 /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

echo "Install dive"
export DIVE_VERSION=$(curl -sL "https://api.github.com/repos/wagoodman/dive/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -OL https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_linux_amd64.deb
sudo apt install ./dive_${DIVE_VERSION}_linux_amd64.deb

echo "Install oras"
export ORAS_VERSION=$(curl https://api.github.com/repos/oras-project/oras/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -LO "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_linux_amd64.tar.gz"
mkdir -p oras-install/
tar -zxf oras_${ORAS_VERSION}_*.tar.gz -C oras-install/
sudo mv oras-install/oras /usr/local/bin/
rm -rf oras_${ORAS_VERSION}_*.tar.gz oras-install/

echo "Install kind"
export KIND_VERSION=$(curl https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-arm64
chmod 0755 /usr/local/bin/kind

echo "Install Postgresql client"
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /usr/share/keyrings/postgresql.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | sudo tee -a /etc/apt/sources.list.d/pgdg.list
apt-get update >/dev/null
apt-get install -y postgresql-client

echo "install testssl.sh"
git clone --depth 1 https://github.com/drwetter/testssl.sh.git /usr/local/testssl.sh

echo "Set shell to zsh"
chsh -s /usr/bin/zsh
chsh -s /usr/bin/zsh coder

echo "mkdir -p \$HOME/.oh-my-zsh/cache" >> /etc/zsh/zshrc
echo "export ZSH_CACHE_DIR=\$HOME/.oh-my-zsh/cache" >> /etc/zsh/zshrc
echo "plugins=(git kubectl docker ansible helm sudo pass kubectx kube-ps1 terraform fd)" >> /etc/zsh/zshrc
echo "ZSH_THEME=robbyrussell" >> /etc/zsh/zshrc
echo "export ZSH=/usr/share/oh-my-zsh" >> /etc/zsh/zshrc
echo "source \$ZSH/oh-my-zsh.sh" >> /etc/zsh/zshrc
echo "autoload -U +X bashcompinit && bashcompinit" >> /etc/zsh/zshrc
echo "complete -o nospace -C /usr/local/bin/packer packer" >> /etc/zsh/zshrc
echo "complete -o nospace -C /usr/local/bin/terraform terraform" >> /etc/zsh/zshrc
echo "complete -o nospace -C /usr/local/bin/vault vault" >> /etc/zsh/zshrc
echo "eval \"\$(scw autocomplete script shell=zsh)\"" >> /etc/zsh/zshrc
echo "PROMPT='\$(kube_ps1)'\$PROMPT" >> /etc/zsh/zshrc
echo "export PATH=\$HOME/bin:\$HOME/.local/bin:/usr/local/testssl.sh:\${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH" >> /etc/zsh/zshrc

echo "Install NodeJS and NPM"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

echo "Cleaning"
rm -rf /var/lib/apt/lists/* /tmp/*