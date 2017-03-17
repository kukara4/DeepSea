
begin:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.events.begin_prep

mines:
  salt.state:
    - tgt: '*'
    - sls: ceph.mines

sync:
  salt.state:
    - tgt: '*'
    - sls: ceph.sync

repo:
  salt.state:
    - tgt: '*'
    - sls: ceph.repo

common packages:
  salt.state:
    - tgt: '*'
    - sls: ceph.packages.common

{% if salt['saltutil.runner']('cephprocesses.check', roles=['mon']) == True %}

{% for host in salt.saltutil.runner('orderednodes.unique', cluster='ceph') %}

wait until the cluster has recovered before processing {{ host }}:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.wait
    - failhard: True

check if all processes are still running after processing {{ host }}:
  salt.state:
    - tgt: '*'
    - sls: ceph.cephprocesses
    - failhard: True

# After the last item in the iteration was processed the reactor 
# still sets ceph osd set noout. So setting this after is still necessary.
unset noout after processing {{ host }}:
  salt.function:
    - name: cmd.run
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - arg:
      - ceph osd unset noout
    - failhard: True

updating {{ host }}:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.updates
    - failhard: True

check if restart is needed for {{ host }}:
  salt.state:
    - tgt: {{ host }}
    - tgt_type: compound
    - sls: ceph.updates.restart
    - failhard: True

{% endfor %}

# After the last item in the iteration was processed the reactor 
# still sets ceph osd set noout. So setting this after is still necessary.
unset noout after processing:
  salt.function:
    - name: cmd.run
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - arg:
      - ceph osd unset noout
    - failhard: True

{% else %}

updates:
  salt.state:
    - tgt: '*'
    - sls: ceph.updates

{% endif %}

complete:
  salt.state:
    - tgt: {{ salt['pillar.get']('master_minion') }}
    - sls: ceph.events.complete_prep
