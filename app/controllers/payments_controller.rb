class PaymentsController < ApplicationController
  skip_before_action :authenticate_user!, :authorize_action

  # TODO: Finding things before actions is not the best way to go. Lazy fetch and use `event` method instead
  before_action :find_event, :find_invoice

  def checkout
    PagSeguroService.config
    payment = PagSeguro::PaymentRequest.new
    payment.notification_url = notification_url
    payment.redirect_url = back_url
    response = PagSeguroService.checkout(@invoice, payment)

    if response[:errors].present?
      flash[:error] = I18n.t('payments_controller.checkout.error', reason: 'xpto')
      redirect_to event_registration_groups_path(@event)
    else
      flash[:notice] = I18n.t('payments_controller.checkout.success')
      @invoice.send_it
      @invoice.save!
      redirect_to response[:url]
    end
  end

  private

  def back_url
    request.referer || root_path
  end

  def notification_url
    payment_notifications_url(
      type: 'pag_seguro',
      pedido: @invoice.id,
      store_code: APP_CONFIG[:pag_seguro][:store_code]
    )
  end

  def find_invoice
    @invoice = Invoice.find params[:id]
  rescue ActiveRecord::RecordNotFound
    redirect_to event_registration_groups_path(@event), alert: t('invoice.not_found')
  end
end
