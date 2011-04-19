require 'sunspot'
require 'mongoid'
require 'sunspot/rails'

# == Examples:
#
# class Post
#   include Mongoid::Document
#   field :title
# 
#   include Sunspot::Mongoid
#   searchable do
#     text :title
#   end
# end
#
module Sunspot
  module Mongoid
    def self.included(base)
      base.class_eval do
        extend Sunspot::Rails::Searchable::ActsAsMethods
        Sunspot::Adapters::DataAccessor.register(DataAccessor, base)
        Sunspot::Adapters::InstanceAdapter.register(InstanceAdapter, base)
        
        def self.solr_index_orphans
          count = self.count
          indexed_ids = solr_search_ids { paginate(:page => 1, :per_page => count) }.to_set
          only(:id).each do |object|
            indexed_ids.delete(object.id.to_s)
          end
          indexed_ids.to_a
        end
        
        def self.solr_execute_search_ids(options = {})
          search = yield
          search.raw_results.map { |raw_result| raw_result.primary_key }
        end
        
        def self.solr_clean_index_orphans
          Sunspot.remove_by_id!(self.class, solr_index_orphans)
        end
        
        
      end
    end

    class InstanceAdapter < Sunspot::Adapters::InstanceAdapter
      def id
        @instance.id
      end
    end

    class DataAccessor < Sunspot::Adapters::DataAccessor
      def load(id)
        @clazz.find(id) rescue nil
      end

      def load_all(ids)
        @clazz.where(:_id.in => ids.map { |id| BSON::ObjectId.from_string(id) })
      end
      
    end
  end
end
