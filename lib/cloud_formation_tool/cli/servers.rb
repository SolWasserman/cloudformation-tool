require 'set'
require 'aws-sdk-ec2'

module CloudFormationTool
  module CLI
    
    class Servers < Clamp::Command
      include CloudFormationTool
      
      parameter "STACK_NAME", "Name of the stack to list servers for"
      parameter "[ASG_NAME]", "Select only this specific auto scaling group"
      
      def execute
        st = CloudFormation::Stack.new(stack_name)
        ts = st.asgroups.select do |res|
          asg_name.nil? or (res.logical_resource_id == asg_name)
        end.collect do |res|
          Thread.new do
            asg = awsas.describe_auto_scaling_groups({
              auto_scaling_group_names: [ res.physical_resource_id ]
            }).auto_scaling_groups.first
            if asg.nil?
              []
            else
              asg.instances.collect do |i|
                Aws::EC2::Instance.new i.instance_id, client: awsec2
              end.collect do |i|
                ips = [ i.public_ip_address ] + i.network_interfaces.collect(&:ipv_6_addresses).flatten.collect(&:ipv_6_address)
                "#{res.logical_resource_id.ljust(30, ' ')} '#{i.public_dns_name}' (#{ips.join(', ')})"
              end
            end
          end
        end
        ts.each(&:join)
        puts ts.select{ |t| t.value.length > 0 }.collect { |t| t.value.join "\n" }
      end
      
    end
  end
end