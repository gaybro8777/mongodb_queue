require_relative 'test_helper'

require 'test/unit'
require 'mongodb_queue'

class MongoDBQueueTest < Test::Unit::TestCase

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @config = get_config
    @queue = MongoDBQueue::MongoDBQueue.new(@config)
    
    @inspect_queue = connect_queue
  end

  # the uby mongo driver appears to derive _id from ruby's object id, so lets make a new object
  def get_person
    {name: 'John', age: 32, id_num: '123456789'}
  end

  # Get config or overridden config
  def get_config
    begin
      # Allow overriding of config for local testing
      require_relative 'mongo_config_helper'
      config = MongoDBConfigHelper::config
    rescue LoadError
      config = {
          address: 'localhost',
          port: 27017,
          database: 'test-db',
          collection: 'test-collection',
          username: 'test-user',
          password: 'test-pass'
      }
    end
    config
  end
  
  def connect_queue
    config = get_config
    @inspect_client = Mongo::MongoClient.new(config[:address], config[:port])
    db = @inspect_client[config[:database]]
    db.authenticate(config[:username], config[:password]) if config[:username] || config[:password]
    db[config[:collection]]
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.
  def teardown
    @inspect_queue.remove
    @inspect_queue.drop_indexes
    @inspect_client.close
    @queue.destroy
  end

  def assert_empty_queue(queue = MongoDBQueue::DEFAULT_QUEUE)
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
    assert_not_nil @queue.enqueue(person)
    dequeued = @queue.dequeue

    assert_equal(person[:name], dequeued['name'])
    assert_equal(person[:age], dequeued['age'])
    assert_equal(person[:id_num], dequeued['id_num'])

    assert_nil(@queue.dequeue)
    assert_not_nil @inspect_queue.find.next_document
  end
  
  def test_enqueue_dequeue_delete
    person = get_person
    assert_not_nil @queue.enqueue(person)
    dequeued = @queue.dequeue(MongoDBQueue::DEFAULT_QUEUE, {delete: true})

    assert_equal(person[:name], dequeued['name'])
    assert_equal(person[:age], dequeued['age'])
    assert_equal(person[:id_num], dequeued['id_num'])

    assert_nil(@queue.dequeue)
    assert_nil @inspect_queue.find.next_document
  end
  
  def test_enqueue_dequeue_with_queue
    person = get_person
    assert_not_nil @queue.enqueue(person, :test_queue)
    dequeued = @queue.dequeue(:test_queue)

    assert_equal(person[:name], dequeued['name'])
    assert_equal(person[:age], dequeued['age'])
    assert_equal(person[:id_num], dequeued['id_num'])

    assert_empty_queue(:test_queue)
  end

  def test_queue_same_doc_twice
    assert_not_nil @queue.enqueue(get_person)
    assert_not_nil @queue.enqueue(get_person)
    
    person = get_person

    dequeued = @queue.dequeue
    assert_equal(person[:name], dequeued['name'])
    assert_equal(person[:age], dequeued['age'])
    assert_equal(person[:id_num], dequeued['id_num'])

    dequeued2 = @queue.dequeue
    assert_equal(person[:name], dequeued2['name'])
    assert_equal(person[:age], dequeued2['age'])
    assert_equal(person[:id_num], dequeued2['id_num'])

    assert_empty_queue
  end

  def test_queue_unique_doc_twice
    person1 = get_person
    person2 = get_person
    
    person1[:id_num] = 123
    person2[:id_num] = person1[:id_num]
    
    assert_not_nil @queue.enqueue(person1, :test_queue, {unique_field: :id_num})
    assert_nil @queue.enqueue(person2, :test_queue, {unique_field: :id_num})

    dequeued = @queue.dequeue(:test_queue)
    assert_equal(person1[:name], dequeued['name'])
    assert_equal(person1[:age], dequeued['age'])
    assert_equal(person1[:id_num], dequeued['id_num'])

    assert_empty_queue(:test_queue)
  end
  
  def test_add_queue
    assert_not_nil @queue.enqueue(get_person, :test_queue, {unique_field: :id_num})
    assert_not_nil @queue.enqueue(get_person, [:test_queue, :test_queue2], {unique_field: :id_num})

    person = get_person

    dequeued = @queue.dequeue(:test_queue)
    assert_equal(person[:name], dequeued['name'])
    assert_equal(person[:age], dequeued['age'])
    assert_equal(person[:id_num], dequeued['id_num'])

    dequeued = @queue.dequeue(:test_queue2)
    assert_equal(person[:name], dequeued['name'])
    assert_equal(person[:age], dequeued['age'])
    assert_equal(person[:id_num], dequeued['id_num'])

    assert_empty_queue(:test_queue)
    assert_empty_queue(:test_queue2)
  end

  def test_no_queue
    assert_nil @queue.enqueue(get_person, [nil, ''])
  end

  def test_remove_all_with_status_same
    # q1 & q2 => success
    @queue.enqueue(get_person, [:queue1, :queue2])
    @queue.dequeue(:queue1, {status: :success}) 
    @queue.dequeue(:queue2, {status: :success})
    assert_equal(1, @queue.remove_all(:success))
    assert_equal(0, @queue.remove_all(:success))
  end

  def test_remove_all_with_status_multiple
    # q1 => success, q2 => error
    @queue.enqueue(get_person, [:queue1, :queue2])
    @queue.dequeue(:queue1, {status: :success})
    @queue.dequeue(:queue2, {status: :error})
    assert_equal(1, @queue.remove_all([:success, :error]))
    assert_equal(0, @queue.remove_all([:success, :error]))
  end

  def test_remove_all_with_status_single
    # q1 => success, q2 => error
    @queue.enqueue(get_person, [:queue1])
    @queue.dequeue(:queue1, {status: :success})
    assert_equal(1, @queue.remove_all([:success, :error]))
    assert_equal(0, @queue.remove_all([:success, :error]))
  end

  def test_remove_all_not_qualified
    # q1 => success, q2 => processing
    @queue.enqueue(get_person, [:queue1, :queue2])
    @queue.dequeue(:queue1, {status: :success})
    @queue.dequeue(:queue2, {status: :processing})
    assert_equal(0, @queue.remove_all([:success, :error]))
  end
  
  def test_requeue_timed_out
    @queue.enqueue(get_person)
    @queue.dequeue
    sleep 0.1
    assert_nil @queue.dequeue
    assert_equal(1, @queue.requeue_timed_out(0.1, MongoDBQueue::DEFAULT_DEQUEUE_STATUS))
    assert_not_nil @queue.dequeue
  end
  
  def test_requeue_timed_out_young
    @queue.enqueue(get_person)
    @queue.dequeue
    assert_nil @queue.dequeue
    assert_equal(0, @queue.requeue_timed_out(5, MongoDBQueue::DEFAULT_DEQUEUE_STATUS))
    assert_nil @queue.dequeue
  end
  
  def test_requeue_timed_out_multiple
    @queue.enqueue(get_person, [:queue1, :queue2, :queue3])
    @queue.dequeue(:queue1, {status: :success})
    @queue.dequeue(:queue2, {status: :error})
    @queue.dequeue(:queue3, {status: :processing})
    sleep 0.1
    assert_nil @queue.dequeue(:queue1)
    assert_nil @queue.dequeue(:queue2)
    assert_nil @queue.dequeue(:queue3)
    assert_equal(2, @queue.requeue_timed_out(0.1, [:error, :processing]))
    assert_nil @queue.dequeue(:queue1)
    assert_not_nil @queue.dequeue(:queue2)
    assert_not_nil @queue.dequeue(:queue3)
  end
  
  def test_unset_all
    @queue.enqueue(get_person, [:queue1, :queue2])
    @queue.dequeue(:queue1, {status: :success})
    @queue.dequeue(:queue2, {status: :error})
    assert_not_nil @inspect_queue.find().next_document['name']
    assert_equal(1, @queue.unset_all([:success, :error], :name))
    assert_nil @inspect_queue.find().next_document['name']
  end

  def test_unset_all_not_qualified
    @queue.enqueue(get_person, [:queue1, :queue2])
    @queue.dequeue(:queue1, {status: :success})
    @queue.dequeue(:queue2, {status: :error})
    assert_not_nil @inspect_queue.find().next_document['name']
    assert_equal(0, @queue.unset_all([:success], :name))
    assert_not_nil @inspect_queue.find().next_document['name']
  end
end