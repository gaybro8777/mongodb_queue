require_relative 'test_helper'

require 'test/unit'
require 'mongodb_queue'

class MongoDBQueueTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @config = get_config
    
    begin
      # Allow overriding of config for local testing
      require_relative 'mongo_config_helper'
      @config = MongoDBConfigHelper::config
    end

    @queue = MongoDBQueue::MongoDBQueue.new(@config)
  end

  # the uby mongo driver appears to derive _id from ruby's object id, so lets make a new object
  def get_person
    {name: 'John', age: 32, id_num: '123456789'}
  end

  # Get config or overridden config
  def get_config
    config = {
        address: 'localhost',
        port: 27017,
        database: 'test-db',
        collection: 'test-collection',
        username: 'test-user',
        password: 'test-pass'
    }

    begin
      # Allow overriding of config for local testing
      require_relative 'mongo_config_helper'
      config = MongoDBConfigHelper::config
    end
    config
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    config = get_config
    down_client = Mongo::MongoClient.new(config[:address], config[:port])
    db = down_client[config[:database]]
    db.authenticate(config[:username], config[:password]) if config[:username] || config[:password]
    collection = db[config[:collection]]
    collection.remove
    collection.drop_indexes
  end

  def assert_empty_queue(queue)
    assert_nil(@queue.dequeue(queue)) # Queue is empty
  end

  def test_initialize_no_address
    @config.delete :address
    exception = assert_raise(RuntimeError) {MongoDBQueue::MongoDBQueue.new(@config)}
    assert_equal('No database address set', exception.message)
  end

  def test_initialize_no_port
    @config.delete :port
    exception = assert_raise(RuntimeError) {MongoDBQueue::MongoDBQueue.new(@config)}
    assert_equal('No database port set', exception.message)
  end

  def test_initialize_no_db
    @config.delete :database
    exception = assert_raise(RuntimeError) {MongoDBQueue::MongoDBQueue.new(@config)}
    assert_equal('No database set', exception.message)
  end

  def test_initialize_no_collection
    @config.delete :collection
    exception = assert_raise(RuntimeError) {MongoDBQueue::MongoDBQueue.new(@config)}
    assert_equal('No collection set', exception.message)
  end
  
  def test_enqueue_dequeue
    person = get_person
    @queue.enqueue(:test_queue, person)
    dequeued = @queue.dequeue(:test_queue)

    assert_equal(person[:name], dequeued['name'])
    assert_equal(person[:age], dequeued['age'])
    assert_equal(person[:id_num], dequeued['id_num'])

    assert_empty_queue(:test_queue)
  end

  def test_queue_same_doc_twice
    @queue.enqueue(:test_queue, get_person)
    @queue.enqueue(:test_queue, get_person)
    
    person = get_person

    dequeued = @queue.dequeue(:test_queue)
    assert_equal(person[:name], dequeued['name'])
    assert_equal(person[:age], dequeued['age'])
    assert_equal(person[:id_num], dequeued['id_num'])

    dequeued2 = @queue.dequeue(:test_queue)
    assert_equal(person[:name], dequeued2['name'])
    assert_equal(person[:age], dequeued2['age'])
    assert_equal(person[:id_num], dequeued2['id_num'])

    assert_empty_queue(:test_queue)
  end

  def test_queue_unique_doc_twice
    person1 = get_person
    person2 = get_person
    
    person1[:id_num] = 123
    person2[:id_num] = person1[:id_num]
    
    puts "#{person1}"
    puts "#{person2}"

    @queue.enqueue(:test_queue, person1, {unique_field: :id_num})
    @queue.enqueue(:test_queue, person2, {unique_field: :id_num})

    dequeued = @queue.dequeue(:test_queue)
    assert_equal(person1[:name], dequeued['name'])
    assert_equal(person1[:age], dequeued['age'])
    assert_equal(person1[:id_num], dequeued['id_num'])

    assert_empty_queue(:test_queue)
    end
end