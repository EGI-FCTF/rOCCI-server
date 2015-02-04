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
      init_client_instances!

      @options.backend_scheme ||= "http://occi.#{@server_properties.hostname || 'localhost'}"

      path = @options.fixtures_dir || ''
      read_resource_tpl_fixtures(path)
    end

    def init_client_instances!
      @logger.debug "[Backends] [AzureBackend] Initializing Azure service clients"
      @base_management_service ||= ::Azure::BaseManagementService.new
      @virtual_machine_service ||= ::Azure::VirtualMachineManagementService.new
      @virtual_machine_image_service ||= ::Azure::VirtualMachineImageManagementService.new
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
  end
end
