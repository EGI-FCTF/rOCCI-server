require 'backends/opennebula/base'

module Backends
  module Opennebula
    class Storage < Base
      include Backends::Helpers::Entitylike
      include Backends::Helpers::AttributesTransferable
      include Backends::Helpers::MixinsAttachable
      include Backends::Helpers::ErbRenderer

      class << self
        # @see `served_class` on `Entitylike`
        def served_class
          Occi::Infrastructure::Storage
        end

        # :nodoc:
        def entity_identifier
          Occi::Infrastructure::Constants::STORAGE_KIND
        end
      end

      # @see `Entitylike`
      def identifiers(_filter = Set.new)
        Set.new(pool(:image, :info_mine).map { |im| im['ID'] })
      end

      # @see `Entitylike`
      def list(_filter = Set.new)
        coll = Occi::Core::Collection.new
        pool(:image, :info_mine).each { |image| coll << storage_from(image) }
        coll
      end

      # @see `Entitylike`
      def instance(identifier)
        image = ::OpenNebula::Image.new_with_id(identifier, raw_client)
        client(Errors::Backend::EntityStateError) { image.info }
        storage_from(image)
      end

      # @see `Entitylike`
      def create(instance)
        image_template = image_from(instance)
        ds_id = candidate_datastore(instance)

        image = ::OpenNebula::Image.new(::OpenNebula::Image.build_xml, raw_client)
        client(Errors::Backend::EntityCreateError) { image.allocate(image_template, ds_id) }
        client(Errors::Backend::EntityStateError) { image.info }

        image['ID']
      end

      # @see `Entitylike`
      def delete(identifier)
        image = ::OpenNebula::Image.new_with_id(identifier, raw_client)
        client(Errors::Backend::EntityStateError) { image.delete }
      end

      private

      # Converts a ONe image instance to a valid storage instance.
      #
      # @param image [OpenNebula::Image] instance to transform
      # @return [Occi::Infrastructure::Storage] transformed instance
      def storage_from(image)
        storage = instance_builder.get(self.class.entity_identifier)

        attach_mixins! image, storage
        transfer_attributes! image, storage, Constants::Storage::TRANSFERABLE_ATTRIBUTES
        enable_actions!(storage)

        storage
      end

      # Converts an OCCI storage instance to a valid ONe image template.
      #
      # @param storage [Occi::Infrastructure::Storage] instance to transform
      # @return [String] ONe template
      def image_from(storage)
        template_path = File.join(template_directory, 'storage.erb')
        data = { instance: storage, identity: active_identity }
        erb_render template_path, data
      end

      # :nodoc:
      def attach_mixins!(image, storage)
        storage << server_model.find_regions.first

        ds = ::OpenNebula::Datastore.new_with_id(image['DATASTORE_ID'], raw_client)
        client(Errors::Backend::EntityStateError) { ds.info }
        ds.each_xpath('CLUSTERS/ID') do |cid|
          attach_optional_mixin! storage, cid, :availability_zone
        end
      end

      # :nodoc:
      def enable_actions!(storage)
        return unless storage['occi.storage.state'] == 'online'
        Constants::Storage::ONLINE_ACTIONS.each { |a| storage.enable_action(a) }
      end

      # :nodoc:
      def candidate_datastore(instance)
        azs = instance.availability_zones.map(&:term)
        azs << default_cluster if azs.empty?

        azs.sort!
        cds = pool(:datastore).detect { |ds| ds.type_str == 'IMAGE' && (azs - clusters(ds)).empty? }
        cds ? cds.id : raise(Errors::Backend::EntityStateError, 'Storage spanning requested zones cannot be created')
      end

      # :nodoc:
      def clusters(element)
        cids = []
        element.each_xpath('CLUSTERS/ID') { |cid| cids << cid }
        cids
      end

      # :nodoc:
      def whereami
        File.expand_path(File.dirname(__FILE__))
      end
    end
  end
end
