#
# Cookbook Name:: aws-cloudwatch
# Recipe:: install
#

action :create do
  # As we're using the accumulator pattern we need to shove everything
  # into the root run context so each of the sections can find the parent
  Chef::Log.info "Adding configuration for #{cookbook_name}"
  with_run_context :root do
    edit_resource(:template, node['aws_cloudwatch']['config_file']) do |new_resource|
      self.cookbook_name = 'aws-cloudwatch'
      source 'awslogs.conf.erb'
      variables[:logs] ||= []
      variables[:logs].push({
        log_file: new_resource.log_file,
        log_group_name: new_resource.log_group_name,
        log_stream_name: new_resource.log_stream_name,
        timezone: new_resource.timezone,
        timestamp_format: new_resource.timestamp_format,
        encoding: new_resource.encoding
    })


      action :nothing
      delayed_action :create
      notifies :restart, 'service[amazon-cloudwatch-agent]', :delayed
    end
  end
end

#provides :aws_cloudwatch_agent

if node['aws_cloudwatch']['region'].nil?
  if node['ec2'] && node['ec2']['region']
    node.normal['aws_cloudwatch']['region'] = node['ec2']['region']
  else
    log('AWS Region is necessary for this cookbook.') { level :error }
    return
  end
end

# download setup script that will install aws cloudwatch logs agent
remote_file "/tmp/AmazonCloudWatchAgent.zip" do
   source node['aws_cloudwatch']['source_zip']
   owner 'root'
   group 'root'
   mode 0755
   only_if { ! File.exists? "#{node['aws_cloudwatch']['path']}/bin/amazon-cloudwatch-agent-ctl" }
end

package 'unzip'
package 'python'
package 'python-pip' if node[:platform_family] == 'rhel'

# unzip package
execute 'Unzip CloudWatch Agent' do
  command "unzip /tmp/AmazonCloudWatchAgent.zip"
  creates "/tmp/install.sh"
  cwd '/tmp'
  only_if { ! File.exists? "#{node['aws_cloudwatch']['path']}/bin/amazon-cloudwatch-agent-ctl" }
end


# install aws unified cloudwatch agent
#execute 'Install CloudWatch Agent' do
#   command "dpkg -i -E ./amazon-cloudwatch-agent.deb"
#   creates "#{node['aws_cloudwatch']['path']}/bin/amazon-cloudwatch-agent-ctl"
#   cwd '/tmp'
#end

# sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:configuration-file-path -s

#execute 'run this' do
 #  command "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s"
#end


#install aws unified cloudwatch agent
rpm_package 'amazon-cloudwatch-agent.rpm' do
  source "/tmp/amazon-cloudwatch-agent.rpm"
  action :install
end

#execute aws unified cloudwatch agent
#execute 'Exec CloudWatch Agent' do
#   command "sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:configuration-file-path -s"
#end

# restart the agent service in the end to ensure that
# the agent will run with the custom configurations
service 'amazon-cloudwatch-agent' do
   action [:enable, :start]
   supports :restart => true, :status => true, :start => true, :stop => true
   provider Chef::Provider::Service::Systemd
   only_if { File.exists? "/usr/bin/dbus-daemon" }
end
