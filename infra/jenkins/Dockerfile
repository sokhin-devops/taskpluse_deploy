# Jenkins for TaskPluse: the official LTS image plus the tools the pipelines run.
# Built by scripts/infra-up.sh (docker compose build). Every download is checked
# against the checksum its project publishes before it is installed.
FROM jenkins/jenkins:2.580.1-lts-jdk21

ARG KUBECTL_VERSION=1.36.5
ARG HELM_VERSION=4.3.0
ARG TRIVY_VERSION=0.76.0
ARG GITLEAKS_VERSION=8.30.1

USER root

# Docker CLI only - no Docker daemon. Builds run on the host's Docker through
# the mounted socket (see infra/compose.yaml).
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && install -m 0755 -d /etc/apt/keyrings \
 && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
 && echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/tools

# kubectl and Helm - the same versions used by hand from WSL.
RUN curl -fsSLO "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && echo "$(curl -fsSL https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256)  kubectl" | sha256sum -c - \
 && install -m 0755 kubectl /usr/local/bin/kubectl \
 && curl -fsSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
 && curl -fsSLO "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" \
 && sha256sum -c "helm-v${HELM_VERSION}-linux-amd64.tar.gz.sha256sum" \
 && tar -xzf "helm-v${HELM_VERSION}-linux-amd64.tar.gz" linux-amd64/helm \
 && install -m 0755 linux-amd64/helm /usr/local/bin/helm \
 && rm -rf /tmp/tools/*

# Trivy (image and dependency vulnerability scanner) and Gitleaks (secrets in git).
RUN curl -fsSLO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" \
 && curl -fsSLO "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_checksums.txt" \
 && sha256sum --ignore-missing -c "trivy_${TRIVY_VERSION}_checksums.txt" \
 && tar -xzf "trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz" trivy \
 && install -m 0755 trivy /usr/local/bin/trivy \
 && curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
 && curl -fsSLO "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_checksums.txt" \
 && sha256sum --ignore-missing -c "gitleaks_${GITLEAKS_VERSION}_checksums.txt" \
 && tar -xzf "gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" gitleaks \
 && install -m 0755 gitleaks /usr/local/bin/gitleaks \
 && rm -rf /tmp/tools/*

WORKDIR /

# Only the plugins the pipelines need - each plugin is code running inside Jenkins.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Configured from infra/jenkins/casc.yaml, never through the setup wizard.
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc.yaml

USER jenkins
