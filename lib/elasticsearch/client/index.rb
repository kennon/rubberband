require 'client/hits'

module ElasticSearch
  module Api
    module Index
      def index(document, options={})
        index, type, options = extract_required_scope(options)
        # type
        # index
        # id (optional)
        # op_type (optional)
        # timeout (optional)
        # document (optional)

        id = options.delete(:id)
        if @batch
          @batch << { :index => { :_index => index, :_type => type, :_id => id }}
          @batch << document
        else
          result = execute(:index, index, type, id, document, options)
          if result["ok"]
            result["_id"]
          else
            false
          end
        end
      end

      def get(id, options={})
        index, type, options = extract_required_scope(options)
        # index
        # type
        # id
        # fields
        
        hit = execute(:get, index, type, id, options)
        if hit
          Hit.new(hit).freeze
        end
      end

      def delete(id, options={})
        index, type, options = extract_required_scope(options)

        if @batch
          @batch << { :delete => { :_index => index, :_type => type, :_id => id }}
        else
          result = execute(:delete, index, type, id, options)
          result["ok"]
        end
      end

      def mlt(id, options={})
        set_default_scope!(options)
        raise "index and type or defaults required" unless options[:index] && options[:type]
        # index
        # type
        # id
        # fields
        
        response = execute(:mlt, options[:index], options[:type], id, options)
        Hits.new(response, slice_hash(options, :per_page, :page, :ids_only)).freeze #ids_only returns array of ids 
      end

      #df	 The default field to use when no field prefix is defined within the query.
      #analyzer	 The analyzer name to be used when analyzing the query string.
      #default_operator	 The default operator to be used, can be AND or OR. Defaults to OR.
      #explain	 For each hit, contain an explanation of how to scoring of the hits was computed.
      #fields	 The selective fields of the document to return for each hit (fields must be stored), comma delimited. Defaults to the internal _source field.
      #field	 Same as fields above, but each parameter contains a single field name to load. There can be several field parameters.
      #sort	 Sorting to perform. Can either be in the form of fieldName, or fieldName:reverse (for reverse sorting). The fieldName can either be an actual field within the document, or the special score name to indicate sorting based on scores. There can be several sort parameters (order is important).
      #from	 The starting from index of the hits to return. Defaults to 0.
      #size	 The number of hits to return. Defaults to 10.
      #search_type	 The type of the search operation to perform. Can be dfs_query_then_fetch, dfs_query_and_fetch, query_then_fetch, query_and_fetch. Defaults to query_then_fetch.
      #scroll Get a scroll id to continue paging through the search results. Value is the time to keep a scroll request around, e.g. 5m
      #ids_only Return ids instead of hits
      def search(query, options={})
        index, type, options = extract_scope(options)

        options[:size] ||= (options[:per_page] || options[:limit] || 10)
        options[:from] ||= options[:size] * (options[:page].to_i-1) if options[:page] && options[:page].to_i > 1
        options[:from] ||= options[:offset] if options[:offset]

        options[:fields] = "_id" if options[:ids_only]

        # options that hits take: per_page, page, ids_only
        hits_options = options.select { |k, v| [:per_page, :page, :ids_only].include?(k) }

        # options that elasticsearch doesn't recognize: page, per_page, ids_only, limit, offset
        options.reject! { |k, v| [:page, :per_page, :ids_only, :limit, :offset].include?(k) }

        response = execute(:search, index, type, query, options)
        Hits.new(response, hits_options).freeze #ids_only returns array of ids instead of hits
      end

      #ids_only Return ids instead of hits
      def scroll(scroll_id, options={})
        response = execute(:scroll, scroll_id)
        Hits.new(response, { :ids_only => options[:ids_only] }).freeze
      end 

      #df	 The default field to use when no field prefix is defined within the query.
      #analyzer	 The analyzer name to be used when analyzing the query string.
      #default_operator	 The default operator to be used, can be AND or OR. Defaults to OR.
      def count(query, options={})
        index, type, options = extract_scope(options)

        response = execute(:count, index, type, query, options)
        response["count"].to_i #TODO check if count is nil
      end

      # Starts a bulk operation batch and yields self. Index and delete requests will be 
      # queued until the block closes, then sent as a single _bulk call.
      def bulk
        @batch = []
        yield(self)
        response = execute(:bulk, @batch)
      ensure
        @batch = nil
      end

    end
  end
end
