# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
begin
  require "minitest/mock"
rescue LoadError
  # Minitest 6 removed minitest/mock. Keep Object#stub for gem tests.
  module MinitestStubCompat
    def stub(name, val_or_callable, *block_args)
      name = name.to_sym
      metaclass = singleton_class
      original = if metaclass.method_defined?(name, false) ||
                    metaclass.private_method_defined?(name, false) ||
                    metaclass.protected_method_defined?(name, false)
        metaclass.instance_method(name)
      end

      metaclass.define_method(name) do |*args, **kwargs, &block|
        if val_or_callable.respond_to?(:call)
          if kwargs.empty?
            val_or_callable.call(*args, &block)
          else
            val_or_callable.call(*args, **kwargs, &block)
          end
        else
          val_or_callable
        end
      end

      yield(*block_args)
    ensure
      if original
        metaclass.define_method(name, original)
      elsif metaclass.method_defined?(name, false) || metaclass.private_method_defined?(name, false)
        metaclass.remove_method(name)
      end
    end
  end

  Object.prepend(MinitestStubCompat) unless Object.method_defined?(:stub)
end
require "rails"
require "active_support/time"
Time.zone ||= "UTC"
require "recording_studio_terms_and_conditions"
