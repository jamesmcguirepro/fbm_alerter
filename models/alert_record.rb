# frozen_string_literal: true

# == Schema Information
#
# Table name: alert_records
#
#  id         :integer          not null, primary key
#  date       :date             not null
#  type       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_alert_records_on_date_and_type  (date, type) UNIQUE
#
class AlertRecord < ActiveRecord::Base
  self.inheritance_column = nil

  LOW_CREDIT = 'low_credit'

  class << self
    # Whether an alert of the given type was recorded today.
    def alerted_today?(type:)
      exists?(date: Date.current, type:)
    end

    # Convenience alias that hard-codes the type.
    def low_credit_alerted_today?
      alerted_today?(type: LOW_CREDIT)
    end

    # Record that an alert of the given type was sent today.
    def set_alerted(type:)
      create!(date: Date.current, type:)
    rescue ActiveRecord::RecordNotUnique
      # Already recorded today — harmless.
    end

    alias_method :set_low_credit_alerted, :set_alerted
  end
end
