# frozen_string_literal: true

class AttendancesController < AuthenticatedController
  before_action :assign_event
  before_action :assign_attendance, except: %i[index create new waiting_list search to_approval attendance_past_info]
  before_action :check_organizer, only: %i[waiting_list to_approval index search]
  before_action :check_user, only: %i[show edit update]

  def new
    @attendance = Attendance.new(event: @event)
  end

  def create
    create_params = AttendanceParams.new(current_user, @event, params)
    @attendance = CreateAttendance.run_for(create_params)
    return redirect_to(event_attendance_path(@event, @attendance), flash: { notice: I18n.t('attendances.create.success') }) if @attendance.valid?

    flash[:error] = @attendance.errors.full_messages.join(' | ')
    render :new
  end

  def edit; end

  def update
    update_params = AttendanceParams.new(current_user, @event, params)
    @attendance = UpdateAttendance.run_for(update_params)
    return redirect_to event_attendances_path(event_id: @event, flash: { notice: I18n.t('attendances.update.success') }) if @attendance.valid?

    flash[:error] = @attendance.errors.full_messages.join(' | ')
    render :edit
  end

  def to_approval
    @attendances_to_approval = @event.attendances.waiting_approval
  end

  def waiting_list
    @waiting_list = @event.attendances.waiting
  end

  def index
    @attendances_list = @event.attendances.active.order(last_status_change_date: :desc)
    @waiting_total = @event.attendances.waiting.count
    @pending_total = @event.attendances.pending.count
    @accepted_total = @event.attendances.accepted.count
    @paid_total = @event.attendances.paid.count
    @reserved_total = @event.reserved_count
    @accredited_total = @event.attendances.showed_in.count
    @confirmed_total = @event.attendances.confirmed.count
    @cancelled_total = @event.attendances.cancelled.count
    @total = @event.attendances_count
  end

  def show; end

  def destroy
    @attendance.cancelled!
    respond_to do |format|
      format.js { return render 'attendances/attendance' }
      format.html { redirect_to event_attendance_path(@event, @attendance), flash: { notice: I18n.t('attendance.destroy.success') } }
    end
  end

  def change_status
    if params[:new_status] == 'accept'
      @attendance.accepted!
      EmailNotifications.registration_group_accepted(@attendance).deliver
    elsif params[:new_status] == 'recover'
      @attendance.pending!
    elsif params[:new_status] == 'pay'
      @attendance.paid!
    elsif params[:new_status] == 'confirm'
      @attendance.confirmed!
      EmailNotifications.registration_confirmed(@attendance).deliver
    elsif params[:new_status] == 'mark_show'
      @attendance.showed_in!
    else
      @attendance.pending!
    end

    respond_to do |format|
      format.js { render 'attendances/attendance' }
      format.html { redirect_to event_attendance_path(@event, @attendance) }
    end
  end

  def search
    @attendances_list = AttendanceRepository.instance.search_for_list(@event, params[:search], statuses_params)

    respond_to do |format|
      format.js {}
      format.csv do
        send_data AttendanceExportService.to_csv(@event), filename: 'attendances_list.csv'
      end
    end
  end

  def attendance_past_info
    @attendance = Attendance.where(email: params[:email]).order(created_at: :desc).first.dup if params[:email].present?
    @attendance = Attendance.new(email: params[:email]) if @attendance.blank?
    render 'attendances/attendance_info'
  end

  private

  def assign_event
    @event = Event.find(params[:event_id])
  end

  def assign_attendance
    @attendance = Attendance.find(params[:id])
  end

  def statuses_params
    params.select { |_key, value| value == 'true' }.keys
  end

  def check_user
    return if current_user.organizer_of?(@event)

    not_found if current_user.id != @attendance.user.id
  end
end
