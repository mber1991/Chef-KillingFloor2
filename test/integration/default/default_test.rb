# InSpec test for recipe KillingFloor2-Ubuntu::default

# The InSpec reference, with examples and extensive documentation, can be
# found at https://www.inspec.io/docs/reference/resources/

describe package("steamcmd") do
  it { should be_installed }
end

describe user 'steam' do
  it { should exist }
end

describe service('kf2server.service') do
  it { should be_installed }
  it { should be_enabled }
  it { should be_running }
end

describe port(7777) do
  it { should be_listening }
  its('protocols') { should include 'udp' }
end
describe port(27015) do
  it { should be_listening }
  its('protocols') { should include 'udp' }
end
describe port(8080) do
  it { should be_listening }
  its('protocols') { should include 'tcp' }
end
#describe port(20560) do
#  it { should be_listening }
#  its('protocols') { should include 'udp' }
#end

# Outbreak
# describe port(123) do
#  it { should be_listening }
#  its('protocols') { should include 'udp' }
#end
