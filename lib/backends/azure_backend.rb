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
      init_client_instances

      @options.backend_scheme ||= "http://occi.#{@server_properties.hostname || 'localhost'}"

      path = @options.fixtures_dir || ''
      read_fixtures(path)
    end

    def read_fixtures(base_path)
      @logger.debug "[Backends] [AzureBackend] Reading fixtures from #{base_path.to_s.inspect}"
      # TODO: impl reading fixtures
    end

    def init_client_instances
      @base_management_service ||= ::Azure::BaseManagementService.new
      @virtual_machine_service ||= ::Azure::VirtualMachineManagementService.new
      @virtual_machine_image_service ||= ::Azure::VirtualMachineImageManagementService.new
    end

    # load helpers for JSON -> Collection conversion
    include Backends::Helpers::JsonCollectionHelper

    # hide internal stuff
    private :read_fixtures
    private :init_client_instances

    # load API implementation
    include Backends::Azure::Compute
    include Backends::Azure::Network
    include Backends::Azure::Storage
    include Backends::Azure::OsTpl
    include Backends::Azure::ResourceTpl
  end
end
