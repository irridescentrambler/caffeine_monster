require 'net/http'
require 'uri'

uri = URI.parse('http://localhost:3000/accounts/2/add_money')
request = Net::HTTP::Put.new(uri)
request['Accept'] = 'application/json'
request.set_form_data(
  'money_to_add' => '300'
)

req_options = {
  use_ssl: uri.scheme == 'https'
}

response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
  http.request(request)
end
