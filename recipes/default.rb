#
# Cookbook:: KillingFloor2-Ubuntu
# Recipe:: default
#
# Copyright:: 2019, The Authors, All Rights Reserved.

## Install all prereqs/Update OS
apt_update

ip_list = Socket.ip_address_list

#Add DNS caching so SteamCMD is less shit
apt_package 'dnsmasq'
service 'dnsmasq' do
    action :restart
end

user 'steam' do
    manage_home true
    home '/home/steam'
    shell '/bin/false'
    password "$1$UKFlKYPt$kXT2BX8vnHrgMQuB4OMlo1"
    sensitive true
end

#SteamCMD is slow as shit otherwise
bash 'Adjust File Settings' do
    code <<-EOH
    echo "fs.file-max=100000" >> /etc/sysctl.conf && sysctl -p
    echo "* soft nofile 1000000" >> /etc/security/limits.conf
    echo "* hard nofile 1000000" >> /etc/security/limits.conf
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
    EOH
end

bash 'Accept Steam EULA' do
    code <<-EOH
    echo steam steam/license note "" | sudo debconf-set-selections
    echo steam steam/question select "I AGREE" | sudo debconf-set-selections
    EOH
end

apt_package 'steamcmd' do
    options "-y"
    action :install
end

# Firewall Configurations
firewall_rule 'Game Port' do
    port      7777
    direction :in
    interface 'eth1'
    protocol  :udp
    command   :allow
end

firewall_rule 'Query Port' do
    port      27015
    direction :in
    interface 'eth1'
    protocol  :udp
    command   :allow
end

firewall_rule 'Steam Port' do
    port      20560
    direction :in
    interface 'eth1'
    protocol  :udp
    command   :allow
end

# open standard http port to tcp traffic only; insert as first rule
firewall_rule 'http' do
    port     80
    protocol :tcp
    interface 'eth1'
    position 1
    command   :allow
end

firewall_rule 'Web Admin' do
    port      8080
    direction :in
    interface 'eth1'
    protocol  :tcp
    command   :allow
end


firewall_rule 'ssh' do
    port     22
    command  :allow
end

# Script File for Kf2 Update
%w[ /home/steam/games /home/steam/games/killingfloor].each do |path|
    directory path do
        owner 'steam'
        group 'steam'
        mode '0755'
        recursive true
    end
end

cookbook_file '/home/steam/games/killingfloor/Install-KF2.sh' do
    source 'Install-KF2.sh'
    owner 'steam'
    group 'steam'
    mode '0755'
    action :create
end

## Login and install KF2
execute 'Install KF2' do
    command "steamcmd +runscript /home/steam/games/killingfloor/Install-KF2.sh"
    live_stream true
end

['LinuxServer-KFEngine.ini','LinuxServer-KFGame.ini','KFZedVarient.ini'].each do |file|
    cookbook_file "/home/steam/games/killingfloor/KFGame/Config/#{file}" do
        source "#{file}"
        mode "0755"
        owner "steam"
        group "steam"
        action :create
    end
end

execute 'chown' do
    command "chown -R steam /home/steam/games/killingfloor"
    user "root"
end

execute 'chgrp' do
    command "chgrp -R steam /home/steam/games/killingfloor"
    user "root"
end

systemd_unit 'kf2server.service' do
    content({Unit: {
            Description: 'kf2server',
            After: 'network.target',
            StartLimitIntervalSec: 0,
        },
        Service: {
            Type: 'simple',
            Restart: 'always',
            RestartSec: 10,
            User: 'steam',
            ExecStart: '/home/steam/games/killingfloor/Binaries/Win64/KFGameSteamServer.bin.x86_64 kf-burningparis?game=Zedternal.WMGameInfo_Endless?difficulty=0?Multihome=' + ip_list[2].ip_address,
        },
        Install: {
            WantedBy: 'multi-user.target'
        }})
    action [:create, :enable]
end

# We need to autogenerate KFWeb.ini because KF2 replaces it on shutdown
execute "Start & Stop Server" do
    command 'timeout 10s /home/steam/games/killingfloor/Binaries/Win64/KFGameSteamServer.bin.x86_64 kf-burningparis'
    user 'steam'
    ignore_failure true
end

ruby_block 'replace_line' do
    block do
        file = Chef::Util::FileEdit.new('/home/steam/games/killingfloor/KFGame/Config/KFWeb.ini')
        file.search_file_replace_line('bEnabled=false', 'bEnabled=true')
        file.write_file
    end
    notifies :start, "systemd_unit[kf2server.service]", :delayed
end