# frozen_string_literal: true

# Manages abstract class for all the models
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  paginates_per 15
end
