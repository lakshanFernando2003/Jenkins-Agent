# ----------------------------
# Dockerfile for unit_test_container_4
# ----------------------------
FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

# ----------------------------
# Install dependencies
# ----------------------------
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg \
    unzip \
    lsb-release \
    software-properties-common \
    openssh-server \
    sudo \
    git \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Install OpenJDK 21 (Adoptium)
# ----------------------------
RUN wget https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.8%2B9/OpenJDK21U-jdk_x64_linux_hotspot_21.0.8_9.tar.gz -P /tmp && \
    tar -xzf /tmp/OpenJDK21U-jdk_x64_linux_hotspot_21.0.8_9.tar.gz -C /opt/ && \
    ln -s /opt/jdk-21.0.8+9 /opt/jdk-21 && \
    rm /tmp/OpenJDK21U-jdk_x64_linux_hotspot_21.0.8_9.tar.gz

ENV JAVA_HOME=/opt/jdk-21
ENV PATH=$JAVA_HOME/bin:$PATH

# ----------------------------
# Install Gradle 8.7
# ----------------------------
RUN wget https://services.gradle.org/distributions/gradle-8.7-bin.zip -P /tmp && \
    unzip -d /opt/gradle /tmp/gradle-8.7-bin.zip && \
    ln -s /opt/gradle/gradle-8.7 /opt/gradle/latest && \
    rm /tmp/gradle-8.7-bin.zip

ENV GRADLE_HOME=/opt/gradle/latest
ENV PATH=$GRADLE_HOME/bin:$PATH

# ----------------------------
# Install PostgreSQL 15
# ----------------------------
RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list && \
    wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && apt-get install -y \
    postgresql-15 \
    postgresql-client-15 && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/lib/postgresql/15/bin:$PATH"

# ----------------------------
# Initialize PostgreSQL database
# ----------------------------
RUN mkdir -p /var/lib/postgresql/data && chown -R postgres:postgres /var/lib/postgresql
USER postgres
RUN initdb -D /var/lib/postgresql/data
USER root
RUN chown -R postgres:postgres /var/lib/postgresql/data

EXPOSE 5432

# ----------------------------
# Configure SSH
# ----------------------------
RUN mkdir /var/run/sshd && \
    echo 'root:root' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' /etc/pam.d/sshd

EXPOSE 22

# ----------------------------
# Startup script to launch PostgreSQL + SSH
# ----------------------------
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Initializing PostgreSQL..."\n\
chown -R postgres:postgres /var/lib/postgresql/data\n\
echo "Starting PostgreSQL..."\n\
su - postgres -c "/usr/lib/postgresql/15/bin/postgres -D /var/lib/postgresql/data &"\n\
sleep 3\n\
echo "Starting SSHD..."\n\
/usr/sbin/sshd -D' > /start.sh && chmod +x /start.sh

# ----------------------------
# Default startup command
# ----------------------------
CMD ["/bin/bash", "/start.sh"]
