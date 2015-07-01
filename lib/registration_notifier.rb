# encoding: UTF-8
class RegistrationNotifier
  def cancel
    Event.active_for(Time.zone.now).each do |event|
      attendances_to_advise = event.attendances.for_cancelation
      attendances_to_advise.each do |attendance|
        Rails.logger.info("[Attendance] #{attendance.to_param}")
        try_with('CANCEL') do
          attendance.cancel
          EmailNotifications.cancelling_registration(attendance).deliver_now
        end
      end
    end
  end

  def cancel_warning
    Rails.logger.info("Perform cancellation warning to #{Event.active_for(Time.zone.now).count} events")
    Event.active_for(Time.zone.now).each do |event|
      attendances_to_advise = event.attendances.for_cancelation_warning
      Rails.logger.info("Warning #{attendances_to_advise.count} attendances")
      attendances_to_advise.each do |attendance|
        Rails.logger.info("[Warning attendance] #{attendance.to_param}")
        try_with('WARN') do
          Rails.logger.info('[Sending warning]')
          attendance.advise!
          EmailNotifications.cancelling_registration_warning(attendance).deliver_now
        end
      end
    end
  end

  private

  def try_with(action)
    yield
    Rails.logger.info("  [#{action}] OK")
  rescue => e
    Airbrake.notify(e)
    Rails.logger.info("  [FAILED #{action}] #{e.message}")
  ensure
    Rails.logger.flush
  end
end
