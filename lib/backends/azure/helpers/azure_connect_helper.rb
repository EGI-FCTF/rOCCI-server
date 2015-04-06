module Backends
  module Azure
    module Helpers
      module AzureConnectHelper

        # Wraps calls to Azure and provides basic error handling.
        # This method requires a block, if no block is given a
        # {Backends::Errors::StubError} error is raised.
        #
        # @example
        #     Backends::Azure::Helpers::AzureConnectHelper.rescue_azure_service(@logger) do
        #       @virtual_machine_service.list_virtual_machines
        #     end
        #
        # @param logger [Logger] instance of a logging facility
        # @effects <i>none</i>: call answered from within the backend
        def self.rescue_azure_service(logger)
          fail Backends::Errors::StubError, 'Azure service-wrapper was called without a block!' unless block_given?

          begin
            yield
          rescue ::Azure::Core::Http::HTTPError => e
            handle_service_error(e, logger)
          rescue => e
            # re-raise our errors
            fail e if e.class.name.start_with?('Backends::Errors::')

            # convert unknown errors
            logger.error "[Backends] [AzureBackend] Generic Error: #{e.message}"
            fail Backends::Errors::ResourceActionError, e.message
          end
        end

        # Converts Azure error codes to errors understood by rOCCI-server.
        # This method will ALWAYS raise an error.
        #
        # @param error [::Azure::Core::Http::HTTPError] Azure HTTP error instance
        # @param logger [Logger] instance of a logging facility
        # @effects <i>none</i>: call answered from within the backend
        def self.handle_service_error(error, logger)
          logger.debug "[Backends] [AzureBackend] #{error.type}: #{error.detail}"
          message = "#{error.type}: #{error.description}"

          case error.status_code
          when 503, 504
            # service is not available, probably Azure's fault
            fail Backends::Errors::ServiceUnavailableError, message
          when 401
            # something is wrong with our credentials
            fail Backends::Errors::AuthenticationError, message
          when 403
            # not allowed to do that
            fail Backends::Errors::UserNotAuthorizedError, message
          when 405, 406
            # action wasn't allowed in this state or context
            fail Backends::Errors::ResourceStateError, message
          when 400
            # something was wrong with our request
            fail Backends::Errors::ResourceCreationError, message
          when 404
            # it's not there anymore
            fail Backends::Errors::ResourceNotFoundError, message
          when 409
            # what we sent was malformed or didn't have the proper format
            fail Backends::Errors::IdentifierNotValidError, message
          else
            # internal or unexpected errors
            fail Backends::Errors::ResourceActionError, message
          end
        end

      end
    end
  end
end
