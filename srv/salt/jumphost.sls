configure-docker:
      cmd.run:
        - name: |
            usermod -aG docker sles
            usermod -aG docker root
            chown root:docker /var/run/docker.sock
            modprobe br_netfilter
            sysctl net.bridge.bridge-nf-call-iptables=1
        - require:
            - docker-install

pre-configure-docker:
      file.managed:
          - names:
              - /etc/sysctl.d/90-rancher.conf:
                  - user: root
                  - group: root
                  - mode: 644
                  - contents: 'net.bridge.bridge-nf-call-iptables=1'
              - /etc/modules-load.d/modules-rancher.conf:
                  - user: root
                  - group: root
                  - mode: 644
                  - contents: 'br_netfilter'

add-product-containers-docker:
     cmd.run:
        - name: 'SUSEConnect -p sle-module-containers/15.3/x86_64'

docker-install:
  pkg.installed:
    - name: docker
    - require:
      - add-product-containers-docker

docker:
  service.running:
    - enable: True
    - watch:
      - pkg: docker
      - configure-docker
    - require:
      - pkg: docker
      - configure-docker
