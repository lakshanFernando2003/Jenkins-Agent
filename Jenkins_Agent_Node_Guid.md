
---

# Jenkins Agent Container Setup (`unit_test_container_4`)

This document describes the end-to-end process of creating and configuring a new Jenkins agent container (`unit_test_container_4`) on **srv-04** and connecting it to the Jenkins master container running on **srv-08**.

---

## **Data to be Collected**

Before starting, gather all required network details, SSH credentials, and container paths from both the Jenkins master container and agent container. These details are essential for SSH-based communication between Jenkins master and the agent.

---

###  Jenkins Master (`srv-08`)

**Container:** `jenkins` (master)
**Purpose:** This is the main Jenkins instance that controls builds and connects to the remote agent.

#### Steps to Collect Information

1. **Find the container IP address**

   Used to verify internal networking and confirm Jenkins master’s reachable interface.

2. **Check the host network interfaces**

   Run the below command on the host (srv-08) to identify which interface/IP is reachable from the agent server.

3. **List available SSH keys**

   Check that the required private and public key files exist in Jenkins’ `.ssh` directory

4. **Display the Jenkins master public key**

   You will need this key to authorize access on the agent container.
   Copy this output later into the agent’s `authorized_keys`.

---

### 🧩 Jenkins Agent (`srv-04`)

**Container:** `unit_test_container_4`
**Purpose:** This container runs build/test workloads triggered by the Jenkins master.

If you have **not yet created the agent container**, refer to the next section “Build Docker Image”.

#### Steps to Collect Information

1. **Find the container IP address**

   This confirms the container’s internal network IP.

2. **Confirm the container is running**

   Ensures the container is active and healthy.

3. **Check port mappings**

   * Show SSH port mapping between host and container:

   * Show PostgreSQL port mapping (optional)

4. **Display network interfaces on host (srv-04)**

   To confirm host accessibility from srv-08

5. **Check active user inside container**

6. **Create Jenkins user and `.ssh` directory**

   If not already present, create the `jenkins` user inside `/home`, then set up the `.ssh` folder:

   This ensures correct ownership and permissions for SSH authentication.

7. **Verify authorized SSH keys file**

   If `/home/jenkins/.ssh/authorized_keys` does not exist, it will be created in the next step.

---

## **Build Docker Image**

### Requirements for the Agent Image

The agent image should include the following:

* Java 21
* Gradle 8.7
* PostgreSQL 15
* SSH server
* Git

### Steps

1. **Navigate to the working directory**

   ```bash
   cd /home/gotlilabs/lakshan_devops/unit_tests
   ```

2. **Create a Dockerfile for the new agent**

   ```bash
   nano Dockerfile.unit_test_container_4
   ```

3. **Add the Dockerfile content**

   ```
   # link: add the GitHub link to Dockerfile
   ```

4. **Build the image**

   ```bash
   docker build -t unit_test_image:v3 -f Dockerfile.unit_test_container_4 .
   ```

---

## **Create and Run the Container**

Run the new Jenkins agent container with proper resources and port mapping.

```bash
docker run -d --privileged -m 2g -p 5433:5432 -p 2224:22 --name unit_test_container_4 unit_test_image:v3
```

* `-m 2g` → Memory limit 2GB
* `--privileged` → Grants full privileges
* `-p 2224:22` → SSH exposed on host port `2224`
* `-p 5433:5432` → PostgreSQL exposed on host port `5433`

Verify that the container started correctly:

```bash
docker ps -a | grep unit_test_container_4
docker logs unit_test_container_4
```

---

## **Verify Installed Services**

Once inside the container, check installed dependencies and verify they are running correctly.

```bash
docker exec -it unit_test_container_4 /bin/bash

ps aux | grep postgres      # Verify PostgreSQL process
service ssh status          # Verify SSH service is active
java -version               # Verify Java installation
gradle -v                   # Verify Gradle installation
psql -U postgres -c "\l"    # List PostgreSQL databases
git --version               # Verify Git installation
```

---

## **Configure Jenkins Agent Connection**

Now we configure secure SSH-based communication between Jenkins master and agent.

---

### **1. Verify Host and Container IPs**

#### 🔹 Jenkins Master (srv-08)

**Purpose:** Confirm Jenkins master’s IP and locate SSH keys for authentication.

1. Find the container IP address:

   ```bash
   docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' jenkins
   ```

2. Identify which network interface is reachable by the agent:

   ```bash
   ip addr
   ```

