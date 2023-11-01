#!/bin/bash
set -euo pipefail
cd /tmp
# shellcheck disable=SC2034
DEBIAN_FRONTEND=noninteractive

echo "Install tools"
apt-get update >/dev/null
apt-get dist-upgrade -y
apt-get install -y --no-install-recommends dumb-init man sudo locales procps lsb-release vim pwgen jq wget curl unzip software-properties-common gpg gettext ca-certificates openssh-client git bzip2 zsh
curl -sL --fail --show-error https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | tee /usr/share/keyrings/trivy.gpg > /dev/null
echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb buster main" | tee -a /etc/apt/sources.list.d/trivy.list
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg
chmod a+r /usr/share/keyrings/docker.gpg
# shellcheck source=/dev/null
echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(source /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update >/dev/null
apt-get install -y --no-install-recommends skopeo pass fonts-powerline htop netcat-openbsd uuid-runtime dnsutils exa fd-find trivy iproute2 nmap iperf3 docker-ce-cli docker-buildx-plugin docker-compose-plugin golang shellcheck python3-pip python3-setuptools python3-ldap python3-docker python3-venv twine python3-psycopg2 gcc python3-dev

# https://wiki.debian.org/Locale#Manually
sed -i "s/# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen 
locale-gen

# For AMD64 / x86_64
[ "$(uname -m)" = x86_64 ] && ARCH="amd64"
# For ARM64
[ "$(uname -m)" = aarch64 ] && ARCH="arm64"
OS=$(uname |tr '[:upper:]' '[:lower:]')

echo "Install Ansible and ansible-modules-hashivault"
# https://www.linuxuprising.com/2023/03/next-debianubuntu-releases-will-likely.html?m=1
export PIP_BREAK_SYSTEM_PACKAGES=1
pip3 install --no-cache-dir ansible ansible-modules-hashivault openshift passlib hvac elasticsearch virtualenv ipykernel checkov opensearch-py

ln -s "$(which fdfind)" /usr/local/bin/fd

echo "Install Oh My Zsh"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
mv /root/.oh-my-zsh /usr/share/oh-my-zsh

echo "Install kubectl"
curl -sL --fail --show-error "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/${OS}/${ARCH}/kubectl" -o /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl

echo "Install helm"
HELM_VERSION=$(curl -sL https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name)
HELM_DIST="helm-$HELM_VERSION-$OS-$ARCH.tar.gz"
DOWNLOAD_URL="https://get.helm.sh/$HELM_DIST"
CHECKSUM_URL="$DOWNLOAD_URL.sha256"
HELM_TMP_ROOT="$(mktemp -dt helm-installer-XXXXXX)"
HELM_TMP_FILE="$HELM_TMP_ROOT/$HELM_DIST"
HELM_SUM_FILE="$HELM_TMP_ROOT/$HELM_DIST.sha256"
if type "curl" > /dev/null; then
  curl -SsL "$CHECKSUM_URL" -o "$HELM_SUM_FILE"
elif type "wget" > /dev/null; then
  curl -sL --fail --show-error -o "$HELM_SUM_FILE" "$CHECKSUM_URL"
fi
if type "curl" > /dev/null; then
  curl -SsL "$DOWNLOAD_URL" -o "$HELM_TMP_FILE"
elif type "wget" > /dev/null; then
  curl -sL --fail --show-error -o "$HELM_TMP_FILE" "$DOWNLOAD_URL"
fi
# installFile verifies the SHA256 for the file, then unpacks and
# installs it.
HELM_TMP="$HELM_TMP_ROOT/helm"
sum=$(openssl sha1 -sha256 "${HELM_TMP_FILE}" | awk '{print $2}')
expected_sum=$(cat "${HELM_SUM_FILE}")
if [ "$sum" != "$expected_sum" ]; then
  echo "SHA sum of ${HELM_TMP_FILE} does not match. Aborting."
  exit 1
fi
mkdir -p "$HELM_TMP"
tar xf "$HELM_TMP_FILE" -C "$HELM_TMP"
HELM_TMP_BIN="$HELM_TMP/$OS-$ARCH/helm"
cp "$HELM_TMP_BIN" "/usr/local/bin"

echo "Install Packer"
PACKER_VERSION=$(curl -sL "https://api.github.com/repos/hashicorp/packer/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_${OS}_${ARCH}.zip" -o /tmp/packer.zip
unzip /tmp/packer.zip >/dev/null
mv -f /tmp/packer /usr/local/bin/packer
rm /tmp/packer.zip

echo "Install Terraform"
TERRAFORM_VERSION=$(curl -sL "https://api.github.com/repos/hashicorp/terraform/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_${OS}_${ARCH}.zip" -o /tmp/terraform.zip
unzip terraform.zip >/dev/null
mv -f /tmp/terraform /usr/local/bin/terraform
chown 0755 /usr/local/bin/terraform
rm /tmp/terraform.zip

echo "Install Vault"
VAULT_VERSION=$(curl -sL "https://api.github.com/repos/hashicorp/vault/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_${OS}_${ARCH}.zip" -o /tmp/vault.zip
unzip /tmp/vault.zip >/dev/null
mv -f /tmp/vault /usr/local/bin/vault
chown 0755 /usr/local/bin/vault
rm /tmp/vault.zip

echo "Install Minio mc client"
curl -sL --fail --show-error "https://dl.min.io/client/mc/release/${OS}-${ARCH}/mc" -o /usr/local/bin/mc
chmod 0755 /usr/local/bin/mc

echo "Install Restic cli"
RESTIC_VERSION=$(curl -sL "https://api.github.com/repos/restic/restic/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://github.com/restic/restic/releases/download/v${RESTIC_VERSION}/restic_${RESTIC_VERSION}_${OS}_${ARCH}.bz2" -o /tmp/restic.bz2
bzip2 -d /tmp/restic.bz2
mv /tmp/restic /usr/local/bin/restic
chmod 0755 /usr/local/bin/restic

echo "Install Scaleway scw cli"
SCW_VERSION=$(curl -sL "https://api.github.com/repos/scaleway/scaleway-cli/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://github.com/scaleway/scaleway-cli/releases/download/v${SCW_VERSION}/scaleway-cli_${SCW_VERSION}_${OS}_${ARCH}" -o /usr/local/bin/scw
chmod 0755 /usr/local/bin/scw

echo "Install Hadolint"
HADOLINT_VERSION=$(curl -sL "https://api.github.com/repos/hadolint/hadolint/releases/latest" | jq -r .tag_name)
[ "$(uname -m)" = x86_64 ] && curl -sL --fail --show-error "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint
[ "$(uname -m)" = aarch64 ] && curl -sL --fail --show-error "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-arm64" -o /usr/local/bin/hadolint
chmod 0755 /usr/local/bin/hadolint

echo "Install cosign"
curl -sLO --fail --show-error "https://github.com/sigstore/cosign/releases/latest/download/cosign-${OS}-${ARCH}"
mv "cosign-${OS}-${ARCH}" /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign

echo "Install dive"
DIVE_VERSION=$(curl -sL "https://api.github.com/repos/wagoodman/dive/releases/latest" | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sLO --fail --show-error "https://github.com/wagoodman/dive/releases/download/v${DIVE_VERSION}/dive_${DIVE_VERSION}_${OS}_${ARCH}.deb"
apt install "./dive_${DIVE_VERSION}_${OS}_${ARCH}.deb"
rm "./dive_${DIVE_VERSION}_${OS}_${ARCH}.deb"

echo "Install oras"
ORAS_VERSION=$(curl -sL https://api.github.com/repos/oras-project/oras/releases/latest | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sLO --fail --show-error "https://github.com/oras-project/oras/releases/download/v${ORAS_VERSION}/oras_${ORAS_VERSION}_${OS}_${ARCH}.tar.gz"
mkdir -p oras-install/
tar -zxf "oras_${ORAS_VERSION}_${OS}_${ARCH}.tar.gz" -C oras-install/
mv oras-install/oras /usr/local/bin/
rm -rf "oras_${ORAS_VERSION}_${OS}_${ARCH}.tar.gz" oras-install/

echo "Install kind"
KIND_VERSION=$(curl -sL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error -o /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-${OS}-${ARCH}"
chmod 0755 /usr/local/bin/kind

echo "Install manifest-tool"
MANIFEST_VERSION=$(curl -sL https://api.github.com/repos/estesp/manifest-tool/releases/latest | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error -o /tmp/binaries-manifest-tool.tar.gz "https://github.com/estesp/manifest-tool/releases/download/v${MANIFEST_VERSION}/binaries-manifest-tool-${MANIFEST_VERSION}.tar.gz"
tar -zxf /tmp/binaries-manifest-tool.tar.gz "manifest-tool-${OS}-${ARCH}"
mv "manifest-tool-${OS}-${ARCH}" "/usr/local/bin/manifest-tool"
chmod 0755 /usr/local/bin/manifest-tool
rm -rf /tmp/binaries-manifest-tool.tar.gz

echo "install testssl.sh"
git clone --depth 1 https://github.com/drwetter/testssl.sh.git /usr/local/testssl.sh
chmod 0755 /usr/local/testssl.sh

echo "Install krew"
KREW="krew-${OS}_${ARCH}"
curl -sL --fail --show-error "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" -o /tmp/krew.tar.gz
tar zxvf "krew.tar.gz" -C /tmp/ >/dev/null
mv -f "/tmp/krew-linux_${ARCH}" /usr/local/bin/krew
chown 0755 /usr/local/bin/krew
rm /tmp/krew.tar.gz /tmp/LICENSE

echo "Install Gadget"
GADGET_VERSION=$(curl -sL https://api.github.com/repos/inspektor-gadget/inspektor-gadget/releases/latest | jq -r .tag_name)
curl -sL --fail --show-error "https://github.com/inspektor-gadget/inspektor-gadget/releases/download/${GADGET_VERSION}/kubectl-gadget-${OS}-${ARCH}-${GADGET_VERSION}.tar.gz" -o /tmp/kubectl-gadget.tar.gz
tar zxf /tmp/kubectl-gadget.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/kubectl-gadget /usr/local/bin/kubectl-gadget
chown 0755 /usr/local/bin/kubectl-gadget
rm /tmp/kubectl-gadget.tar.gz /tmp/LICENSE

echo "Install k9s"
K9S_VERSION=$(curl -sL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)
curl -sL --fail --show-error "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${OS}_${ARCH}.tar.gz" -o /tmp/k9s.tar.gz
tar zxf /tmp/k9s.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/k9s /usr/local/bin/k9s
chown 0755 /usr/local/bin/k9s
rm /tmp/k9s.tar.gz

echo "Install popeye"
POPEYE_VERSION=$(curl -sL https://api.github.com/repos/derailed/popeye/releases/latest | jq -r .tag_name)
[ "$(uname -m)" = x86_64 ] && curl -sL --fail --show-error "https://github.com/derailed/popeye/releases/download/${POPEYE_VERSION}/popeye_${OS}_x86_64.tar.gz" -o /tmp/popeye.tar.gz
[ "$(uname -m)" = aarch64 ] && curl -sL --fail --show-error "https://github.com/derailed/popeye/releases/download/${POPEYE_VERSION}/popeye_${OS}_arm64.tar.gz" -o /tmp/popeye.tar.gz
tar zxf /tmp/popeye.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/popeye /usr/local/bin/popeye
chown 0755 /usr/local/bin/popeye
rm /tmp/popeye.tar.gz

echo "Install havener"
HAVENER_VERSION=$(curl -sL https://api.github.com/repos/homeport/havener/releases/latest | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://github.com/homeport/havener/releases/download/v${HAVENER_VERSION}/havener_${HAVENER_VERSION}_${OS}_${ARCH}.tar.gz" \
    -o /tmp/havener.tar.gz
tar zxf /tmp/havener.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/havener /usr/local/bin/havener
chown 0755 /usr/local/bin/havener
rm /tmp/havener.tar.gz

echo "Install kubectx and kubens"
KUBECTX_VERSION=$(curl -sL https://api.github.com/repos/ahmetb/kubectx/releases/latest | jq -r .tag_name)
curl -sL --fail --show-error "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubectx_${KUBECTX_VERSION}_${OS}_x86_64.tar.gz" \
    -o /tmp/kubectx.tar.gz
tar zxf /tmp/kubectx.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/kubectx /usr/local/bin/kubectx
chown 0755 /usr/local/bin/kubectx
rm /tmp/kubectx.tar.gz
curl -sL --fail --show-error "https://github.com/ahmetb/kubectx/releases/download/${KUBECTX_VERSION}/kubens_${KUBECTX_VERSION}_${OS}_x86_64.tar.gz" \
    -o /tmp/kubens.tar.gz
tar zxf /tmp/kubens.tar.gz -C /tmp/ >/dev/null
mv -f /tmp/kubens /usr/local/bin/kubens
chown 0755 /usr/local/bin/kubens
rm /tmp/kubens.tar.gz

echo "Install duf"
DUF_VERSION=$(curl -sL https://api.github.com/repos/muesli/duf/releases/latest | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://github.com/muesli/duf/releases/download/v${DUF_VERSION}/duf_${DUF_VERSION}_${OS}_${ARCH}.deb" \
    -o /tmp/duf.deb
dpkg -i /tmp/duf.deb
rm /tmp/duf.deb

echo "Install bat"
BAT_VERSION=$(curl -sL https://api.github.com/repos/sharkdp/bat/releases/latest | jq -r .tag_name | sed -E 's/v(.*)/\1/')
curl -sL --fail --show-error "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat_${BAT_VERSION}_${ARCH}.deb" \
    -o /tmp/bat.deb
dpkg -i /tmp/bat.deb
rm /tmp/bat.deb

echo "Install grype"
GRYPE_VERSION=$(curl -sL "https://api.github.com/repos/anchore/grype/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -sLO --fail --show-error "https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_${OS}_${ARCH}.deb"
apt install "./grype_${GRYPE_VERSION}_${OS}_${ARCH}.deb"
rm "./grype_${GRYPE_VERSION}_${OS}_${ARCH}.deb"

echo "Install syft"
SYFT_VERSION=$(curl -sL "https://api.github.com/repos/anchore/syft/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
curl -sLO --fail --show-error "https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_${OS}_${ARCH}.deb"
apt install "./syft_${SYFT_VERSION}_${OS}_${ARCH}.deb"
rm "./syft_${SYFT_VERSION}_${OS}_${ARCH}.deb"

echo "Install Postgresql client"
curl -sL --fail --show-error https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor > /usr/share/keyrings/postgresql.gpg
echo "deb [signed-by=/usr/share/keyrings/postgresql.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee -a /etc/apt/sources.list.d/pgdg.list
apt-get update >/dev/null
apt-get install -y postgresql-client

adduser --gecos '' --disabled-password coder
echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

curl -sL --fail --show-error "https://github.com/boxboat/fixuid/releases/download/v0.5/fixuid-0.5-${OS}-${ARCH}.tar.gz" | tar -C /usr/local/bin -xzf -
chown root:root /usr/local/bin/fixuid
chmod 4755 /usr/local/bin/fixuid
mkdir -p /etc/fixuid
printf "user: coder\ngroup: coder\n" > /etc/fixuid/config.yml

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
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
NODE_MAJOR=20
echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y nodejs

echo "Cleaning"
rm -rf /var/lib/apt/lists/* /tmp/*
