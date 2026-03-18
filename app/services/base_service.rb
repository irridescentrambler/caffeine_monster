# frozen_string_literal: true

# Base class for service objects; provides Response and a class-level .call that invokes #call.
class BaseService
  Response = Struct.new(:data, :error) do
    def success?
      error.nil?
    end
  end

  def self.call(...)
    new(...).call
  end
end
