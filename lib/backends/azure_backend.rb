module Backends
  class AzureBackend
    API_VERSION = '0.0.1'

    def initialize(delegated_user, options, server_properties, logger, dalli_cache)
      @delegated_user = Hashie::Mash.new(delegated_user)
      @options = Hashie::Mash.new(options)
      @server_properties = Hashie::Mash.new(server_properties)
      @logger = logger || Rails.logger
      @dalli_cache = dalli_cache

      path = @options.fixtures_dir || ''
      read_fixtures(path)
    end

    def read_fixtures(base_path)
      @logger.debug "[Backends] [AzureBackend] Reading fixtures from #{base_path.to_s.inspect}"
      # TODO: impl reading fixtures
    end

    # load helpers for JSON -> Collection conversion
    include Backends::Helpers::JsonCollectionHelper

    # hide internal stuff
    private :read_fixtures

    # load API implementation
    include Backends::Azure::Compute
    include Backends::Azure::Network
    include Backends::Azure::Storage
    include Backends::Azure::OsTpl
    include Backends::Azure::ResourceTpl
  end
end
