# monkey-patch Azure's crazy-ass logging
if defined?(::Loggerx)
  module CustomAzureLogger
    DEFAULT_LOGGER = Rails.logger

    class << self
      def info(msg)
        DEFAULT_LOGGER.info "[#{self.name}] #{msg}"
      end

      def error_with_exit(msg)
        DEFAULT_LOGGER.fatal "[#{self.name}] #{msg}"
        raise msg
      end

      def warn(msg)
        DEFAULT_LOGGER.warn "[#{self.name}] #{msg}"
        msg
      end

      def error(msg)
        DEFAULT_LOGGER.error "[#{self.name}] #{msg}"
        msg
      end

      def exception_message(msg)
        DEFAULT_LOGGER.fatal "[#{self.name}] #{msg}"
        raise msg
      end

      def success(msg)
        info(msg)
      end
    end
  end

  silence_warnings { ::Loggerx = CustomAzureLogger }
end
