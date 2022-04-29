base:
  'roles:jumphost':
    - match: grain
    - jumphost
  'roles:rancher':
    - match: grain
    - rancher
  'roles:rke2':
    - match: grain
    - rke2
  '*':
    - requirements
    - ntp
    - users