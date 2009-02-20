class Module
  def const_during(constant, value)
    if const_defined?(constant)
      overridden = true
      saved = const_get(constant)
      remove_const(constant)
    end

    const_set(constant, value)
    yield
  ensure
    if overridden
      remove_const(constant)
      const_set(constant, saved)
    end
  end
end

class MockLogger
  def info(msg,pfx=nil) end
  def debug(msg,pfx=nil) end
end

class MockConfiguration < Hash
  def initialize(*args)
    super
    self[:release_path] = "/path/to/releases/version"
    self[:ssh_options] = {}
  end

  def logger
    @logger ||= MockLogger.new
  end

  def set(variable, value=nil, &block)
      self[variable] = value
  end

  def respond_to?(sym)
    self.has_key?(sym)
  end

  def method_missing(sym, *args)
    if args.length == 0
      self[sym]
    else
      super
    end
  end
end
