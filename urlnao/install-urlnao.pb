---
# This is an playbook to set up urlnao
# use "-e rebuild=true" to force update of the urlnao binary

- vars:
    prefix: /usr/local
    uname: urlnao
    gname: www

  hosts: localhost
  vars_files:
  - config.yml

  gather_facts: no
  tasks:
  - name: Check if binary exists
    stat:
      path: "{{ prefix }}/sbin/urlnao"
    register: stat_result

  - name: Build if necessary
    block:
      - name: Git checkout
        git:
          repo: 'https://github.com/WilliButz/urlnao'
          dest: urlnao
        register: git

      - name: Build
        shell: 
          cmd: cargo build --release
          chdir: urlnao
        when: git.changed or rebuild is defined

      - name: Install
        become: yes
        copy:
          src: urlnao/target/release/urlnao
          dest: "{{ prefix }}/sbin/urlnao"
          mode: 0755
          owner: root
          group: wheel
    when: not stat_result.stat.exists or rebuild is defined

  - name: Create user
    become: yes
    user:
      name: "{{ uname }}"
      shell: /usr/sbin/nologin
      home: "{{ prefix }}/var/lib/urlnao"
      password: '*'
      comment: Weechat File Upload
      uid: 348
      group: "{{ gname }}"

  - name: startup file
    become: yes
    template:
      src: rc.d.j2
      dest: "{{ prefix }}/etc/rc.d/urlnao"
      owner: root
      group: wheel
      mode: 0755

  - name: nginx conf file
    become: yes
    template:
      src: nginx-urlnao.conf.j2
      dest: "{{ prefix }}/etc/nginx/servers/urlnao.conf"
      owner: root
      group: wheel
      mode: 0644

  - name: nginx htpasswd
    become: yes
    lineinfile:
      path: "{{prefix}}/etc/nginx/urlnao.htpasswd"
      regexp: "^{{ authuser }}:"
      line: "{{authuser}}:{{authpass|password_hash('sha512', 42 | random(seed=webname) | string)}}"
      owner: root
      group: www
      mode: 0640
      create: yes

