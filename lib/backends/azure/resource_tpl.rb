module Backends
  module Azure
    module ResourceTpl

      AZURE_SIZE_TERM = /^uuid_(?<size_name>.+)__(?<size_hash>[[:alnum:]]{40})$/

      # Gets platform- or backend-specific `resource_tpl` mixins which should be merged
      # into Occi::Model of the server.
      #
      # @example
      #    mixins = resource_tpl_list #=> #<Occi::Core::Mixins>
      #    mixins.first  #=> #<Occi::Core::Mixin>
      #
      # @return [Occi::Core::Mixins] a collection of mixins
      def resource_tpl_list
        mixins = Occi::Core::Mixins.new

        @resource_tpl.to_a.each do |res_m|
          mixins << Occi::Core::Mixin.new(
            res_m.scheme,
            resource_tpl_list_size_name_to_term(res_m.term),
            res_m.title,
            res_m.attributes,
            res_m.depends,
            res_m.actions,
            res_m.location,
            res_m.applies
          )
        end

        mixins
      end

      # Gets a specific resource_tpl mixin instance as Occi::Core::Mixin.
      # Term given as an argument must match the term inside
      # the returned Occi::Core::Mixin instance.
      #
      # @example
      #    resource_tpl = resource_tpl_get('65d4f65adfadf-ad2f4ad-daf5ad-f5ad4fad4ffdf')
      #        #=> #<Occi::Core::Mixin>
      #
      # @param term [String] OCCI term of the requested resource_tpl mixin instance
      # @return [Occi::Core::Mixin, nil] a mixin instance or `nil`
      def resource_tpl_get(term)
        found = resource_tpl_list_term_to_original_mixin(term)

        Occi::Core::Mixin.new(
          found.scheme,
          resource_tpl_list_size_name_to_term(found.term),
          found.title,
          found.attributes,
          found.depends,
          found.actions,
          found.location,
          found.applies
        )
      end

      private

      #
      #
      def resource_tpl_list_term_to_size_name(mixin_term)
        resource_tpl_list_term_to_original_mixin(mixin_term).term
      end

      #
      #
      def resource_tpl_list_term_to_original_mixin(mixin_term)
        azure_size_hash = resource_tpl_list_term_to_size_hash(mixin_term)
        fail Backends::Errors::ResourceNotValidError,
            "Invalid resource_tpl mixin format! #{mixin_term.inspect}" unless azure_size_hash

        found = @resource_tpl.to_a.select { |m| ::Digest::SHA1.hexdigest(m.term) == azure_size_hash }.first
        fail Backends::Errors::ResourceNotFoundError,
            "There is no such resource_tpl mixin! #{mixin_term.inspect}" unless found
        found
      end

      #
      #
      def resource_tpl_list_term_to_size_hash(mixin_term)
        matched = AZURE_SIZE_TERM.match(mixin_term)
        matched ? matched[:size_hash] : nil
      end

      #
      #
      def resource_tpl_list_size_name_to_term(azure_size_name)
        azure_size_name_fixed = azure_size_name.downcase
        azure_size_name_fixed.gsub!(/[^a-z0-9\-]/, '_')
        azure_size_name_fixed.gsub!(/_+/, '_')
        azure_size_name_fixed.gsub!(/^_|_$/, '')

        "uuid_#{azure_size_name_fixed}__#{::Digest::SHA1.hexdigest(azure_size_name)}"
      end

    end
  end
end
