longhorn-requirements:
  pkg.installed:
    - pkgs:
      - nfs-client
      - nfs-kernel-server
      - xfsprogs
      - ceph-common
      - open-iscsi

iscsid:
  service.running:
    - enable: True
    - require:
      - longhorn-requirements