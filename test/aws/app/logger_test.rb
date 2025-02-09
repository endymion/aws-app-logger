# frozen_string_literal: true

require 'stringio'
require 'test_helper'
require 'rainbow'
require 'json'
require 'aws-sdk-cloudwatchlogs'
require 'vcr'

ENV['AWS_REGION'] = 'us-east-1'
VCR.configure do |config|
  config.cassette_library_dir = "#{__dir__}/../../vcr_cassettes"
  config.hook_into :webmock
end

class Aws::App::LoggerTest < Test::Unit::TestCase
  puts 'Test log message: ' + @@test_message =
      '¡Sierra! 🌟 🐭 🌱 🦄 SUCCESS'

  test 'VERSION' do
    assert do
      Aws::App::Logger.const_defined?(:VERSION)
    end
  end

  # Existing functionality from Logger, passed through.
  test 'output includes message' do
    $logger = Aws::App::Logger.new(output = StringIO.new)
    $logger.debug @@test_message
    assert output.string.include? @@test_message
  end

  test 'output includes severity' do
    $logger = Aws::App::Logger.new(output = StringIO.new)
    $logger.debug @@test_message
    assert output.string =~ /debug/i
  end

  test 'output includes appropriate severity log lines' do
    $logger = Aws::App::Logger.new(output = StringIO.new)
    $logger.level = :info
    $logger.info @@test_message
    $logger.debug @@test_message
    assert output.string =~ /info/i and output.string !~ /debug/i
  end

  test 'existing formatter interface still works' do
    $logger = Aws::App::Logger.new(output = StringIO.new)
    $logger.formatter = proc {|severity, time, p, msg| "TEST#{severity}: #{msg}\n" }
    $logger.debug @@test_message
    assert output.string =~ /TESTDEBUG/i
  end

  # New functionality for AWS CloudWatch

  test 'logging an object as JSON with debug' do
    $logger = Aws::App::Logger.new(output = StringIO.new)
    $logger.debug @@test_message, {id:'10102001', total:'1295', subtotal:'...'}
    assert(
      output.string.include?(@@test_message) &&
      JSON.parse(output.string.split("\n")[1])['id'].eql?('10102001')
    )
  end

  test 'logging more than one object as JSON with debug' do
    $logger = Aws::App::Logger.new(output = StringIO.new)
    $logger.debug @@test_message,
      {action:'sale'},
      {id:'10102001', total:'1295', subtotal:'...'}
    assert(
      output.string.include?(@@test_message) &&
      JSON.parse(output.string.split("\n")[1])[0]['action'].eql?('sale') &&
      JSON.parse(output.string.split("\n")[1])[1]['id'].eql?('10102001')
    )
  end

  test 'logging all objects with no string' do
    $logger = Aws::App::Logger.new(output = StringIO.new)
    $logger.debug(
      {action:'sale'},
      {id:'10102001', total:'1295', subtotal:'...'}
    )
    assert(
      (data = JSON.parse(output.string.split(/^[\S]+\s/)[1])).first['action'].
        eql?('sale') &&
      data.last['id'].eql?('10102001')
    )
  end

  test 'pretty-printed object representation not included by default' do
    $logger = Aws::App::Logger.new(output = StringIO.new)
    $logger.debug @@test_message, {id:'10102001', total:'1295', subtotal:'...'}
    assert(
      output.string.include?(@@test_message) &&
      ! Rainbow.uncolor(output.string).include?(':id => "10102001"')
    )
  end

  test 'the pretty option enables the pretty-printed version' do
    $logger = Aws::App::Logger.new(output = StringIO.new,
      pretty:true)
    $logger.debug @@test_message, {id:'10102001', total:'1295', subtotal:'...'}
    assert(
      output.string.include?(@@test_message) &&
      output.string.include?(':id => "10102001"')
    )
  end

  # AWS CloudWatch provides the timestamp and that's better anyway.
  test 'the default formatter does not include the timestamp' do
    $logger = Aws::App::Logger.new(output = StringIO.new)
    $logger.debug @@test_message
    assert(
      !( output.string =~ /\d\d\d\d\-\d\d\-\d\d/ )
    )
  end

  # These tests use Cloudwatch.

  test 'log to CloudWatch using the name of a log group' do
    VCR.use_cassette(__method__, :match_requests_on => [:method]) do
      assert Aws::App::Logger.
        new('aws-app-logger-test').
        debug(@@test_message, {id:'10102001', total:'1295', subtotal:'...'})
    end
  end

  test 'logging more than once requires managing the sequence token' do
    VCR.use_cassette(__method__, :match_requests_on => [:method]) do
      logger = Aws::App::Logger.new('aws-app-logger-test')
      assert logger.debug("1") && logger.debug("2")
    end
  end

  # Implicit log group creation.
  test 'creates log group when one does not exist' do
    VCR.use_cassette(__method__, :match_requests_on => [:method]) do
      log_group_name_that_does_not_exist =
        'aws-app-logger-test-' +
        (0...8).map { (65 + rand(26)).chr }.join
      Aws::App::Logger.new log_group_name_that_does_not_exist
      remove_log_group log_group_name_that_does_not_exist
    end
  end

  test 'finds a log group when one does exist' do
    VCR.use_cassette(__method__, :match_requests_on => [:method]) do
      log_group_name_that_does_not_exist =
        'aws-app-logger-test-' +
        (0...8).map { (65 + rand(26)).chr }.join
      Aws::App::Logger.new log_group_name_that_does_not_exist
      Aws::App::Logger.new log_group_name_that_does_not_exist
      remove_log_group log_group_name_that_does_not_exist
    end
  end

  # WIP: Tests that use CloudWatch Log Insights.
  # This is complicated because CloudWatch doesn't parse the JSON from
  # log entries made directly to CloudWatch.  Lambda parses the JSON from
  # log entries that you send through Lambda, but you have to add your own
  # tags to the log entries yourself if you send the log entry directly.
  # test 'finds log entries using structured data' do
  #   VCR.use_cassette(__method__, :match_requests_on => [:method]) do
  #     logger = Aws::App::Logger.new('aws-app-logger-test')
  #     100.times do |i|
  #       total = rand(10000)
  #       logger.debug('order-completed',
  #         {'action':'order-completed'},
  #         {id:'10102001', total:total, subtotal:'...'})
  #     end
  #   end
  # end

  private

  def remove_log_group(name)
    cloudwatch = Aws::CloudWatchLogs::Client.new
    cloudwatch.delete_log_group(
      log_group_name: name
    )
  end

end
