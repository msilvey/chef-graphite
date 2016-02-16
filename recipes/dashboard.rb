include_recipe "apache2"
include_recipe "apache2::mod_python"
include_recipe "build-essential"

if platform_family?("debian")
  packages = [ "python-cairo-dev", "python-django", "python-django-tagging", "python-memcache", "python-rrdtool" ]
elsif platform_family?("fedora", "rhel")
  packages = [ "bitmap", "bitmap-fonts", "Django", "django-tagging", "pycairo", "python-memcached", "rrdtool-python" ]

  # bitmap-fonts not available
  packages.reject! { |pkg| pkg == "bitmap-fonts" } if platform?("amazon")
else
  packages = [ "python-cairo-dev", "python-django", "python-django-tagging", "python-memcache", "python-rrdtool" ]
end

packages.each do |graphite_package|
  package graphite_package do
    action :install
  end
end

python_pip "graphite-web" do
  version node["graphite"]["version"]
  options %Q{--install-option="--prefix=#{node['graphite']['home']}" --install-option="--install-lib=#{node['graphite']['home']}/webapp"}
  action :install
end

template "#{node['graphite']['home']}/conf/graphTemplates.conf" do
  mode "0644"
  source "graphTemplates.conf.erb"
  owner node["apache"]["user"]
  group node["apache"]["group"]
  notifies :restart, "service[apache2]"
end

template "#{node['graphite']['home']}/webapp/graphite/local_settings.py" do
  mode "0644"
  source "local_settings.py.erb"
  owner node["apache"]["user"]
  group node["apache"]["group"]
  variables(
    :home           => node["graphite"]["home"],
    :storage_dir    => node["graphite"]["carbon"]["storage_dir"],
    :whisper_dir    => node["graphite"]["carbon"]["whisper_dir"],
    :timezone       => node["graphite"]["dashboard"]["timezone"],
    :memcache_hosts => node["graphite"]["dashboard"]["memcache_hosts"],
    :mysql_server   => node["graphite"]["dashboard"]["mysql_server"],
    :mysql_username => node["graphite"]["dashboard"]["mysql_username"],
    :mysql_password => node["graphite"]["dashboard"]["mysql_password"],
    :mysql_port     => node["graphite"]["dashboard"]["mysql_port"]
  )
  notifies :restart, "service[apache2]"
end

apache_site "000-default" do
  enable false
end

web_app "graphite" do
  template "graphite.conf.erb"
  docroot "#{node['graphite']['home']}/webapp"
  server_name "graphite"
  graphite_home node["graphite"]["home"]
  graphite_port node["graphite"]["port"]
  storage_dir node["graphite"]["carbon"]["storage_dir"]
end

directory "#{node['graphite']['carbon']['storage_dir']}/log" do
  owner node["apache"]["user"]
  group node["apache"]["group"]
end

directory node['graphite']['carbon']['whisper_dir'] do
  owner node["apache"]["user"]
  group node["apache"]["group"]
end

directory "#{node['graphite']['carbon']['storage_dir']}/log/webapp" do
  owner node["apache"]["user"]
  group node["apache"]["group"]
end

cookbook_file "#{node['graphite']['carbon']['storage_dir']}/graphite.db" do
  owner node["apache"]["user"]
  group node["apache"]["group"]
  action :create_if_missing
end

logrotate_app "dashboard" do
  cookbook "logrotate"
  path "#{node['graphite']['carbon']['storage_dir']}/log/webapp/*.log"
  frequency "daily"
  rotate 7
  create "644 root root"
end
