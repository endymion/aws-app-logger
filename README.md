# Aws::App::Logger

This Ruby gem will emit log messages the way you normally do from Ruby,
but leverage the power of AWS CloudWatch, with metrics, alerts, Log Insights,
visualization, and more.

## Familiar logginer interface

You might have a lot of Ruby code that's already full of log statements that
use the standard Logger class, like this:

    $logger.info  "Starting to process order: #{@order.id}"
    $logger.debug "Order: #{@order.inspect}"
    ...
    $logger.info  "Order final: #{@order.id}"

If you're using AWS Lambda to run your code, then you'll be able to see your
logs and search then in AWS CloudWatch:

    2022-10-12T16:20:45.891-05:00	DEBUG: Starting to process order: 1234
    2022-10-12T16:20:45.891-05:00	DEBUG: Order: {:id=>"1234", :total=>"4592", :subtotal=>"..." ... }
    2022-10-12T16:20:47.369-05:00	DEBUG: Order final: {:id=>"1234", :total=>"4592", :subtotal=>"..." ... }

## Stuctured data logging

But, you could get more out of CloudWatch.  You could log your `@order` object
as machine-readable data that you could
[query](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
with [CloudWatch Log Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html).

When you have an operational problem and a message goes into a dead-letter queue,
your operators will need a quick way to query your logs for other messages
related to the message.  In this example, where the messages relate to an
application that 'processes orders' of some kind, you might want to quickly
find the log entries related to that order so that you can trace its lifecycle
and decide how to handle the message.

With this gem, you can log your existing messages just like you did before.
But instead of passing just a message when you emit a log statement, you can
provide structured data.

So, this:

    $logger.info "Starting to process order: #{@order.id}"

...becomes:

    $logger.info 'Starting to process order.', @order.id

And instead of this in your CloudWatch logs:

    2022-10-12T16:20:45.891-05:00 	DEBUG: Starting to process order: 1234

...you get this:

    DEBUG: Starting to process order.
      {"message":"Starting to process order.", "id":"1234","total":"4592","subtotal":"..."}
      Hash
      {
              :id => "10102001",
           :total => "1295",
        :subtotal => "..."
      }

CloudWatch already provides a timestamp, so you don't need that.  The second,
indented line of your log output is machine-readable JSON data, and after
that is a human-readable, pretty-printed version for you to read.  CloudWatch will parse the JSON representation and index the things that it finds in it, and you can read the other part.

## Query your logs

Now, you can use AWS Log Insights to find log entries related to
concepts in your application.  If you have an application with an "order" model that you care about, then you can query for log messages
related to any given order `id`.  You can do queries based on attributes
of your orders, like the total, subtotal, any special taxes that your
application handles, etc.  You can search for log lines from orders as
they closed where the total was above $X, for example.  Or where some
tax line item was zero, when maybe it never should be.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add aws-app-logger

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install aws-app-logger

## Usage

If you have existing log statements in your code that assume that there is a
global `$logger` for you to use for logging, then you can override the default
logger with:

    require 'aws-app-logger'
    $logger = Aws::App::Logger.new

### Log stuff just like before

Now use that just like the standard Logger:

    $logger.info 'Someting is happening!'

### Log objects

Log the `@session` object as JSON so that you can query for its values in the future:

    $logger.debug 'The current session:', @session

### Log additional context

Log additional context with your `@session` object, to help you understand what was happening:

    $logger.debug 'A condition was triggered!,
      { action:'trigger', condition:'red' },
      @session

When you provide more than one object, you will get a JSON array in the log with all the objects in it.

### Log directly to CloudWatch

If you don't want to emit your log output to standard output, if you instead
want to log directly to CloudWatch through the CloudWatch API, then you can
provide a string when you create the `Logger` instance, and it will use that
as the name of a log group in CloudWatch:

    require 'aws-app-logger'
    $logger = Aws::App::Logger.new 'my-log-group'
    $logger.info 'A message in a log stream in the log group my-log-group.'
    $logger.debug "Some important object that responsd to to_json:", @record

### Pretty printing

You can also log an optional pretty-printed representation that displays the
class name, and it uses Awesome Print to render the object so that you can see
array indexes and useful things like that.

You can enable pretty printing with the `nopretty:true` option when you set up
your logging:

    require 'aws-app-logger'
    $logger = Aws::App::Logger.new pretty:true
    $logger.info 'Starting to process order.', @order.id

Produces:

    DEBUG: Starting to process order.
      {"message":"Starting to process order.", "id":"1234","total":"4592","subtotal":"..."}
      Hash
      {
              :id => "10102001",
           :total => "1295",
        :subtotal => "..."
      }

CloudWatch is good at parsing the JSON and displaying it for you, so you might
never need this.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test-unit` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/aws-app-logger.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
