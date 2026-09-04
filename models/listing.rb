class Listing < ActiveRecord::Base
  validates :title, presence: true

  has_many :alerts

  scope :unnotified_and_unsold, -> {
    left_outer_joins(:alerts_sent)
      .where(alerts_sent: { id: nil }, is_sold: false)
      .order(first_seen_at: :desc)
  }
end
