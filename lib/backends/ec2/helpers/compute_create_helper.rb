module Backends
  module Ec2
    module Helpers
      module ComputeCreateHelper

        def compute_create_with_os_tpl(compute)
          @logger.debug "[Backends] [Ec2Backend] Deploying #{compute.inspect}"

          os_tpl_mixins = compute.mixins.get_related_to(Occi::Infrastructure::OsTpl.mixin.type_identifier)
          os_tpl = os_tpl_mixins.first

          @logger.debug "[Backends] [Ec2Backend] Deploying with OS template: #{os_tpl.term}"
          os_tpl = os_tpl_list_term_to_image_id(os_tpl.term)
          serialized_mixins = compute.mixins.to_a.map { |m| m.type_identifier }.join(' ')

          Backends::Ec2::Helpers::AwsConnectHelper.rescue_aws_service(@logger) do
            ec2_response = @ec2_client.run_instances(
              image_id: os_tpl,
              instance_type: 't1.micro',
              min_count: 1, max_count: 1,
              user_data: '',
              monitoring: {
                enabled: false,
              },
              additional_info: serialized_mixins,
            )

            ec2_response.instances.first[:instance_id]
          end
        end

      end
    end
  end
end
