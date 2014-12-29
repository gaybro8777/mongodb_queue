mongodb_queue
=============

[![Build Status](https://api.shippable.com/projects/5498868ed46935d5fbc0d547/badge?branchName=master)](https://app.shippable.com/projects/5498868ed46935d5fbc0d547/builds/latest) [![Gem Version](https://badge.fury.io/rb/mongodb_queue.svg)](http://badge.fury.io/rb/mongodb_queue) [![Downloads](http://ruby-gem-downloads-badge.herokuapp.com/mongodb_queue?type=total)](https://rubygems.org/gems/mongodb_queue)


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
person2 = {name: 'Jane', age: 29, id: '123456789'}

# Basic Usage
queue.enqueue(person)
queued_person = queue.dequeue

# Custom Queue Names
queue.enqueue(person, :friends)
friend = queue.dequeue(:friends)

# Multiple Queues
queue.enqueue(person, [:faculty, :staff])
faculty_member = queue.dequeue(:faculty)
staff_member = queue.dequeue(:staff)

# Prevent Duplicate Items
@queue.enqueue(person, :faculty, {unique_field: :id_num})
@queue.enqueue(person2, :faculty, {unique_field: :id_num})  # This wont be queued
faculty_member = queue.dequeue(:faculty)

# Delete item when dequeued
#   Be careful with this if using multiple queues as it deletes the document from all queues.
queue.enqueue(person, :faculty)
faculty_member = queue.dequeue(:faculty, {delete: true})

# Use a different dequeued status
queue.enqueue(person)
faculty_member = queue.dequeue(MongoDBQueue::DEFAULT_QUEUE, {status: :processing})

# Remove documents that have finished some processing
queue.remove_all([:success, :error])

# Requeue documents that have been in a dequeued status for 5 minutes (300 seconds)
queue.requeue_timed_out(300)

# Requeue documents that have been in a processing status for 5 minutes (300 seconds)
queue.requeue_timed_out(300, :processing)

# Unset the name field for successfully processed documents
queue.unset_all([:success], :name)

# Disconnect from MongoDB when done
queue.destroy
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
            "queue_timestamp" : ISODate("2014-12-24T19:39:55.052Z")
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

## License
Copyright 2014 Dashing Rocket, Ltd.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
