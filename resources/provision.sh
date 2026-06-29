#!/bin/sh

set -exu

install_extra_packages() {
  pkg_add bash
  pkg_add curl
  pkg_add rust
  pkg_add git
  pkg_add rsync--
}

setup_sudo() {
  pkg_add sudo--

  cat <<EOF > /etc/sudoers
#includedir /etc/sudoers.d
EOF

# ?todo don't allow $SECONDARY_USER user to perform priv ops.

  mkdir -p /etc/sudoers.d
  cat <<EOF > "/etc/sudoers.d/$SECONDARY_USER"
Defaults:$SECONDARY_USER !requiretty
$SECONDARY_USER ALL=(ALL:ALL) ALL
EOF

  chmod 440 "/etc/sudoers.d/$SECONDARY_USER"
}

configure_boot_scripts() {
  cat <<EOF >> /etc/rc.local
RESOURCES_MOUNT_PATH='/mnt/resources'
#mkdir -p "\$RESOURCES_MOUNT_PATH"
mount_resources_disk() {
  disk=\$(sysctl -n hw.disknames | sed 's/:[^,]*//g' | cut -d ',' -f 2 -s)

  if [ -n "\$disk" ]; then
    partition=\$(disklabel \$disk | sed -n '/^ *[abd-z]: /s/^ *\([abd-z]\):.*/\1/p')
    dev="/dev/\${disk}\${partition}"
    
    mount_msdos "\$dev" "\$RESOURCES_MOUNT_PATH"
  fi
}

install_authorized_keys() {
  if [ -s "\$RESOURCES_MOUNT_PATH/KEYS" ]; then
# mkdir -p "/home/$SECONDARY_USER/.ssh"
    cp "\$RESOURCES_MOUNT_PATH/KEYS" "/home/$SECONDARY_USER/.ssh/authorized_keys"
    chown "$SECONDARY_USER:$SECONDARY_USER" "/home/$SECONDARY_USER/.ssh/authorized_keys"
    chmod 600 "/home/$SECONDARY_USER/.ssh/authorized_keys"
  fi
}

mount_freya_disk() {
  disk=\$(sysctl -n hw.disknames | sed 's/:[^,]*//g' | cut -d ',' -f 3 -s)

  if [ -n "\$disk" ]; then
    disklabel -w -A /dev/r\${disk}c
    newfs /dev/r\${disk}a
    mount /dev/\${disk}a /home/$SECONDARY_USER/storage

    cp -r /home/$SECONDARY_USER/.cargo /home/$SECONDARY_USER/storage/.cargo
    chown -R "$SECONDARY_USER:$SECONDARY_USER" "/home/$SECONDARY_USER/storage"
  fi
}

format_swap() {
  disk=\$(sysctl -n hw.disknames | sed 's/:[^,]*//g' | cut -d ',' -f 4 -s)

  if [ -n "\$disk" ]; then
    disklabel -E \$disk << EOF2
z
w
q
EOF2

    disklabel -E \$disk << EOF3
a b
64
*
swap
w
q
EOF3
    swapctl -a /dev/\${disk}b
  fi
}


mount_resources_disk
install_authorized_keys
mount_freya_disk
format_swap
EOF
}

configure_boot_flags() {
  cat <<EOF >> /etc/boot.conf
set tty com0
set timeout 1
EOF
}

configure_pre_login_message(){
  sed '/(%h) (%t)/s/\\r\\n\\r\\n/ FREYABOOTREADY\\r\\n\\r\\n/' /etc/gettytab > /tmp/gettytab
  rm /etc/gettytab
  mv /tmp/gettytab /etc/gettytab
}

configure_ttys(){
  sed -i '/console.*/s/off secure/on secure/' /etc/ttys
  sed -i '/ttyC[1-5].*/s/on  secure/off secure/' /etc/ttys
}

