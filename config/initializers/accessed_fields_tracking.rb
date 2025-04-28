# frozen_string_literal: true

# This initializer tracks accessed fields and unused attributes for ActiveRecord objects.
ActiveSupport.on_load(:active_record) do
  after_initialize :save_objects_for_tracking, if: -> { Rails.env.local? }

  # Enables tracking for overfetching unused attributes
  def self.track_for_overfetching
    define_singleton_method(:enable_for_tracking) { true }
  end

  private

  # Saves the current object for tracking if tracking is enabled
  def save_objects_for_tracking
    return unless tracking_enabled?

    initialize_tracking_data
    track_current_object
  end

  # Returns a list of unused attributes by subtracting accessed fields from all attributes
  def unused_attributes
    attribute_names - accessed_fields
  end

  # Checks if tracking is enabled for the current class
  def tracking_enabled?
    self.class.try(:enable_for_tracking)
  end

  # Initializes the tracking data structure in the current thread
  def initialize_tracking_data
    Thread.current[:_tracked_instances] ||= {}
    Thread.current[:_tracked_instances][self.class.name] ||= []
  end

  # Adds the current object to the tracking data, with a limit to optimize memory usage
  def track_current_object
    tracked_instances = Thread.current[:_tracked_instances][self.class.name]
    return if tracked_instances.count >= 15

    tracked_instances << self
  end
end
