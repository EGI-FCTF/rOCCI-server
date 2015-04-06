module Backends
  module Azure
    module OsTpl

      AZURE_IMAGE_TERM = /^uuid_(?<image_name>.+)__(?<image_hash>[[:alnum:]]{40})$/

      # Gets backend-specific `os_tpl` mixins which should be merged
      # into Occi::Model of the server.
      #
      # @example
      #    mixins = os_tpl_list #=> #<Occi::Core::Mixins>
      #    mixins.first #=> #<Occi::Core::Mixin>
      #
      # @return [Occi::Core::Mixins] a collection of mixins
      def os_tpl_list
        mixins = Occi::Core::Mixins.new

        Backends::Azure::Helpers::AzureConnectHelper.rescue_azure_service(@logger) do
          @virtual_machine_image_service.list_virtual_machine_images.each do |azure_image|
            mixins << os_tpl_list_mixin_from_image(azure_image) if azure_image
          end
        end

        mixins
      end

      # Gets a specific os_tpl mixin instance as Occi::Core::Mixin.
      # Term given as an argument must match the term inside
      # the returned Occi::Core::Mixin instance.
      #
      # @example
      #    os_tpl = os_tpl_get('65d4f65adfadf-ad2f4ad-daf5ad-f5ad4fad4ffdf')
      #        #=> #<Occi::Core::Mixin>
      #
      # @param term [String] OCCI term of the requested os_tpl mixin instance
      # @return [Occi::Core::Mixin, nil] a mixin instance or `nil`
      def os_tpl_get(term)
        azure_image = os_tpl_list_term_to_image(term)
        os_tpl_list_mixin_from_image(azure_image)
      end

      private

      #
      #
      def os_tpl_list_term_to_image_name(mixin_term)
        os_tpl_list_term_to_image(mixin_term).name
      end

      #
      #
      def os_tpl_list_mixin_from_image(azure_image)
        depends = %w|http://schemas.ogf.org/occi/infrastructure#os_tpl|
        term = os_tpl_list_image_to_term(azure_image)
        scheme = "#{@options.backend_scheme}/occi/infrastructure/os_tpl#"
        title = azure_image.name || 'unknown'
        location = "/mixin/os_tpl/#{term}/"
        applies = %w|http://schemas.ogf.org/occi/infrastructure#compute|

        Occi::Core::Mixin.new(scheme, term, title, nil, depends, nil, location, applies)
      end

      #
      #
      def os_tpl_list_image_to_term(azure_image)
        azure_image_name = azure_image.name.downcase
        azure_image_name.gsub!(/[^a-z0-9\-]/, '_')
        azure_image_name.gsub!(/_+/, '_')
        azure_image_name.gsub!(/^_|_$/, '')

        "uuid_#{azure_image_name}__#{::Digest::SHA1.hexdigest(azure_image.name)}"
      end

      #
      #
      def os_tpl_list_term_to_image(mixin_term)
        azure_image_hash = os_tpl_list_term_to_image_hash(mixin_term)
        fail Backends::Errors::ResourceNotValidError,
            "Invalid os_tpl mixin format! #{mixin_term.inspect}" unless azure_image_hash

        azure_image = Backends::Azure::Helpers::AzureConnectHelper.rescue_azure_service(@logger) do
          @virtual_machine_image_service.list_virtual_machine_images.select do |azure_image|
            ::Digest::SHA1.hexdigest(azure_image.name) == azure_image_hash
          end
        end

        fail Backends::Errors::ResourceNotFoundError,
            "There is no such os_tpl mixin! #{mixin_term.inspect}" unless azure_image.first

        azure_image.first
      end

      #
      #
      def os_tpl_list_term_to_image_hash(mixin_term)
        matched = AZURE_IMAGE_TERM.match(mixin_term)
        matched ? matched[:image_hash] : nil
      end

    end
  end
end
