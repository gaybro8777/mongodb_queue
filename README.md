mongodb_queue
=============

[![Build Status](https://api.shippable.com/projects/5498868ed46935d5fbc0d547/badge?branchName=master)](https://app.shippable.com/projects/5498868ed46935d5fbc0d547/builds/latest) [![Code Climate](https://codeclimate.com/github/dashingrocket/mongodb_queue/badges/gpa.svg)](https://codeclimate.com/github/dashingrocket/mongodb_queue) [![Test Coverage](https://codeclimate.com/github/dashingrocket/mongodb_queue/badges/coverage.svg)](https://codeclimate.com/github/dashingrocket/mongodb_queue)

**This project is under development.**

MongoDB based work queue written in Ruby.  Supports multiple queues.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mongodb_queue'
```

And then execute:

$ bundle

Or install it yourself as:

$ gem install mongodb_queue

## Usage

```ruby
require 'mongodb_queue'

queue = MongoDBQueue::MongoDBQueue.new({address: 'localhost', port: 27017, database: 'test-db', collection: 'test-queue'})
person = {name: 'John', age: 32, id: '123456789'}
person2 = {name: 'James', age: 24, id: '123456789'}

# Basic Usage
queue.simple_enqueue(person)
queued_person = queue.simple_dequeue

# Multiple Queues
queue.enqueue([:faculty, :staff], person)
faculty_member = queue.dequeue(:faculty)
staff_member = queue.dequeue(:staff)

# Prevent Duplicate Items
@queue.enqueue(:faculty, person, {unique_field: :id_num})
@queue.enqueue(:faculty, person2, {unique_field: :id_num})  # This wont be queued
faculty_member = queue.dequeue(:faculty)

# Delete item when dequeued
#   Be careful with this if using multiple queues as it deletes the document from all queues.
queue.enqueue(:faculty, person)
faculty_member = queue.dequeue(:faculty, {delete: true)

# Use a different dequeued state
queue.enqueue(:faculty, person)
faculty_member = queue.dequeue(:faculty, {status: :processing)
```

## Sample MongoDB Document

This is a document that has been added to 2 queues - test_queue and test_queue2.  It has already been dequeued from test_queue

``` json
{
    "_id" : ObjectId("549b1678b83b50d6bf000001"),
    "name" : "John",
    "age" : 32,
    "id_num" : "123456789",
    "queue" : [
        {
            "name" : "test_queue",
            "status" : "dequeue",
            "queue_timestamp" : ISODate("2014-12-24T19:39:36.051Z"),
            "dequeue_timestamp" : ISODate("2014-12-24T19:39:36.053Z")
        },
        {
            "name" : "test_queue2",
            "status" : "queue",
            "queue_timestamp" : ISODate("2014-12-24T19:39:55.052Z"),
        }
    ]
}
```

## Contributing

1. Fork it ( https://github.com/dashingrocket/mongodb_queue/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
