# frozen_string_literal: true

# This is an abstract class for all the controllers in the App.
class ApplicationController < ActionController::Base
  after_action :track_active_record_objects_for_overfetching, if: -> { Rails.env.local? }

  private

  # Tracks ActiveRecord objects for overfetching and logs relevant details
  def track_active_record_objects_for_overfetching
    tracked_instances = Thread.current[:_tracked_instances]
    return unless tracked_instances

    tracked_instances.each do |model_name, instances|
      log_model_fetching_details(model_name, instances)
      log_unused_fields(instances)
    end

    clear_tracked_instances
  end

  # Logs the count of loaded objects for a specific model
  def log_model_fetching_details(model_name, instances)
    Rails.logger.tagged("Tracking overfetching for #{model_name}") do
      Rails.logger.debug("Loaded #{instances.uniq.count} #{model_name} objects")
    end
  end

  # Logs unused and accessed fields for the tracked objects
  def log_unused_fields(instances)
    object_to_track = extract_object_to_track(instances)
    return unless object_to_track&.respond_to?(:unused_attributes) && object_to_track.unused_attributes.present?

    Rails.logger.tagged("Overfetching detected for model #{object_to_track.class.name}") do
      Rails.logger.debug("Unused attributes: #{object_to_track.unused_attributes}")
      Rails.logger.debug("Accessed fields: #{object_to_track.accessed_fields}")
    end
  end

  # Extracts the object to track from the given instances
  def extract_object_to_track(instances)
    case instances
    when Array, ActiveRecord::Relation
      instances.first
    else
      instances
    end
  end

  # Clears the tracked instances from the current thread
  def clear_tracked_instances
    Thread.current[:_tracked_instances] = nil
  end
end
