# frozen_string_literal: true

require 'net/http'
require 'uri'

def add_money(account_id, money_amount)
  uri = URI.parse("http://localhost:3000/accounts/#{account_id}/add_money")
  request = Net::HTTP::Put.new(uri)
  request['Accept'] = 'application/json'
  request.set_form_data(
    'money_to_add' => money_amount
  )

  req_options = {
    use_ssl: uri.scheme == 'https'
  }

  Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
end

def withdraw_money(account_id, money_amount)
  uri = URI.parse("http://localhost:3000/accounts/#{account_id}/withdraw_money")
  request = Net::HTTP::Put.new(uri)
  request['Accept'] = 'application/json'
  request.set_form_data(
    'money_to_withdraw' => money_amount
  )

  req_options = {
    use_ssl: uri.scheme == 'https'
  }

  Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
end
