name 'aws-cloudwatch'
maintainer 'Test'
maintainer_email 'nXXX@amXX.com'
description 'Install and Configure AWS CloudWatch Unified Agent'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version '1.0.0'

%w(
   ubuntu
).each do |os|
  supports os
end

