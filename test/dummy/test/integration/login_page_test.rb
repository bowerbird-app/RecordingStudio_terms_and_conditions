# frozen_string_literal: true

require "test_helper"

class LoginPageTest < ActionDispatch::IntegrationTest
  test "sign in uses Users Auth email-first, not the old Devise card" do
    get new_user_session_path

    assert_response :success
    assert_select "html[data-theme='rounded']"
    assert_select "h2", text: "Welcome back"
    assert_select "input[type='email'][name='user[email]'][placeholder='you@company.com']"
    assert_select "label", text: "Email", count: 0
    assert_select "input[type='password'][name='user[password]']", count: 0
    assert_select "input[name='user[remember_me]']", count: 0
    assert_select "button[type='submit']", text: "Continue with email"
    refute_includes response.body, "Remember me"
    refute_includes response.body, "Default: admin@admin.com / Password"
    refute_includes response.body, "data-recording-studio-default-layout"
    refute_includes response.body, "fixed inset-0"
    refute File.exist?(Rails.root.join("app/views/devise/sessions/new.html.erb"))
    assert_includes response.body, "@hotwired/turbo-rails"
    assert_match %r{/assets/turbo\.min[^"]+\.js}, response.body
  end

  test "continue with email opens the password screen" do
    post new_user_session_path, params: { user: { email: "admin@admin.com" } }

    assert_redirected_to "#{new_user_session_path}/password"
    follow_redirect!

    assert_response :success
    assert_select "input[type='password'][name='user[password]']"
    assert_select "input[type='hidden'][name='user[email]'][value='admin@admin.com']"
    assert_select "button[type='submit']", text: "Sign in"
    assert_select "a[href='#{new_user_password_path}']", text: "Forgot your password?"
  end
end
