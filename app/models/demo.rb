# frozen_string_literal: true

thread1 = Thread.new do
  category1 = Category.new(
    name: 'Water',
    active: true
  )
  category1.save
end

thread2 = Thread.new do
  category2 = Category.new(
    name: 'Water',
    active: true
  )
  category2.save
end

[thread1, thread2].each(&:join)
