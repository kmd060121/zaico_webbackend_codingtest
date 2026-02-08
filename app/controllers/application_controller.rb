class ApplicationController < ActionController::Base
  # Disable browser check for now to avoid issues
  # allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
