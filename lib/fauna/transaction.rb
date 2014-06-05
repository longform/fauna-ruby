module Fauna
  class Client
    def transaction
      # push context?
      t = Fauna::Transaction.new
      yield t if block_given?
      t.execute
      # pop context?
    end
  end

  class Transaction
    # A transaction object could store actions and turn them into a transaction
    # Hypothetical example
    # Fauna::Client.transaction do |t|
    #  t.post('some/ref', { :some => :data})
    #  t.delete('some/other/ref')
    #  t.put('some/singleton/update/whatever')
    # end

    def initialize
      @actions = {}
    end

    def post(path, data)
      @actions << { :method => 'POST', :path => path, :data => data }
    end

    def put(path, data)
      @actions << { :method => 'PUT', :path => path, :data => data }
    end

    def patch(path, data)
      @actions << { :method => 'PATCH', :path => path, :data => data }
    end

    def delete(path)
      @actions << { :method => 'DELETE', :path => path, :data => data }
    end

    def execute
      Fauna::Client.post('transaction', { :actions => actions }) # may need some work in Fauna::Cache
    end
  end
end
