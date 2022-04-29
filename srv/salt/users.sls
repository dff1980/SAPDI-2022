sles:
  user.present:
    - fullname: SUSE Rancher admin user
    - shell: /bin/bash
    - home: /home/sles
    - password: $5$F9e7kH4IkMBo$dU3oC/uXcmr6LlsqYHU1X5s.yDim0bN/6PD022jPWyA # mkpasswd -m sha-256 (whois)
    - groups:
      - users

sles-ssh-keys:
  ssh_auth.present:
    - user: sles
    - source: salt://ssh/id_rsa.pub
    - config: '%h/.ssh/authorized_keys'
    - require:
      - user: sles