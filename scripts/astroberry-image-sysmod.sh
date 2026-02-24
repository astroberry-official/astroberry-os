#!/bin/bash
#
# astroberry-image-sysmod.sh
# Apply custom mods to vanilla system image
# Invoked by: scripts/astroberry-image-build.sh
# Runs in chroot environment!

set -xe

# Check if run in chroot
if [ ! ischroot ]; then
  exit 1
fi

# Validate version
if [ -z "$ASTROBERRY_VERSION" ]; then
    echo "\ASTROBERRY_VERSION environment variable is not set!"
    exit 2
fi

# Validate version
if [[ ! "$ASTROBERRY_VERSION" =~ ^[0-9]\.([0-9]|[0-9][0-9])$ ]]; then
    echo "Wrong version format! Expected #.# or #.##, got $ASTROBERRY_VERSION"
    exit 2
fi

export DEBIAN_FRONTEND=noninteractive

################### ADD APT REPOSITORY ##################

# Add Astroberry OS certificate
curl -fsSL https://astroberry.io/debian/astroberry.asc \
    | gpg --dearmor -o /etc/apt/keyrings/astroberry.gpg

# Add Astroberry OS repository
cat <<EOF > /etc/apt/sources.list.d/astroberry.sources
Types: deb
URIs: https://astroberry.io/debian/
Architectures: arm64
Suites: trixie
Components: main
Signed-By: /etc/apt/keyrings/astroberry.gpg
EOF

# Give priority to Astroberry OS repository
cat <<EOF > /etc/apt/preferences.d/astroberry-pin
Package: *
Pin: origin astroberry.io
Pin-Priority: 900
EOF

################### UPDATE PACKAGES ##################

# Update the system
apt-get update

################### INSTALL ASTROBERRY OS ##################

# Install Astroberry OS
apt-get install -y astroberry-os-desktop

################### APPLY SYSTEM MODS ######################

# Add Astroberry OS config directory
if [ ! -d /etc/astroberry ]; then mkdir -p /etc/astroberry; fi

# Add Astroberry OS version file
echo "$ASTROBERRY_VERSION" > /etc/astroberry/version

# Enable members of netdev group to edit network connections
cat <<EOF > /etc/polkit-1/rules.d/10-networkmanager.rules
polkit.addRule(function(action, subject) {
  if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 &&
      subject.isInGroup("netdev")) {
    return polkit.Result.YES;
  }
});
EOF

# Enable members of sudo group to manage packages
cat <<EOF > /etc/polkit-1/rules.d/10-synaptic.rules
polkit.addRule(function(action, subject) {
  if (action.id.indexOf("com.ubuntu.pkexec.synaptic") == 0 &&
      subject.isInGroup("sudo")) {
    return polkit.Result.YES;
  }
});
EOF

# Enable members of sudo group to reboot and shutdown
cat <<EOF > /etc/polkit-1/rules.d/10-power-manager.rules
polkit.addRule(function(action, subject) {
  if (action.id.indexOf("org.freedesktop.login1.power-off") == 0 &&
      subject.isInGroup("sudo")) {
    return polkit.Result.YES;
  }
});

polkit.addRule(function(action, subject) {
  if (action.id.indexOf("org.freedesktop.login1.reboot") == 0 &&
      subject.isInGroup("sudo")) {
    return polkit.Result.YES;
  }
});
EOF

# Enable members of plugdev group to mount and eject external drives
cat <<EOF > /etc/polkit-1/rules.d/10-file-manager.rules
polkit.addRule(function(action, subject) {
  if (action.id.startsWith("org.freedesktop.udisks2") &&
       subject.isInGroup("plugdev")) {
    return polkit.Result.YES;
  }
});
EOF

# Disable graphical login
update-rc.d lightdm disable

# Install astroberry-manager
apt-get install -y python3 python-is-python3 python3-pip python3-venv \
  libcairo2-dev libgirepository-2.0-dev libdbus-1-dev libcfitsio-dev libnova-dev libindi-dev \
  tigervnc-standalone-server gpsd gpsd-tools apparmor-utils
python -m venv /opt/astroberry-manager && /opt/astroberry-manager/bin/pip install /tmp/astroberry-mods/astroberry_manager-1.0-py3-none-any.whl
#python -m venv /opt/astroberry-manager && /opt/astroberry-manager/bin/pip install astroberry_manager@git+https://github.com/astroberry-official/astroberry-manager

