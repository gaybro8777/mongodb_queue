mongodb_queue
=============

------------- | -------------
Build Status  | [![Build Status](https://travis-ci.org/dashingrocket/mongodb_queue.svg?branch=master)](https://travis-ci.org/dashingrocket/mongodb_queue)
Code Climate  | [![Code Climate](https://codeclimate.com/github/dashingrocket/mongodb_queue/badges/gpa.svg)](https://codeclimate.com/github/dashingrocket/mongodb_queue)
Test Coverage | [![Test Coverage](https://codeclimate.com/github/dashingrocket/mongodb_queue/badges/coverage.svg)](https://codeclimate.com/github/dashingrocket/mongodb_queue)
Gem Version   | TBD


** This project is unfinished **

MongoDB based work queue written in Ruby.  Support multiple queues.

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

TODO: Write usage instructions here

```ruby
require 'mongodb_queue'

queue = MongoDBQueue::MongoDBQueue.new({address: 'localhost', port: 27017, database: 'test-db', collection: 'test-queue'})

person = {name: 'John', age: 32, ssn: '123456789'}

# Basic Usage
queue.enqueue([:faculty, :staff], person)
queue.dequeue(:faculty)
```

## Contributing

1. Fork it ( https://github.com/dashingrocket/mongodb_queue/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
