require 'spec_helper'
require File.join(File.dirname(__FILE__), '../../lib/registration_no_show')

describe RegistrationNoShow do
  let(:no_show) { RegistrationNoShow.new }

  before do
    ::Rails.logger.stubs(:info)
    ::Rails.logger.stubs(:flush)
    Airbrake.stubs(:notify)
  end

  describe '#no_show' do
    context 'with current and past events' do
      let(:past_event) { FactoryGirl.create(:event, start_date: 7.days.ago, end_date: 6.days.ago) }
      let(:current_event) { FactoryGirl.create :event }

      context 'two attendances' do
        context 'and both are pending' do
          let!(:attendance) { FactoryGirl.create(:attendance, event: past_event, status: :pending) }
          let!(:other_attendance) { FactoryGirl.create(:attendance, event: past_event, status: :accepted) }
          let!(:out_attendance) { FactoryGirl.create(:attendance, event: current_event, status: :accepted) }
          it 'marks the attendances from past events and ignores the attendances from current event' do
            no_show.no_show
            expect(attendance.reload.status).to eq 'no_show'
            expect(other_attendance.reload.status).to eq 'no_show'
            expect(out_attendance.reload.status).to eq 'accepted'
          end
        end
      end
    end
  end
end