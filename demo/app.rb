# frozen_string_literal: true

require 'haml'
require 'sinatra'
require 'sinatra/param'

require_relative '../../lib/dependencies'

get '/compile' do
  param :input, String, required: true

  parsed_clauses = POECSS::Parsing.parse_input(params[:input])
  result = POECSS::Generator.generate_poe_rules(parsed_clauses)

  content_type 'text/plain'
  body result
end

get '/' do
  haml :index
end
