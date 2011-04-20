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
        
        def self.solr_execute_search_ids(options = {})
          search = yield
          search.raw_results.map { |raw_result| raw_result.primary_key }
        end
        
        def self.solr_clean_index_orphans
          solr_index_diff[:orphans].each do |id|
            Sunspot.remove_by_id(self.class, id)
          end
          Sunspot.commit
        end
        
        def self.solr_reindex_missing
          Sunspot.index!(find(solr_index_diff[:missing]))
        end
        
        def self.solr_index_diff
          indexed_ids = solr_search_ids { paginate(:page => 1, :per_page => (self.count*10)) }
          all_ids = only(:id).map {|d| d.id.to_s}
          missing = all_ids - indexed_ids
          orphans = indexed_ids - all_ids
          return {:missing => missing, :orphans => orphans}
        end
        
        def self.solr_repair_index
          diff = solr_index_diff
          diff[:orphans].each {|id| Sunspot.remove_by_id(self.class, id) }
          Sunspot.index(find(diff[:missing]))
          Sunspot.commit
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
        @clazz.find(BSON::ObjectID.from_string(id)) rescue nil
      end

      def load_all(ids)
        @clazz.where(:_id.in => ids.map { |id| BSON::ObjectId.from_string(id) })
      end
      
    end
  end
end