# Install reverse proxy
apt-get install -y caddy
if [ -e /etc/caddy/Caddyfile ]; then cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.default; fi
cat <<EOF > /etc/caddy/Caddyfile
{
	auto_https disable_redirects
}

http://astroberry.local {
        handle /api* {
            reverse_proxy localhost:8624
        }
        handle /websockify* {
            reverse_proxy localhost:8070
        }
        handle /* {
            reverse_proxy localhost:8080
        }
}

https://astroberry.local {
        handle /api* {
            reverse_proxy localhost:8624
        }
        handle /websockify* {
            reverse_proxy localhost:8070
        }
        handle /* {
            reverse_proxy localhost:8080
        }
}
EOF

# Enable SSH
# ln -s /usr/lib/systemd/system/ssh.service /etc/systemd/system/multi-user.target.wants/

# Setup TigerVNC service
echo "Setup TigerVNC service"
cat <<EOF > /etc/systemd/system/vncserver.service
[Unit]
Description=Remote desktop service (VNC) for Astroberry OS
After=multi-user.target

[Service]
Type=simple
User=astroberry
Environment=HOME=/home/astroberry
ExecStart=tigervncserver -display :70 -desktop astroberry -SecurityTypes None -NeverShared -DisconnectClients -localhost yes -UseIPv6 no -geometry 1920x1080 -depth 24 -fg -xstartup startxfce4
ExecStop=tigervncserver -kill
Restart=on-failure
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF
ln -s /etc/systemd/system/vncserver.service /etc/systemd/system/multi-user.target.wants/

# Setup INDI Web Manager service
echo "Setup INDI Web Manager service"
cat <<EOF > /etc/systemd/system/indiwebmanager.service
[Unit]
Description=INDI Web Manager
After=multi-user.target

[Service]
Type=idle
User=astroberry
ExecStart=sh -c "/opt/astroberry-manager/bin/indi-web --host 127.0.0.1"

Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
ln -s /etc/systemd/system/indiwebmanager.service /etc/systemd/system/multi-user.target.wants/

# Setup Websockify service
echo "Setup Websockify service"
cat <<EOF > /etc/systemd/system/websockify.service
[Unit]
Description=Websockify for VNC
After=multi-user.target

[Service]
Type=idle
User=astroberry
ExecStart=sh -c "/opt/astroberry-manager/bin/websockify 127.0.0.1:8070 127.0.0.1:5970 --auth-plugin ExpectOrigin --auth-source \"https://astroberry.local http://astroberry.local\""
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
ln -s /etc/systemd/system/websockify.service /etc/systemd/system/multi-user.target.wants/

# Setup Astroberry Manager service
echo "Setup Astroberry Manager service"
cat <<EOF > /etc/systemd/system/astroberry-manager.service
[Unit]
Description=Astroberry OS Web Manager
Wants=vncserver.service
Wants=indiwebmanager.service
Wants=websockify.service
After=multi-user.target

[Service]
Type=idle
User=astroberry
Environment=TERM=xterm-256color
ExecStart=sh -c "/opt/astroberry-manager/bin/astroberry-manager"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
ln -s /etc/systemd/system/astroberry-manager.service /etc/systemd/system/multi-user.target.wants/

# Setup file sharing
echo "Setup file sharing"
if [ -e /etc/samba/smb.conf ]; then cp /etc/samba/smb.conf /etc/samba/smb.conf.default; fi
cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   map to guest = bad user
   usershare allow guests = no
   multicast dns register = no

[Shared Files]
   comment = Shared Files
   path = /home/astroberry/Shared
   browseable = yes
   writeable = yes
   read only = no
   create mask = 0644
   directory mask = 0755
   valid users = astroberry
EOF

# Enable zeroconf/avahi
echo "Setup avahi service"
cat <<EOF > /etc/avahi/services/astroberry.service
<?xml version="1.0" standalone="no"?><!--*-nxml-*-->
<service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
                <type>_device-info._tcp</type>
                <port>0</port>
                <txt-record>model=MacSamba</txt-record>
        </service>
        <service>
                <type>_http._tcp</type>
                <port>80</port>
        </service>
        <service>
                <type>_smb._tcp</type>
                <port>445</port>
        </service>
</service-group>
EOF

# Customize login greeter
echo "Customize login greeter"
if [ -e /etc/lightdm/lightdm-gtk-greeter.conf ]; then
    sed -i "s/^#background=.*/background=\/usr\/share\/astroberry-artwork\/backgrounds\/milkyway-galaxy-center-and-its-companions_1920x1080.jpg/g" /etc/lightdm/lightdm-gtk-greeter.conf
    sed -i "s/^#font-name=.*/font-name=Roboto/g" /etc/lightdm/lightdm-gtk-greeter.conf
    echo "default-user-image=/usr/share/astroberry-artwork/icons/astroberry-avatar-500.png" >> /etc/lightdm/lightdm-gtk-greeter.conf
