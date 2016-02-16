python_pip "twisted" do
  version node["graphite"]["twisted_version"]
  action :install
end

python_pip "zope.interface" do
  action :install
end

python_pip "carbon" do
  version node["graphite"]["version"]
  options %Q{--install-option="--prefix=#{node['graphite']['home']}" --install-option="--install-lib=#{node['graphite']['home']}/lib"}
  action :install
end

template "#{node['graphite']['home']}/conf/carbon.conf" do
  mode "0644"
  source "carbon.conf.erb"
  owner node["apache"]["user"]
  group node["apache"]["group"]
  variables(
    :storage_dir                => node["graphite"]["carbon"]["storage_dir"],
    :whisper_dir                => node["graphite"]["carbon"]["whisper_dir"],
    :line_receiver_interface    => node["graphite"]["carbon"]["line_receiver_interface"],
    :pickle_receiver_interface  => node["graphite"]["carbon"]["pickle_receiver_interface"],
    :cache_query_interface      => node["graphite"]["carbon"]["cache_query_interface"],
    :log_updates                => node["graphite"]["carbon"]["log_updates"],
    :max_cache_size             => node["graphite"]["carbon"]["max_cache_size"],
    :max_creates_per_minute     => node["graphite"]["carbon"]["max_creates_per_minute"],
    :max_updates_per_second     => node["graphite"]["carbon"]["max_updates_per_second"]
  )
  notifies :restart, "service[carbon-cache]"
end

template "#{node['graphite']['home']}/conf/storage-schemas.conf" do
  mode "0644"
  source "storage-schemas.conf.erb"
  owner node["apache"]["user"]
  group node["apache"]["group"]
  notifies :restart, "service[carbon-cache]"
end

template "#{node['graphite']['home']}/conf/storage-aggregation.conf" do
  mode "0644"
  source "storage-aggregation.conf.erb"
  owner node["apache"]["user"]
  group node["apache"]["group"]
  notifies :restart, "service[carbon-cache]"
end

execute "chown" do
  command "chown -R #{node['apache']['user']}:#{node['apache']['group']} #{node['graphite']['carbon']['storage_dir']}"
  only_if do
    f = File.stat("#{node['graphite']['carbon']['storage_dir']}")
    f.uid == 0 && f.gid == 0
  end
end

template "/etc/init/carbon-cache.conf" do
  mode "0644"
  source "carbon-cache.conf.erb"
  variables(
    :home => node["graphite"]["home"],
    :version => node["graphite"]["version"],
    :storage_dir => node["graphite"]["carbon"]["storage_dir"]
  )
end

logrotate_app "carbon" do
  cookbook "logrotate"
  path "#{node['graphite']['carbon']['storage_dir']}/log/carbon-cache/carbon-cache-a/*.log"
  frequency "daily"
  rotate 7
  create "644 root root"
end

service "carbon-cache" do
  provider Chef::Provider::Service::Upstart
  action [ :enable, :start ]
end
