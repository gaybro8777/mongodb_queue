require 'logger'
require 'mongo'

module MongoDBQueue
  # The default queue name
  DEFAULT_QUEUE = :default_queue

  # The default status of a document that is queued.
  DEFAULT_QUEUE_STATUS = 'queued'
  
  # The default status of a document that is dequeued.
  DEFAULT_DEQUEUE_STATUS = 'dequeued'
  

  # MongoDB Backed Queue
  #
  # @author Jesse Bowes
  class MongoDBQueue
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
    # @param object [Hash] The object to queue
    # @param queue_names [Array] A list of queues to add the object to.
    # @param opts [Hash] Options
    # @option opts [String] :unique_field Prevent duplicate documents being queued on the same queue by this unique field
    def enqueue(object, queue_names = [DEFAULT_QUEUE], opts={})
      connect_mongo
      unique_field = opts[:unique_field]
      set_unique unique_field
      send_queues(queue_names, object, unique_field)
    end

    # Gets an object from a queue
    # @param queue_name [String] The queue to get the object from
    # @param opts [Hash] Options
    # @option opts [String]  :status ({DEFAULT_DEQUEUE_STATUS}) The status to mark the document as after it's dequeued.
    # @option opts [Boolean] :delete (false) Delete the object from ALL queues when dequeued.
    # @return [Hash] Queued object or nil
    def dequeue(queue_name = DEFAULT_QUEUE, opts={})
      connect_mongo
      @logger.info 'Checking queue'
      status = opts[:status] || DEFAULT_DEQUEUE_STATUS
      delete = opts[:delete]

      query = {queue: {'$elemMatch' => {name: queue_name, status: DEFAULT_QUEUE_STATUS}}}
      
      if delete
        @queue.find_and_modify(query: query, remove: true)
      else
        @queue.find_and_modify(query: query, update: {'$set' => {'queue.$.status' => status, "queue.$.#{status}_timestamp" => Time.now}})
      end
    end
    
    # Removes all MongoDB documents that have all their queue statuses set to the provided status(es).
    # @param statuses [Array] A list of queue statuses that qualify a document for removal
    # @return [Integer] Number of documents removed
    def remove_all(statuses = [DEFAULT_DEQUEUE_STATUS])
      statuses = [statuses].flatten
      num_removed = 0
      potential_items = @queue.find({'queue.status' => {'$in' => statuses}}, {fields: ['queue.status']})
      potential_items.each do |item|
        id = item['_id']
        item_statuses = item['queue'].map{|s|s['status']}
        item_statuses.uniq!
        other_statuses = item_statuses - statuses
        
        if other_statuses.empty?
          result = @queue.remove({'_id' => id})
          num_removed += result['n']
        end
      end
      num_removed
    end
    
    # Requeues all documents that were dequeued more than timeout_sec ago and have a status that is in statuses
    # @param statuses [Array] A list of queue statuses that qualify a document for requeuing
    # @return [Integer] Number of documents requeued
    def requeue_timed_out(timeout_sec, statuses = [DEFAULT_DEQUEUE_STATUS])
      statuses = [statuses].flatten
      timeout_time = Time.now - timeout_sec
      num_requeued = 0
      potential_items = @queue.find({'queue.status' => {'$in' => statuses}}, {fields: ['queue']})

      potential_items.each do |item|
        id = item['_id']
        item['queue'].each do |queue|
          queue_name = queue['name']
          status = queue['status']
          timestamp_field = "#{status}_timestamp"
          timestamp = queue[timestamp_field]
          
          if statuses.include?(status) && timestamp < timeout_time
            # Requeue this item
            result = @queue.update({'_id' => id, 'queue.name' => queue_name}, {'$set' => {'queue.$.status' => DEFAULT_QUEUE_STATUS}})
            num_requeued += result['nModified']
          end
        end
      end
      num_requeued
    end
    
    def unset_all(statueses)
      # TODO Needs Implementation.  Similar query to remove_all
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
        queues.each {|q| queue_list << {name: q, status: DEFAULT_QUEUE_STATUS, "#{DEFAULT_QUEUE_STATUS}_timestamp" => Time.now}}
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
          queue_list << {name: q, status: DEFAULT_QUEUE_STATUS, "#{DEFAULT_QUEUE_STATUS}_timestamp" => Time.now} unless exists
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
