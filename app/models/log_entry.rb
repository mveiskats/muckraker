class LogEntry < ApplicationRecord
  default_scope { order(:logged_at) }
  scope :logged_after, ->(date) { where('DATE(logged_at) >= ?', date) }
  scope :logged_before, ->(date) { where('DATE(logged_at) <= ?', date) }

  def self.condensed_log
    result = StringIO.new
    all.each do |le|
      result << "#{le.logged_at.iso8601} - user id: #{le.user_id.to_s.rjust(5)}"
      result << " - HTTP #{le.status_code}"
      result << " - #{le.method.ljust(5)} #{le.uri}"
      result << "\n"
    end

    result.string
  end

  def self.full_log
    result = StringIO.new
    all.each do |le|
      result << le.content
    end

    result.string
  end
end
