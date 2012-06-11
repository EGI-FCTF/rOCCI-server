##############################################################################
#  Copyright 2011 Service Computing group, TU Dortmund
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
##############################################################################

##############################################################################
# Description: OpenNebula Backend
# Author(s): Hayati Bice, Florian Feldhaus, Piotr Kasprzak
##############################################################################

require 'rubygems'
require 'uuidtools'
require 'oca'
require 'occi/model'

# OpenNebula backend
require 'occi/backend/opennebula/compute'
require 'occi/backend/opennebula/network'
require 'occi/backend/opennebula/storage'

# OpenNebula backend based mixins
#require 'occi/extensions/one/Image'
#require 'occi/extensions/one/Network'
#require 'occi/extensions/one/VirtualMachine'
#require 'occi/extensions/one/VNC'

#require 'occi/extensions/Reservation'

require 'occi/log'

include OpenNebula

module OCCI
  module Backend
    module OpenNebula

      # ---------------------------------------------------------------------------------------------------------------------
      class OpenNebula

        # The ACL level to be used when querying resource in OpenNebula:
        # - INFO_ALL returns all resources and works only when running under the oneadmin account
        # - INFO_GROUP returns the resources of the account + his group (= default)
        # - INFO_MINE returns only the resources of the account
        INFO_ACL = OpenNebula::Pool::INFO_GROUP

        include Compute
        include Network
        include Storage


        # Operation mappings

        OPERATIONS = { }

        OPERATIONS["http://schemas.ogf.org/occi/infrastructure#compute"] = {

            # Generic resource operations
            :deploy       => :compute_deploy,
            :update_state => :compute_update_state,
            :delete       => :compute_delete,

            # Compute specific resource operations
            :start        => :compute_start,
            :stop         => :compute_stop,
            :restart      => :compute_restart,
            :suspend      => :compute_suspend
        }

        OPERATIONS["http://schemas.ogf.org/occi/infrastructure#network"] = {

            # Generic resource operations
            :deploy       => :network_deploy,
            :update_state => :network_update_state,
            :delete       => :network_delete,

            # Network specific resource operations
            :up           => :network_up,
            :down         => :network_down
        }

        OPERATIONS["http://schemas.ogf.org/occi/infrastructure#storage"] = {

            # Generic resource operations
            :deploy       => :storage_deploy,
            :update_state => :storage_update_state,
            :delete       => :storage_delete,

            # Network specific resource operations
            :online       => :storage_online,
            :offline      => :storage_offline,
            :backup       => :storage_backup,
            :snapshot     => :storage_snapshot,
            :resize       => :storage_resize
        }

        # ---------------------------------------------------------------------------------------------------------------------       
        #        private
        # ---------------------------------------------------------------------------------------------------------------------

        # ---------------------------------------------------------------------------------------------------------------------      
        def check_rc(rc)
          if rc.class == Error
            raise OCCI::BackendError, "Error message from OpenNebula: #{rc.to_str}"
            # TODO: return failed!
          end
        end

        # ---------------------------------------------------------------------------------------------------------------------
        # Generate a new occi id for resources created directly in OpenNebula using a seed id and the kind identifier
        def generate_occi_id(kind, seed_id)
          # Use strings as kind ids
          kind = kind.type_identifier if kind.kind_of?(OCCI::Core::Kind)
          return UUIDTools::UUID.sha1_create(UUIDTools::UUID_DNS_NAMESPACE, "#{kind}:#{seed_id}").to_s
        end

        # ---------------------------------------------------------------------------------------------------------------------
        public
        # ---------------------------------------------------------------------------------------------------------------------

        # ---------------------------------------------------------------------------------------------------------------------     
        def initialize(user, password)

          # TODO: create mixins from existing templates

          # initialize OpenNebula connection
          OCCI::Log.debug("### Initializing connection with OpenNebula")

          # TODO: check for error!
          #       @one_client = Client.new(OCCI::Server.config['one_user'] + ':' + OCCI::Server.config['one_password'], OCCI::Server.config['one_xmlrpc'])
          @one_client = Client.new(user + ':' + password, OCCI::Server.config['one_xmlrpc'])

        end

        # ---------------------------------------------------------------------------------------------------------------------     
        def register_existing_resources
          # get all compute objects
          resource_template_register
          os_template_register
          compute_register_all_instances
          network_register_all_instances
          storage_register_all_instances
        end

        # ---------------------------------------------------------------------------------------------------------------------     
        def resource_template_register
          # currently not directly supported by OpenNebula
        end

        # ---------------------------------------------------------------------------------------------------------------------     
        def os_template_register
          backend_object_pool=TemplatePool.new(@one_client, INFO_ACL)
          backend_object_pool.info
          backend_object_pool.each do |backend_object|
            related = %w|http://schemas.ogf.org/occi/infrastructure#os_tpl|
            term    = backend_object['NAME'].downcase.chomp.gsub(/\W/, '_')
            # TODO: implement correct schema for service provider
            scheme  = OCCI::Server.location + "/occi/infrastructure/os_tpl#"
            title   = backend_object['NAME']
            mixin   = Hashie::Mash.new(:related => related, :term => term, :scheme => scheme, :title => title)
            mixin   = OCCI::Core::Mixin.new(mixin)
            OCCI::Model.register(mixin)
          end
        end

      end

    end
  end
end
