require_relative 'money_transfer_script'
response1 = nil
response2 = nil
thread1 = Thread.new do
  response1 = add_money(3, 200)
end

thread2 = Thread.new do
  response2 = add_money(3, 300)
end

[thread1, thread2].map(&:join)
