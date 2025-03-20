require 'net/http'
require 'uri'

def create_user(name, email)
  uri = URI('http://localhost:3000/users')
  Net::HTTP.post_form(uri, 'user[email]' => email, 'user[name]' => name)
end
