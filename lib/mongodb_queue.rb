require 'logger'
require 'mongo'

module MongoDBQueue
  class MongoDBQueue
    
    # settings
    #  :address
    #  :port
    #  :database
    #  :collection
    #  :username => optional
    #  :password => optional
    def initialize(settings, logger=nil)
      @logger = logger || Logger.new(STDOUT)
      check_settings(settings)
      @settings = settings
      @unique_fields = []
      connect_mongo
    end
    
    def destroy
      begin
        disconnect_mongo
      rescue; end
    end
    
    # opts:
    #  :unique_field => Prevent duplicate documents being queued on the same queue by this unique field
    def enqueue(queue_names, object, opts={})
      connect_mongo
      unique_field = opts[:unique_field]
      set_unique unique_field
      send_queues(queue_names, object, unique_field)
    end
    
    # opts
    #  :status => default: dequeue
    #  :delete => default false.  Be careful with this if using multiple queues as it deletes the document from all queues.
    def dequeue(queue_name, opts={})
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
        db = @client[@settings[:name]]
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

    def send_queues(data, queues, unique_field)
      queues = [queues].flatten
      queue_list = []
      
      doc = get_existing_doc(unique_field)

      if doc.nil?
        queues.each {|q| queue_list << {name: q, status: :queue, queue_timestamp: Time.now}}
        if queue_list.empty?
          @logger.info "Skipping item #{data.object_id}.  No destination queues."
        else
          data[:queue] = queue_list
          @logger.info "\tQueuing item #{data.object_id} into #{queue_list.collect{|q|q[:name]}}"
          @queue.insert data
        end
      else
        @logger.info "\tAlready received unique #{data[unique_field]}."
        docid = doc['_id']
        prevous_queues = doc['queue']
        queues.each do |q|
          exists = prevous_queues.any? {|h| h['name'] == q}
          queue_list << {name: q, status: :queue, queue_timestamp: Time.now} unless exists
        end

        if queue_list.empty?
          @logger.info "\t\tSkipping item #{data[unique_field]}.  No new queues"
        else
          @logger.info "\t\tQueuing item #{data[unique_field]} into #{queue_list.collect{|q|q[:name]}}"
          @queue.update({'_id' => docid}, {'$set' => data, '$addToSet' => { queue: { '$each' =>queue_list }}})
        end
      end
    end
    
    def get_existing_doc(unique_field)
      if unique_field
        @queue.find({unique_field => data[:sha256]}).next_document
      else
        nil
      end
    end
  end
end