fi

# Customize desktop
echo "Customize desktop"

# Fix vnc slow down on headless system: xfwm4 --compositor=off --vblank=off --replace
sed -i "s/<value type=\"string\" value=\"xfwm4\"\/>/<value type=\"string\" value=\"xfwm4\"\/><value type=\"string\" value=\"--compositor=off\"\/><value type=\"string\" value=\"--vblank=off\"\/>/g" \
    /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml

# Customize GTK settings
sed -i "s/<property name=\"ThemeName\" type=\"string\" value=\".*\"\/>/<property name=\"ThemeName\" type=\"string\" value=\"Adwaita-dark\"\/>/g" \
    /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
sed -i "s/<property name=\"FontName\" type=\"string\" value=\".*\"\/>/<property name=\"FontName\" type=\"string\" value=\"Roboto 11\"\/>/g" \
    /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
sed -i "s/<property name=\"MonospaceFontName\" type=\"string\" value=\".*\"\/>/<property name=\"MonospaceFontName\" type=\"string\" value=\"Monospace 11\"\/>/g" \
    /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

# Enable dark mode for panels
sed -i "s/<property name=\"dark-mode\" type=\"bool\" value=\".*\"\/>/<property name=\"dark-mode\" type=\"bool\" value=\"true\"\/>/g" \
    /etc/xdg/xfce4/panel/default.xml

# Customize panel 1
sed -i "s/<property name=\"size\" type=\"uint\" value=\".*\"\/>/<property name=\"size\" type=\"uint\" value=\"38\"\/>/g" \
    /etc/xdg/xfce4/panel/default.xml
sed -i "s/<property name=\"icon-size\" type=\"uint\" value=\".*\"\/>/<property name=\"icon-size\" type=\"uint\" value=\"0\"\/>/g" \
    /etc/xdg/xfce4/panel/default.xml

# Customize menu layout
echo "Customize menu layout"
if [ -e /etc/xdg/menus/xfce-applications.menu ]; then mv /etc/xdg/menus/xfce-applications.menu /etc/xdg/menus/xfce-applications.menu.default; fi
cat <<EOF > /etc/xdg/menus/xfce-applications.menu
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
  "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">

