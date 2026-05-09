module ApplicationHelper
  STATUS_BADGE = {
    "pending"   => "bg-gray-100 text-gray-600",
    "ingesting" => "bg-yellow-100 text-yellow-700",
    "ready"     => "bg-green-100 text-green-700",
    "failed"    => "bg-red-100 text-red-700"
  }.freeze

  def status_badge_classes(status)
    STATUS_BADGE.fetch(status.to_s, "bg-gray-100 text-gray-600")
  end
end
