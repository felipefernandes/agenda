$:.unshift File.dirname(__FILE__) + "/../../lib"

require File.dirname(__FILE__) + "/../utils"
require 'test/unit'
require 'switchtower/scm/subversion'

class ScmSubversionTest < Test::Unit::TestCase
  class SubversionTest < SwitchTower::SCM::Subversion
    attr_accessor :story
    attr_reader   :last_path

    def svn_log(path)
      @last_path = path
      story.shift
    end
  end

  class MockChannel
    attr_reader :sent_data

    def send_data(data)
      @sent_data ||= []
      @sent_data << data
    end

    def [](name)
      "value"
    end
  end

  class MockActor
    attr_reader :command
    attr_reader :channels
    attr_accessor :story

    def initialize(config)
      @config = config
    end

    def run(command)
      @command = command
      @channels ||= []
      @channels << MockChannel.new
      story.each { |stream, line| yield @channels.last, stream, line }
    end

    def method_missing(sym, *args)
      @config.send(sym, *args)
    end
  end

  def setup
    @config = MockConfiguration.new
    @config[:current_path] = "/mwa/ha/ha/current"
    @config[:repository] = "/hello/world"
    @config[:svn] = "/path/to/svn"
    @config[:password] = "chocolatebrownies"
    @scm = SubversionTest.new(@config)
    @actor = MockActor.new(@config)
    @log_msg = <<MSG.strip
------------------------------------------------------------------------
r1967 | minam | 2005-08-03 06:59:03 -0600 (Wed, 03 Aug 2005) | 2 lines

Initial commit of the new switchtower utility

------------------------------------------------------------------------
MSG
    @scm.story = [ @log_msg ]
  end

  def test_latest_revision
    @scm.story = [ @log_msg ]
    assert_equal "1967", @scm.latest_revision
    assert_equal "/hello/world", @scm.last_path
  end

  def test_latest_revision_searching_upwards
    @scm.story = [ "-----------------------------\n", @log_msg ]
    assert_equal "1967", @scm.latest_revision
    assert_equal "/hello", @scm.last_path
  end

  def test_checkout
    @actor.story = []
    assert_nothing_raised { @scm.checkout(@actor) }
    assert_nil @actor.channels.last.sent_data
    assert_match %r{/path/to/svn co\s+-q}, @actor.command
  end

  def test_checkout_via_export
    @actor.story = []
    @config[:checkout] = "export"
    assert_nothing_raised { @scm.checkout(@actor) }
    assert_nil @actor.channels.last.sent_data
    assert_match %r{/path/to/svn export\s+-q}, @actor.command
  end

  def test_update
    @actor.story = []
    assert_nothing_raised { @scm.update(@actor) }
    assert_nil @actor.channels.last.sent_data
    assert_match %r{/path/to/svn up}, @actor.command
  end

  def test_checkout_needs_ssh_password
    @actor.story = [[:out, "Password: "]]
    assert_nothing_raised { @scm.checkout(@actor) }
    assert_equal ["chocolatebrownies\n"], @actor.channels.last.sent_data
  end

  def test_checkout_needs_http_password
    @actor.story = [[:out, "Password for (something): "]]
    assert_nothing_raised { @scm.checkout(@actor) }
    assert_equal ["chocolatebrownies\n"], @actor.channels.last.sent_data
  end

  def test_checkout_needs_alternative_ssh_password
    @actor.story = [[:out, "someone's password: "]]
    assert_nothing_raised { @scm.checkout(@actor) }
    assert_equal ["chocolatebrownies\n"], @actor.channels.last.sent_data
  end

  def test_svn_password
    @config[:svn_password] = "butterscotchcandies"
    @actor.story = [[:out, "Password: "]]
    assert_nothing_raised { @scm.checkout(@actor) }
    assert_equal ["butterscotchcandies\n"], @actor.channels.last.sent_data
  end

  def test_svn_username
    @actor.story = []
    @config[:svn_username] = "turtledove"
    assert_nothing_raised { @scm.checkout(@actor) }
    assert_nil @actor.channels.last.sent_data
    assert_match %r{/path/to/svn co --username turtledove}, @actor.command
  end
end