<Menu>
    <Name>Astroberry</Name>

    <DefaultAppDirs/>
    <DefaultDirectoryDirs/>

    <Include>
        <Category>X-Xfce-Toplevel</Category>
    </Include>

    <Exclude>
        <Filename>xfce4-mail-reader.desktop</Filename>
    </Exclude>

    <Layout>
        <Filename>xfce4-run.desktop</Filename>
        <Separator/>
        <Filename>xfce4-terminal-emulator.desktop</Filename>
        <Filename>xfce4-file-manager.desktop</Filename>
        <Filename>xfce4-web-browser.desktop</Filename>
        <Separator/>
        <Menuname>Astronomy</Menuname>
        <Separator/>
        <Merge type="all"/>
        <Separator/>
        <Filename>xfce4-about.desktop</Filename>
        <Filename>xfce4-session-logout.desktop</Filename>
    </Layout>

    <Menu>
        <Name>Astronomy</Name>
        <Directory>xfce-astronomy.directory</Directory>
        <Include>
            <Category>Science</Category>
            <Category>Education</Category>
            <Category>AstroImaging</Category>
            <Filename>com.google.sites.ser-player.desktop</Filename>
        </Include>
    </Menu>

    <Menu>
        <Name>Settings</Name>
        <Directory>xfce-settings.directory</Directory>
        <Include>
            <Category>Settings</Category>
        </Include>

        <Layout>
            <Filename>xfce-settings-manager.desktop</Filename>
            <Separator/>
            <Merge type="all"/>
        </Layout>

        <Menu>
            <Name>Screensavers</Name>
            <Directory>xfce-screensavers.directory</Directory>
            <Include>
                <Category>Screensaver</Category>
            </Include>
        </Menu>
    </Menu>

    <Menu>
        <Name>Accessories</Name>
        <Directory>xfce-accessories.directory</Directory>
        <Include>
            <Or>
                <Category>Accessibility</Category>
                <Category>Core</Category>
                <Category>Legacy</Category>
                <Category>Utility</Category>
            </Or>
        </Include>
        <Exclude>
            <Or>
                <Filename>xfce4-file-manager.desktop</Filename>
                <Filename>xfce4-terminal-emulator.desktop</Filename>
                <Filename>xfce4-about.desktop</Filename>
                <Filename>xfce4-run.desktop</Filename>
            </Or>
        </Exclude>
    </Menu>

    <Menu>
        <Name>System</Name>
        <Directory>xfce-system.directory</Directory>
        <Include>
            <Or>
                <Category>Emulator</Category>
                <Category>System</Category>
            </Or>
        </Include>
        <Exclude>
            <Or>
                <Filename>xfce4-session-logout.desktop</Filename>
            </Or>
        </Exclude>
    </Menu>

    <Menu>
        <Name>Other</Name>
        <Directory>xfce-other.directory</Directory>
        <OnlyUnallocated/>
        <Include>
            <All/>
        </Include>
    </Menu>
    <DefaultMergeDirs/>

</Menu>

EOF

# remove astrodmx from top level menu
echo "NoDisplay=true" >> /usr/share/desktop-directories/astrodmx.directory

# First boot system configuration is handled by cloud-init
# with configuration in meta-data, user-data, network-config.
# Additional custom configuration is defined in astroberry-init
# invoked in runcmd section of user-data file.

echo "Configure cloud-init"

# meta-data
sed -i "s/instance_id: .*/instance_id: astroberryos-image/g" /boot/firmware/meta-data

# user-data
cat <<EOF > /boot/firmware/user-data
#cloud-config
hostname: astroberry
manage_etc_hosts: true

users:
- name: astroberry
  groups: users,adm,dialout,audio,netdev,video,plugdev,cdrom,games,input,gpio,spi,i2c,render,sudo
  shell: /bin/bash
  lock_passwd: false
  passwd: \$5\$MRvtBeRUfh\$QGv7UN3cnLPJ00paa82TjuwrjqiFvpj/JDgKKd7ikh4
  sudo: ALL=(ALL) NOPASSWD:ALL

ssh_pwauth: true

timezone: Etc/UTC

runcmd:
- localectl set-x11-keymap "us" pc105
- setupcon -k --force || true
- astroberry-init
EOF

## network-config
#cat <<EOF > /boot/firmware/network-config
#network:
#  version: 2
#
#  ethernets:
#    eth0:
#      dhcp4: true
#      optional: true
#
#  wifis:
#    wlan0:
#      dhcp4: no
#      addresses: [10.42.0.1/24]
#      access-points:
#        "astroberry":
#          password: "astroberry"
#          mode: ap
#      regulatory-domain: GB
#EOF

# Set wireless regulatory domain
sed -i -e "s/\s*cfg80211.ieee80211_regdom=\S*//" \
    -e "s/\(.*\)/\1 cfg80211.ieee80211_regdom=GB/" \
    /boot/firmware/cmdline.txt

# Configure Hotspot
WIFIKEY="$(echo WVhOMGNtOWlaWEp5ZVFvPQo= | base64 -d | base64 -d)"
cat <<EOF > /etc/NetworkManager/system-connections/Hotspot.nmconnection
[connection]
id=Hotspot
uuid=54825a4f-17c5-4111-adcd-3c08c0d189f7
type=wifi
interface-name=wlan0
timestamp=1770433545
autoconnect=true

[wifi]
mode=ap
ssid=astroberry

[wifi-security]
group=ccmp;
key-mgmt=wpa-psk
pairwise=ccmp;
proto=rsn;
psk=$WIFIKEY

[ipv4]
method=shared

