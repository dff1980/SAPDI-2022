/etc/chrony.d/ntp.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://main/ntp.conf
    - require:
      - chronyd-install

chrony-pool-suse-remove:
  pkg.purged:
    - name: chrony-pool-suse

chronyd-install:
  pkg.installed:
    - names:
      - chrony-pool-empty
      - chrony
    - require:
        - chrony-pool-suse-remove

chronyd:
  service.running:
    - enable: True
    - watch:
      - pkg: chrony
      - file: /etc/chrony.d/ntp.conf
    - require:
      - pkg: chrony
      - file: /etc/chrony.d/ntp.conf