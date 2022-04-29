rke-pre-configure:
      cmd.run:
        - name: |
            swapoff -a
            systemctl disable kdump --now
            systemctl disable firewalld --now

sshd:
  service.running:
    - enable: True

add-product-containers:
     cmd.run:
        - name: 'SUSEConnect -p sle-module-containers/15.3/x86_64'

add-module-basesystem:
  cmd.run:
    - name: 'SUSEConnect -p sle-module-basesystem/15.3/x86_64'

base-enhanced_base-install:
  pkg.installed:
    - pkgs:
      - patterns-base-enhanced_base
      - sudo
    - require:
      - add-module-basesystem

ip-forwarding-sysctl:
      cmd.run:
        - name: |
            sysctl net.ipv4.conf.all.forwarding=1
            sysctl net.ipv6.conf.all.forwarding=1

ip-forwarding:
      file.managed:
          - names:
              - /etc/sysctl.d/90-rancher.conf:
                  - user: root
                  - group: root
                  - mode: 644
                  - contents: |
                      net.ipv4.conf.all.forwarding=1
                      net.ipv6.conf.all.forwarding=1