[ipv6]
addr-gen-mode=default
method=ignore

[proxy]
EOF
chmod 600 /etc/NetworkManager/system-connections/Hotspot.nmconnection

# Add custom init script invoked by cloud-init at the first boot
# This script is run as **root**
echo "Add astroberry-init"
cat <<EOF > /usr/local/bin/astroberry-init
#!/bin/bash

set -xe

cleanup() {
    rm -rf /usr/local/bin/astroberry-init
    rm -rf /usr/local/bin/desktop-init
}
trap cleanup EXIT

# Enable radio
nmcli radio wifi on

# Enable file sharing
if [ ! -e /home/astroberry/Shared ]; then su astroberry -c "mkdir -p /home/astroberry/Shared"; fi
echo -ne "astroberry\nastroberry\n" | smbpasswd -a -s astroberry

# Apply default configuration to user desktop
if [ -e /usr/local/bin/desktop-init ]; then
    su astroberry -c "/usr/local/bin/desktop-init" && sleep 1 && systemctl restart vncserver.service
fi

# Trust local CA
caddy trust

EOF
chmod 755 /usr/local/bin/astroberry-init

# Add customization of user desktop invoked by astroberry-init at the first boot
# This script is run as **user**
echo "Add desktop-init"
cat <<EOF > /usr/local/bin/desktop-init
#!/bin/bash

set -xe

export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$UID/bus
export DISPLAY=:70

# Window title font
xfconf-query -c xfwm4 -p /general/title_font -n -t string -s "Roboto Bold 11"

# Desktop background
xfconf-query -c xfce4-desktop -n -t string -p /backdrop/screen0/monitorVNC-0/workspace0/last-image \
  -s /usr/share/astroberry-artwork/backgrounds/sci-fi-planet-darkness-night_1920x1080_bw.jpg

# Desktop icons
xfconf-query -c xfce4-desktop -n -t int -p /desktop-icons/style -s 0

# Application menu
xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-icon -n -t string -s /usr/share/astroberry-artwork/icons/astroberry-icon-white.svg
xfconf-query -c xfce4-panel -p /plugins/plugin-1/button-title -n -t string -s "Astroberry OS"
xfconf-query -c xfce4-panel -p /plugins/plugin-1/show-button-title -n -t bool -s true

# Action buttons
xfconf-query -c xfce4-panel -p /plugins/plugin-10/appearance -n -t int -s 0
xfconf-query -c xfce4-panel -p /plugins/plugin-10/items -n -a \
  -t string -s "-lock-screen" -t string -s "-switch-user" -t string -s "-separator" -t string -s "-suspend" -t string -s "-hibernate" -t string -s "-hybrid-sleep" -t string -s "-separator" \
  -t string -s "+shutdown" -t string -s "+restart" -t string -s "+separator" -t string -s "+logout" -t string -s "-logout-dialog"

# Clock
xfconf-query -c xfce4-panel -p /plugins/plugin-8/digital-date-font -n -t string -s "Roboto 11"
xfconf-query -c xfce4-panel -p /plugins/plugin-8/digital-time-font -n -t string -s "Roboto 11"
xfconf-query -c xfce4-panel -p /plugins/plugin-8/digital-time-format -n -t string -s "%T"

EOF
chmod 755 /usr/local/bin/desktop-init

################### CLEAN ##################

# Clean packages and leftovers
apt-get remove -y --purge modemmanager
apt-get autoremove -y
rm -rf /install.sh # AstroDMx leftover

# Clean apt cache
apt-get clean
rm -rf /var/cache/apt/archives/*.deb
rm -rf /var/cache/apt/archives/partial/*
rm -rf /var/lib/apt/lists/*

# Clean logs
find /var/log -type f -name "*.log" -delete
find /var/log -type f -name "*.log.*" -delete
find /var/log -type f -name "*.gz" -delete
truncate -s 0 /var/log/lastlog
truncate -s 0 /var/log/wtmp
truncate -s 0 /var/log/btmp

# Clean tmp
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clean caches
rm -rf /home/*/.cache/*
rm -rf /root/.cache/*

# Clean bash history
rm -f /home/*/.bash_history
rm -f /root/.bash_history

# Truncate journal
journalctl --vacuum-time=1s
rm -rf /var/log/journal/*