3. Verify the SSH private/public key pair used for agent connections:

   ```bash
   ls -lrt /var/jenkins_home/.ssh  # verify jenkins_agent_key
   ```

4. Display and copy the public key to use later in the agent’s `authorized_keys`:

   ```bash
   cat /var/jenkins_home/.ssh/jenkins_agent_key.pub
   ```

---

#### 🔹 Jenkins Agent (srv-04)

**Purpose:** Ensure container is ready for SSH and properly configured to accept connections from the master.

1. Retrieve container IP address:

   ```bash
   docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' unit_test_container_4
   ```

2. Confirm container status:

   ```bash
   docker ps -a | grep unit_test_container_4
   ```

3. Check SSH and PostgreSQL port mappings:

   ```bash
   docker port unit_test_container_4 22
   docker port unit_test_container_4 5432
   ```

4. Display host network interfaces:

   ```bash
   ip addr
   ```

5. Verify user context inside container:

   ```bash
   docker exec -it unit_test_container_4 whoami
   ```

6. Check if the `authorized_keys` file already exists:

   ```bash
   docker exec -it unit_test_container_4 cat /home/jenkins/.ssh/authorized_keys
   ```

---

### **2. SSH Key Authentication Setup**

If the SSH directory or key files are missing, follow these steps.

1. **Create `.ssh` directory and set permissions**:

   ```bash
   docker exec -it unit_test_container_4 bash -c 'mkdir -p /home/jenkins/.ssh && chmod 700 /home/jenkins/.ssh'
   ```

2. **If no key pair exists on master or agent, generate one:**

   ```bash
   ssh-keygen -t rsa -b 4096 -f /var/jenkins_home/.ssh/jenkins_agent_key -C "jenkins-agent"
   ```

   This creates:

   * `/var/jenkins_home/.ssh/jenkins_agent_key` (private)
   * `/var/jenkins_home/.ssh/jenkins_agent_key.pub` (public)

3. **Add master’s public key to the agent’s authorized keys:**

   ```bash
   docker exec -it unit_test_container_4 bash -c 'echo "PASTE_MASTER_PUBLIC_KEY" >> /home/jenkins/.ssh/authorized_keys && chown -R jenkins:jenkins /home/jenkins/.ssh && chmod 600 /home/jenkins/.ssh/authorized_keys'
   ```

---

## **Manual Connectivity Tests**

Before configuring via Jenkins UI, confirm SSH connectivity manually.

### **From Jenkins Master (srv-08) → Agent (srv-04)**

```bash
ping -c 3 AGENT_IP
nc -vz AGENT_IP 22
nc -vz AGENT_IP 5432
ssh -i /var/jenkins_home/.ssh/jenkins_agent_key -p 2224 jenkins@AGENT_IP "echo OK"
```

### **From Agent → Master**

```bash
ping -c 3 MASTER_IP
nc -vz MASTER_IP 22
```

✅ **Expected Output:**
`OK` — confirms SSH key-based connection is successful.

## **Add Jenkins SSH Credentials**

Before linking the agent node, you must store the SSH private key in Jenkins credentials.

1. Go to **Manage Jenkins → Credentials → System → Global credentials (unrestricted)**
2. Click **Add Credentials**
3. Fill the form as follows:

   * **Kind:** SSH Username with private key
   * **Scope:** Global (Jenkins, nodes, items, all child items)
   * **Username:** `jenkins`
   * **Private Key:**

     * Select **Enter directly**
     * Paste the entire content of the master’s private key file:

       ```bash
       cat /var/jenkins_home/.ssh/jenkins_agent_key
       ```
   * **ID:** `jenkins_agent_key`
   * **Description:** `SSH key for Jenkins Agent (unit_test_container_4)`
4. Click **Create**

Once done, use this credential when configuring the node connection

---

---

## **Add Jenkins Node via GUI**

1. Navigate to **Manage Jenkins → Manage Nodes → New Node**
2. Enter node name: `unit_test_container_4`
3. Remote root directory: `/home/jenkins`
4. Labels (optional): `unit-test`
5. Launch method: **Launch agents via SSH**

   * **Host:** `AGENT_IP`
   * **Port:** `22`
   * **Credentials:** SSH private key (`jenkins_agent_key`)
   * **Host Key Verification Strategy:** *Non verifying (no check)* or *Known hosts file*
6. Click **Save and Launch**
7. The agent node should appear as **Online** under the Jenkins node list.

---
