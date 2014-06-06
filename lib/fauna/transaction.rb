module Fauna
  class Transaction
    class InvalidTransaction < StandardError; end
    class BadRequest < StandardError; end

    attr_accessor :params, :actions

    def initialize(actions = [])
      @actions = actions
      @params = {}
      yield self if block_given?
    end

    def execute(execution_params = {})
      raise(InvalidTransaction, "Transaction must include at least one action") unless @actions.length > 0

      data = { :actions => @actions.map(&:to_hash) }
      @params.merge!(execution_params)
      data[:params] = @params if @params.length > 0

      Fauna.connection.post('transactions', data)
    rescue Fauna::Connection::BadRequest => e
      raise Fauna::Transaction::BadRequest, e.message
    end

    def get(path)
      @actions << Actions.new('GET', path)
      @actions.length - 1
    end

    def post(path, body = {})
      @actions << Action.new('POST', path, body)
      @actions.length - 1
    end

    def put(path, body = {})
      @actions << Action.new('PUT', path, body)
      @actions.length - 1
    end

    def patch(path, body = {})
      @actions << Action.new('PATCH', path, body)
      @actions.length - 1
    end

    def delete(path)
      @actions << Action.new('DELETE', path)
      @actions.length - 1
    end

    def self.execute(actions = [], execution_params = {})
      transaction = Fauna::Transaction.new(actions)
      yield transaction if block_given?
      transaction.execute(execution_params)
    end

    # Escape dollar signs that would ordinarily be interpreted as transaction
    # variables.
    #
    # The default mode leaves ${variables} intact, but escapes $variables.
    # This allows values containing normal dollar signs to be used.
    #
    # mode = :strict escapes _all_ dollar signs, should the need arise.

    def self.escape(data, mode = :default)
      if data.is_a? Hash
        Hash[data.map { |key, value| [key, escape(value, mode)] }]
      elsif data.is_a? Array
        data.map { |value| escape(value, mode) }
      elsif data.respond_to? :gsub
        if mode == :strict
          data.gsub(/(\$)/, '$\0')
        else
          data.gsub(/(\$(?!\{))/, '$\0')
        end
      else
        data
      end
    end

    class Action
      attr_accessor :method, :path, :body

      # Valid attributes of "body" are:
      #
      # data => (Hash, only ${variables} may be used)
      # constraints => (Hash)
      # references => (Hash)
      # permissions => (Hash)

      def initialize(method, path, body = {})
        @method = method
        @path = path
        @body = body
      end

      def to_hash
        action = {
          :method => @method,
          :path => @path,
          :body => self.class.sanitize_body(@body)
        }
        action.delete(:body) unless action[:body].length > 0
        action
      end

      def self.sanitize_body(body)
        sanitized_body = {}
        body.keys.each do |key|
          case key.to_sym
          when :data
            # TODO: add some kind of way to indicate that the data has already been escaped
            # (probably before being added via the initializer). Maybe a DataHash delegator
            # with an 'escape' method and an :escaped accessor
            sanitized_body[key.to_sym] = Fauna::Transaction.escape(body[key])
          when :constraints, :references, :permissions
            sanitized_body[key.to_sym] = body[key]
          end
        end
        sanitized_body
      end

      def self.from_hash(hsh)
        Action.new(hsh[:method], hsh[:path], hsh.fetch(:body, {}))
      end
    end
  end
end
