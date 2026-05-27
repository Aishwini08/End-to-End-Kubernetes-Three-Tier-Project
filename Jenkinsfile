---
- name: Configure Jenkins Server
  hosts: jenkins
  become: true

  vars_files:
    - secrets.yml

  vars:
    github_token: "{{ vault_github_token }}"
    github_username: "Aishwini08"
    sonar_token: "{{ vault_sonar_token }}"
    aws_account_id: "{{ vault_aws_account_id }}"
    aws_region: "ap-south-1"

  tasks:
    - name: Remove stale Jenkins repo if present
      file:
        path: "{{ item }}"
        state: absent
      loop:
        - /etc/apt/sources.list.d/jenkins.list
        - /etc/apt/keyrings/jenkins-keyring.asc

    - name: Update apt cache
      apt:
        update_cache: yes

    - name: Install dependencies
      apt:
        name:
          - curl
          - gnupg
          - wget
          - fontconfig
          - openjdk-21-jre
          - docker.io
          - unzip
        state: present

    - name: Ensure /etc/apt/keyrings directory exists
      file:
        path: /etc/apt/keyrings
        state: directory
        mode: '0755'

    - name: Add Jenkins GPG key
      shell: |
        wget -O /etc/apt/keyrings/jenkins-keyring.asc \
          https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

    - name: Add Jenkins repository
      shell: |
        echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" \
          | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

    - name: Update apt cache after Jenkins repo
      apt:
        update_cache: yes

    - name: Install Jenkins
      apt:
        name: jenkins
        state: present

    - name: Start and enable Docker
      systemd:
        name: docker
        state: started
        enabled: yes

    - name: Add ubuntu user to docker group
      user:
        name: ubuntu
        groups: docker
        append: yes

    - name: Add jenkins user to docker group
      user:
        name: jenkins
        groups: docker
        append: yes

    - name: Install kubectl
      shell: |
        curl -Lo /tmp/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
      args:
        creates: /usr/local/bin/kubectl

    - name: Install Helm
      shell: |
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      args:
        creates: /usr/local/bin/helm

    - name: Install AWS CLI
      shell: |
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
        unzip /tmp/awscliv2.zip -d /tmp/
        /tmp/aws/install
      args:
        creates: /usr/local/bin/aws

    - name: Install Trivy
      shell: |
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
      args:
        creates: /usr/local/bin/trivy

    # FIX: Updated from v9.0.9 (EOL) to v10.1.0
    - name: Install OWASP Dependency Check
      shell: |
        wget https://github.com/jeremylong/DependencyCheck/releases/download/v10.1.0/dependency-check-10.1.0-release.zip \
          -O /tmp/dc.zip
        unzip /tmp/dc.zip -d /opt/
        chmod +x /opt/dependency-check/bin/dependency-check.sh
        ln -sf /opt/dependency-check/bin/dependency-check.sh /usr/local/bin/dependency-check
      args:
        creates: /usr/local/bin/dependency-check

    # FIX: Check docker ps directly instead of a separate marker file task
    - name: Run SonarQube container
      shell: |
        if docker ps -a --format '{{.Names}}' | grep -q '^sonarqube$'; then
          docker start sonarqube 2>/dev/null || true
        else
          docker run -d \
            --name sonarqube \
            --restart always \
            -p 9000:9000 \
            -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
            sonarqube:lts-community
        fi

    # FIX: Added html-publisher plugin required by Jenkinsfile publishHTML step
    - name: Install JCasC and required plugins
      shell: |
        JENKINS_HOME=/var/lib/jenkins
        mkdir -p $JENKINS_HOME/plugins

        curl -sL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.12.13/jenkins-plugin-manager-2.12.13.jar \
          -o /tmp/jenkins-plugin-manager.jar

        java -jar /tmp/jenkins-plugin-manager.jar \
          --war /usr/share/jenkins/jenkins.war \
          --plugin-download-directory $JENKINS_HOME/plugins \
          --plugins \
            configuration-as-code:latest \
            git:latest \
            workflow-aggregator:latest \
            github:latest \
            credentials-binding:latest \
            docker-workflow:latest \
            job-dsl:latest \
            pipeline-github:latest \
            sonar:latest \
            aws-credentials:latest \
            pipeline-aws:latest \
            html-publisher:latest

        chown -R jenkins:jenkins $JENKINS_HOME/plugins
      args:
        creates: /var/lib/jenkins/plugins/configuration-as-code.jpi

    - name: Get Jenkins public IP
      shell: curl -s http://169.254.169.254/latest/meta-data/public-ipv4
      register: jenkins_ip

    - name: Write JCasC configuration
      copy:
        dest: /var/lib/jenkins/jenkins.yaml
        owner: jenkins
        group: jenkins
        mode: '0644'
        content: |
          jenkins:
            systemMessage: "Jenkins configured automatically via JCasC"
            numExecutors: 2
            securityRealm:
              local:
                allowsSignup: false
                users:
                  - id: "admin"
                    password: "admin123"
            authorizationStrategy:
              loggedInUsersCanDoAnything:
                allowAnonymousRead: false
            location:
              url: "http://{{ jenkins_ip.stdout }}:8080/"

          credentials:
            system:
              domainCredentials:
                - credentials:
                    - usernamePassword:
                        scope: GLOBAL
                        id: "github-credentials"
                        description: "GitHub credentials"
                        username: "{{ github_username }}"
                        password: "{{ github_token }}"
                    # FIX: was "sonar-token" — must match Jenkinsfile credentialsId
                    - string:
                        scope: GLOBAL
                        id: "sonarqube-token"
                        description: "SonarQube token"
                        secret: "{{ sonar_token }}"
                    - string:
                        scope: GLOBAL
                        id: "aws-account-id"
                        description: "AWS Account ID for ECR"
                        secret: "{{ aws_account_id }}"

          tool:
            sonarRunnerInstallation:
              installations:
                - name: "SonarScanner"
                  properties:
                    - installSource:
                        installers:
                          - sonarRunnerInstaller:
                              id: "5.0.1.3006"

          unclassified:
            sonarGlobalConfiguration:
              buildWrapperEnabled: true
              installations:
                - name: "SonarQube"
                  serverUrl: "http://{{ jenkins_ip.stdout }}:9000"
                  credentialsId: "sonarqube-token"

          jobs:
            - script: >
                pipelineJob('three-tier-pipeline') {
                  triggers {
                    githubPush()
                  }
                  definition {
                    cpsScm {
                      scm {
                        git {
                          remote {
                            url('https://github.com/Aishwini08/End-to-End-Kubernetes-Three-Tier-Project.git')
                            credentials('github-credentials')
                          }
                          branch('*/main')
                        }
                      }
                      scriptPath('Jenkinsfile')
                    }
                  }
                }

    # FIX: Drop-in override instead of editing package-managed service file
    - name: Create systemd drop-in directory for Jenkins
      file:
        path: /etc/systemd/system/jenkins.service.d
        state: directory
        mode: '0755'

    - name: Write JCasC drop-in override for Jenkins systemd
      copy:
        dest: /etc/systemd/system/jenkins.service.d/casc.conf
        mode: '0644'
        content: |
          [Service]
          Environment="JAVA_OPTS=-Djava.awt.headless=true -Dcasc.jenkins.config=/var/lib/jenkins/jenkins.yaml"

    # FIX: Use copy module — shell+creates guard doesn't update stale content
    - name: Skip Jenkins setup wizard - install version marker
      copy:
        dest: /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion
        content: "2.0\n"
        owner: jenkins
        group: jenkins
        mode: '0644'

    - name: Skip Jenkins setup wizard - upgrade wizard state
      copy:
        dest: /var/lib/jenkins/jenkins.install.UpgradeWizard.state
        content: "2.0\n"
        owner: jenkins
        group: jenkins
        mode: '0644'

    - name: Reload systemd
      shell: systemctl daemon-reload

    # FIX: Added enabled: yes — was restarted but never enabled for auto-start
    - name: Restart and enable Jenkins
      systemd:
        name: jenkins
        state: restarted
        enabled: yes

    # FIX: /api/json with credentials instead of /login
    # /login returns 200 even when JCasC has failed — false positive
    - name: Wait for Jenkins to be fully ready
      uri:
        url: "http://localhost:8080/api/json"
        method: GET
        user: admin
        password: admin123
        force_basic_auth: yes
        status_code: 200
      register: result
      until: result.status == 200
      retries: 30
      delay: 15