configure_ssh() {
  cp /etc/ssh/sshd_config /tmp/sshd_config
  sed '/^PermitRootLogin/s/ yes$/ no/' /tmp/sshd_config > /etc/ssh/sshd_config
  rm /tmp/sshd_config
  tee -a /etc/ssh/sshd_config <<EOF
AcceptEnv *
UseDNS no
EOF
}

configure_flags() {
  tee /etc/rc.conf.local <<EOF
sndiod_flags=NO
sendmail_flags=NO
EOF
}

setup_freya_home_directory() {
  local work_directory="/home/$SECONDARY_USER"
  local permissions="$SECONDARY_USER:$SECONDARY_USER"

  mkdir "$work_directory/storage"
  chown -R "$permissions" "$work_directory/storage"

  cat <<EOF >> /home/$SECONDARY_USER/env.toml

[[envs]]
key = "CARGO_HOME"
value = "/home/$SECONDARY_USER/storage/.cargo"

# if system does not support RUSTUP, then this should be used.
# a value is a list separated by the ',' without spaces which are
# a names of the env values.
[[envs]]
key = "FREYA_CARGO_DIR_PATHS"
value = "STABLE-X86_64-UNKNOWN-OPENBSD"

[[envs]]
key = "STABLE-X86_64-UNKNOWN-OPENBSD"
value = "/usr/local/bin/cargo"

# a default toolchain name. A value is a full toolchain name
# channel-arch-hw-os-abi
[[envs]]
key = "FREYA_DEFAULT_TOOLCHAIN"
value = "stable-x86_64-unknown-openbsd"


EOF
  chown "$permissions" "$work_directory/env.toml"
}

setup_freyashell() {
  cd /tmp

  git clone --depth 1 --branch v0.1.8 https://codeberg.org/4neko/freyashell.git

  cd ./freyashell

  cargo build --release

  cp ./target/release/freyashell /usr/local/bin/freyashell

  cd /tmp

  rm -rf /tmp/freyashell

  # set the shell
  echo "/usr/local/bin/freyashell" >> /etc/shells

  # set freya user to work with freyashell
  chsh -s /usr/local/bin/freyashell freya
}


configure_fstab() {
  mkdir -p "/mnt/resources"

  #cp /etc/fstab /tmp/fstab
  sed -i '/.a\ \/\ ffs\ /s/rw/ro/' /etc/fstab
  sed -i '/.b none swap sw/d' /etc/fstab
  echo "swap /tmp mfs rw,nodev,nosuid,-s=128m 0 0" >> /etc/fstab
  echo "swap /dev mfs rw,-P=/cfg/dev,-s=32m 0 0" >> /etc/fstab
  echo "swap /var mfs rw,-P=/cfg/var,-s=800m 0 0" >> /etc/fstab
  echo "swap /home/$SECONDARY_USER/.ssh mfs rw,-s=4m 0 0" >> /etc/fstab

  rm -f /dev/log
  rm -f /dev/slaacd.sock
  rm -f /var/run/cron.sock
  rm -f /var/run/ntpd.sock
  rm -f /var/run/smtpd.sock

  mkdir /cfg  
  cp -Rp /var /cfg
  cp -Rp /dev /cfg

  mkdir /cfg/var/etc-rw

  mv /etc/random.seed /cfg/var/etc-rw
  ln -s /var/etc-rw/random.seed /etc/random.seed 

  rcctl stop resolvd
  rcctl stop slaacd
  rcctl stop smtpd
  rcctl stop ntpd
  rcctl stop pflogd
  rcctl stop syslogd

  mv /etc/resolv.conf /cfg/var/etc-rw
  ln -s /var/etc-rw/resolv.conf /etc/resolv.conf

  rm -rf /var/*
  rm -rf /tmp/*
}

install_extra_packages
setup_sudo
configure_boot_flags
configure_pre_login_message
configure_ttys
configure_boot_scripts
configure_ssh
configure_flags
setup_freya_home_directory
setup_freyashell
configure_fstab