module Fauna
  class NoContextError < StandardError; end
  class InvalidTransaction < StandardError; end

  class Cache
    attr_reader :connection

    def initialize(connection)
      raise ArgumentError, "Connection cannot be nil" unless connection
      @cache = {}
      @connection = connection
    end

    def get(ref, query = {}, pagination = {})
      res = @cache[ref]
      res = @cache[res] if res.is_a? String # non-canonical refs point to their canonical refs.

      if res.nil?
        response = @connection.get(ref, query.merge(pagination))
        update_cache(ref, response)
        res = response['resource']
      end

      res
    end

    def post(ref, data)
      res = @connection.post(ref, data)
      update_cache(ref, res)
      res['resource']
    end

    def put(ref, data)
      res = @connection.put(ref, data)
      if res['resource']
        update_cache(ref, res)
        res['resource']
      end
    end

    def patch(ref, data)
      res = @connection.patch(ref, data)
      if res['resource']
        update_cache(ref, res)
        res['resource']
      end
    end

    def delete(ref, data)
      @connection.delete(ref, data)
      @cache.delete(ref)
      nil
    end

    def post_transaction(data)
      actions = data.fetch(:actions, [])
      raise(InvalidTransaction, "Transaction must include at least one action") unless actions.length > 0

      res = @connection.post_transaction(data)

      if actions.last[:method] == 'DELETE'
        @cache.delete(actions.last[:path])
        nil
      else
        if res['resource'] # the res returned by @connection should always be a hash if the method isn't DELETE 
          update_cache(actions.last[:path], res) # but how to deal with transaction vars ($0)
          res['resource']
        end
      end
    end

    private

    def update_cache(ref, res)
      # FIXME Implement set range caching
      if (res['resource']['class'] != "resources" && res['resource']['class'] != "events")
        @cache[ref] = res['resource']['ref'] # store the non-canonical ref as a pointer to the real one.
        @cache[res['resource']['ref']] = res['resource']
      end
      @cache.merge!(res['references'] || {})
    end
  end
end
