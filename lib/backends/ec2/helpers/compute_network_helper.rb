module Backends
  module Ec2
    module Helpers
      module ComputeNetworkHelper

        def compute_attach_network_public(networkinterface)
          compute_id = networkinterface.source.split('/').last

          compute_instance = compute_get(compute_id)
          fail Backends::Errors::ResourceCreationError, "Resource #{compute_id.inspect} already has a public network attached!" \
            if compute_attach_network_public_has_elastic?(compute_id)

          is_vpc = compute_instance.links.to_a.select { |l| l.target.split('/').last.include?('vpc-') }.any?

          addr_opts = {}
          addr_opts[:instance_id] = compute_id

          Backends::Ec2::Helpers::AwsConnectHelper.rescue_aws_service(@logger) do
            if is_vpc
              addr_opts[:allocation_id] = @ec2_client.allocate_address(domain: 'vpc')[:allocation_id]
            else
              addr_opts[:public_ip] = @ec2_client.allocate_address(domain: 'standard')[:public_ip]
            end

            begin
              @ec2_client.associate_address(addr_opts)
            rescue => e
              @logger.warn "[Backends] [Ec2Backend] An attempt to associate #{addr_opts.inspect} failed!"

              if is_vpc
                @ec2_client.release_address(allocation_id: addr_opts[:allocation_id])
              else
                @ec2_client.release_address(public_ip: addr_opts[:public_ip])
              end

              fail Backends::Errors::ResourceCreationError, e.message
            end
          end

          "compute_#{compute_id}_nic_eni-0"
        end

        def compute_attach_network_private(networkinterface)
          # TODO: explore possible solutions
          fail Backends::Errors::ResourceCreationError, 'Network "private" cannot be attached manually!'
        end

        def compute_attach_network_vpc(networkinterface)
          # TODO: explore possible solutions
          fail Backends::Errors::ResourceCreationError, "VPC networks cannot be attached to already running instances!"
        end

        def compute_detach_network_public(networkinterface)
          ec2_allocation = networkinterface.attributes.occi!.networkinterface!.address
          fail Backends::Errors::ResourceCreationError, 'Interfaces without an address cannot be detached!' if ec2_allocation.blank?

          Backends::Ec2::Helpers::AwsConnectHelper.rescue_aws_service(@logger) do
            begin
              @ec2_client.disassociate_address(public_ip: ec2_allocation)
              @ec2_client.release_address(public_ip: ec2_allocation)
            rescue ::Aws::EC2::Errors::AuthFailure => e
              @logger.warn "[Backends] [Ec2Backend] An attempt to release #{ec2_allocation.inspect} failed!"
              fail Backends::Errors::UserNotAuthorizedError, e.message
            end
          end
        end

        def compute_detach_network_private(networkinterface)
          fail Backends::Errors::ResourceCreationError, 'Network "private" cannot be detached manually!'
        end

        def compute_detach_network_vpc(networkinterface)
          # TODO: explore possible solutions
          fail Backends::Errors::ResourceCreationError, "VPC networks cannot be detached from already running instances!"
        end

        private

        def compute_attach_network_public_has_elastic?(instance_id)
          filters = []
          filters << { name: 'instance-id', values: [instance_id] }

          addresses = nil
          Backends::Ec2::Helpers::AwsConnectHelper.rescue_aws_service(@logger) do
            addresses = @ec2_client.describe_addresses(filters: filters).addresses
          end

          addresses && (addresses.count > 0)
        end

      end
    end
  end
end
