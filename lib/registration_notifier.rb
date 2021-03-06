# frozen_string_literal: true

class RegistrationNotifier
  include Singleton

  def cancel
    Event.not_started.each do |event|
      AttendanceRepository.instance.for_cancelation(event).each do |attendance|
        Rails.logger.info("[Attendance] #{attendance.to_param}")
        try_with('CANCEL') do
          attendance.cancelled!
          EmailNotifications.cancelling_registration(attendance).deliver
        end
      end
    end
  end

  def cancel_warning
    Rails.logger.info("Perform cancellation warning to #{Event.active_for(Time.zone.now).count} events")
    Event.active_for(Time.zone.now).each do |event|
      attendances_to_advise = AttendanceRepository.instance.for_cancelation_warning(event)
      Rails.logger.info("Warning #{attendances_to_advise.count} attendances")
      attendances_to_advise.each do |attendance|
        Rails.logger.info("[Warning attendance] #{attendance.to_param}")
        try_with('WARN') do
          Rails.logger.info('[Sending warning]')
          attendance.advise!
          EmailNotifications.cancelling_registration_warning(attendance).deliver
        end
      end
    end
  end

  private

  def try_with(action)
    Rails.logger.info(" processing [#{action}]")
    yield
  rescue StandardError => e
    Airbrake.notify(e.message, action: action)
    Rails.logger.info("  [FAILED #{action}] #{e.message}")
  ensure
    Rails.logger.flush
  end
end
