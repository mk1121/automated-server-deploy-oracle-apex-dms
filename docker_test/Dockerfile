FROM almalinux:8

# Install dependencies needed for the scripts
RUN dnf install -y \
    sudo \
    which \
    procps \
    unzip \
    tar \
    passwd \
    openssh-clients \
    && dnf clean all

# Mock firewall-cmd because it fails in Docker without privileged/host networking
# and even then can be tricky. We just want to verify the script flow.
RUN echo '#!/bin/bash' > /usr/bin/firewall-cmd && \
    echo 'echo "Mock firewall-cmd: $*"' >> /usr/bin/firewall-cmd && \
    chmod +x /usr/bin/firewall-cmd

# Mock setenforce/SELinux
RUN echo '#!/bin/bash' > /usr/sbin/setenforce && \
    chmod +x /usr/sbin/setenforce

WORKDIR /root
CMD ["/bin/bash"]
