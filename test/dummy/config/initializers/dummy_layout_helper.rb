# frozen_string_literal: true

Rails.application.config.to_prepare do
  next unless defined?(ActionView::Base)
  next if ActionView::Base < DummyLayoutHelper

  ActionView::Base.class_eval { include DummyLayoutHelper }
end
