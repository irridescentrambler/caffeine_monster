require_relative 'money_transfer_script'
response1 = nil
response2 = nil
thread1 = Thread.new do
  response1 = withdraw_money(1, 1500)
end

thread2 = Thread.new do
  response2 = withdraw_money(1, 1500)
end

[thread1, thread2].map(&:join)