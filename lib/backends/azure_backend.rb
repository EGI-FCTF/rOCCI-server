module Backends
  class AzureBackend
    API_VERSION = '0.0.1'

    def initialize(delegated_user, options, server_properties, logger, dalli_cache)
      @delegated_user = Hashie::Mash.new(delegated_user)
      @options = Hashie::Mash.new(options)
      @server_properties = Hashie::Mash.new(server_properties)
      @logger = logger || Rails.logger
      @dalli_cache = dalli_cache

      # configure and initialize client instances
      ::Azure.configure do |config|
        # configure virtual machine management access
        config.management_certificate = @options.management_certificate
        config.subscription_id        = @options.subscription_id
        config.management_endpoint    = @options.management_endpoint || "https://management.core.windows.net"
      end

      @options.backend_scheme ||= "http://occi.#{@server_properties.hostname || 'localhost'}"

      path = @options.fixtures_dir || ''
      read_resource_tpl_fixtures(path)
    end

    def init_client_instances!
      return false if @base_management_service && @virtual_machine_service && @virtual_machine_image_service

      @logger.debug "[Backends] [AzureBackend] Initializing Azure service clients"
      @base_management_service ||= ::Azure::BaseManagementService.new
      @virtual_machine_service ||= ::Azure::VirtualMachineManagementService.new
      @virtual_machine_image_service ||= ::Azure::VirtualMachineImageManagementService.new

      true
    end

    def read_resource_tpl_fixtures(base_path)
      path = File.join(base_path, 'resource_tpl', '*.json')
      @resource_tpl = Occi::Core::Mixins.new

      Dir.glob(path) do |json_file|
        @resource_tpl.merge(read_from_json(json_file).mixins) if File.readable?(json_file)
      end
    end

    # load helpers for JSON -> Collection conversion
    include Backends::Helpers::JsonCollectionHelper

    # hide internal stuff
    private :read_resource_tpl_fixtures
    private :init_client_instances!

    # load API implementation
    include Backends::Azure::Compute
    include Backends::Azure::Network
    include Backends::Azure::Storage
    include Backends::Azure::OsTpl
    include Backends::Azure::ResourceTpl

    # run authN code before every method
    extend Backends::Helpers::RunBeforeHelper::ClassMethods

    def run_authn
      begin
        init_client_instances!
      rescue => ex
        @logger.fatal "[Backends] [AzureBackend] Instantiating service clients: #{ex.message}"
        fail Backends::Errors::AuthenticationError, 'Could not get an EC2 client for the current user!'
      end
    end
    private :run_authn

    run_before(instance_methods, :run_authn, true)
  end
end
