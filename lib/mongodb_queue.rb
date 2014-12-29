require 'logger'
require 'mongo'

module MongoDBQueue
  # MongoDB Backed Queue
  #
  # @author Jesse Bowes
  # @since 0.0.1
  class MongoDBQueue
    # The default queue used by {#simple_enqueue} and {#simple_dequeue}
    DEFAULT_QUEUE = :default_queue

    # Initializer
    # @param settings [Hash] MongoDB connection settings
    # @option settings [String]   :address MongoDB address
    # @option settings [Integer]  :port MongoDB port
    # @option settings [String]   :database MongoDB database to use
    # @option settings [String]   :collection MongoDB collection to use
    # @option settings [String]   :username MongoDB username to use (optional)
    # @option settings [String]   :password MongoDB password to use (optional)
    # @param logger [Logger]  Use a specific logger, otherwise logs to STDOUT
    def initialize(settings, logger=nil)
      @logger = logger || Logger.new(STDOUT)
      check_settings(settings)
      @settings = settings
      @unique_fields = []
      connect_mongo
    end
    
    # Disconnects from MongoDB.  Call before exiting.
    def destroy
      begin
        disconnect_mongo
      rescue; end
    end

    # Add an object to a queue
    # @param queue_names [Array] A list of queues to add the object to 
    # @param object [Hash] The object to queue
    # @param opts [Hash] Options
    # @option opts [String] :unique_field Prevent duplicate documents being queued on the same queue by this unique field
    def enqueue(object, queue_names=[DEFAULT_QUEUE], opts={})
      connect_mongo
      unique_field = opts[:unique_field]
      set_unique unique_field
      send_queues(queue_names, object, unique_field)
    end

    # Gets an object from a queue
    # @param queue_name [String] The queue to get the object from
    # @param opts [Hash] Options
    # @option opts [String]  :status (:dequeue) The status to mark the document as after it's dequeued.
    # @option opts [Boolean] :delete (false) Delete the object from ALL queues when dequeued.
    # @return [Hash] Queued object or nil
    def dequeue(queue_name=DEFAULT_QUEUE, opts={})
      connect_mongo
      @logger.info 'Checking queue'
      status = opts[:status] || 'dequeue'
      delete = opts[:delete]

      query = {queue: {'$elemMatch' => {name: queue_name, status: :queue}}}
      
      if delete
        @queue.find_and_modify(query: query, remove: true)
      else
        @queue.find_and_modify(query: query, update: {'$set' => {'queue.$.status' => status, "queue.$.#{status}_timestamp" => Time.now}})
      end
    end
    
    private
    def check_settings(settings)
      raise 'No database address set' if settings[:address].nil?
      raise 'No database port set' if settings[:port].nil?
      raise 'No database set' if settings[:database].nil?
      raise 'No collection set' if settings[:collection].nil?
    end

    def connect_mongo
      if @client.nil? || !@client.connected?
        @client = Mongo::MongoClient.new(@settings[:address], @settings[:port])
        db = @client[@settings[:database]]
        db.authenticate(@settings[:username], @settings[:password]) if @settings[:username] || @settings[:password]
        @queue = db[@settings[:collection]]
        @queue.create_index({'queue.name' => Mongo::ASCENDING, 'queue.status' => Mongo::ASCENDING})
      end
    end

    def disconnect_mongo
      @client.close if @client
    end
    
    def set_unique(unique_field)
      if unique_field && !@unique_fields.include?(unique_field)
        @queue.create_index(unique_field, {unique: true})
        @unique_fields << unique_field
      end
    end

    def send_queues(queues, data, unique_field)
      queues = [queues].flatten
      queues.reject!{|q| q.nil? || q.empty?}
      
      queue_list = []
      
      doc = get_existing_doc(data, unique_field)

      if doc.nil?
        queues.each {|q| queue_list << {name: q, status: :queue, queue_timestamp: Time.now}}
        if queue_list.empty?
          @logger.info "Skipping item #{data.object_id}.  No destination queues."
          return nil
        else
          data[:queue] = queue_list
          @logger.info "Queuing item #{data.object_id} into #{queue_list.collect{|q|q[:name]}}"
          return @queue.insert data
        end
      else
        @logger.info "\tAlready received unique #{data[unique_field]}."
        docid = doc['_id']
        previous_queues = doc['queue']
        queues.each do |q|
          exists = previous_queues.any? {|h| h['name'] == q}
          queue_list << {name: q, status: :queue, queue_timestamp: Time.now} unless exists
        end

        if queue_list.empty?
          @logger.info "\t\tSkipping item #{data[unique_field]}.  No new queues"
          return nil
        else
          @logger.info "Queuing item #{data[unique_field]} into #{queue_list.collect{|q|q[:name]}}"
          return @queue.update({'_id' => docid}, {'$set' => data, '$addToSet' => { queue: { '$each' =>queue_list }}})
        end
      end
    end
    
    def get_existing_doc(data, unique_field)
      if unique_field
        @queue.find({unique_field => data[unique_field]}).next_document
      else
        nil
      end
    end
  end
end
