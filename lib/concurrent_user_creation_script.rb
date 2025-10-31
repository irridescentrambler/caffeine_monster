# frozen_string_literal: true

require_relative 'user_creation_script'

response1 = nil
response2 = nil
thread1 = Thread.new do
  response1 = create_user('Ruby User', 'ruby_user@meetup.com')
end

thread2 = Thread.new do
  response2 = create_user('Ruby User', 'ruby_user@meetup.com')
end

[thread1, thread2].each(&:join)
