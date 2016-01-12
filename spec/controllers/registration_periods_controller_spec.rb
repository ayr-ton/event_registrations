# == Schema Information
#
# Table name: registration_periods
#
#  id             :integer          not null, primary key
#  event_id       :integer
#  title          :string(255)
#  start_at       :datetime
#  end_at         :datetime
#  created_at     :datetime
#  updated_at     :datetime
#  price_cents    :integer          default(0), not null
#  price_currency :string(255)      default("BRL"), not null
#

describe RegistrationPeriodsController, type: :controller do
  context 'unauthenticated' do
    describe 'GET #new' do
      it 'redirects to login' do
        get :new, event_id: 'foo'
        expect(response).to redirect_to login_path
      end
    end
    describe 'POST #create' do
      it 'redirects to login' do
        post :create, event_id: 'foo'
        expect(response).to redirect_to login_path
      end
    end
  end

  context 'logged as normal user' do
    let(:user) { FactoryGirl.create(:user) }
    before { sign_in user }

    describe 'GET #new' do
      it 'redirects to login' do
        get :new, event_id: 'foo'
        expect(response).to redirect_to root_path
      end
    end

    describe 'POST #create' do
      it 'redirects to login' do
        post :create, event_id: 'foo'
        expect(response).to redirect_to root_path
      end
    end
  end

  context 'logged as admin user' do
    let(:admin) { FactoryGirl.create(:admin) }
    before { sign_in admin }

    describe 'GET #new' do
      context 'with a valid event' do
        let!(:event) { FactoryGirl.create :event }
        it 'assigns the variables and render the template' do
          get :new, event_id: event
          expect(assigns(:event)).to eq event
          expect(assigns(:registration_period)).to be_a_new RegistrationPeriod
          expect(response).to render_template :new
        end
      end
      context 'with an invalid event' do
        it 'renders 404' do
          get :new, event_id: 'foo'
          expect(response).to have_http_status 404
        end
      end
    end

    describe 'POST #create' do
      let(:event) { FactoryGirl.create :event }
      context 'with valid parameters' do
        it 'creates the period and redirects to event' do
          start_date = Time.zone.now
          end_date = 1.week.from_now

          post :create, event_id: event, registration_period: { title: 'foo', start_at: start_date, end_at: end_date, price: 100 }
          period_persisted = RegistrationPeriod.last
          registration_period = assigns(:registration_period)
          expect(period_persisted.title).to eq 'foo'
          expect(period_persisted.start_at.utc.to_i).to eq start_date.to_i
          expect(period_persisted.end_at.utc.to_i).to eq end_date.to_i
          expect(period_persisted.price).to eq 100
          expect(response).to redirect_to new_event_registration_period_path(event, registration_period)
        end
      end

      context 'with invalid parameters' do
        context 'and invalid period params' do
          it 'renders form with the errors' do
            post :create, event_id: event, registration_period: { title: '' }
            period = assigns(:registration_period)

            expect(period).to be_a RegistrationPeriod
            expect(period.errors.full_messages).to eq ['Title não pode ficar em branco', 'Start at não pode ficar em branco', 'End at não pode ficar em branco']
            expect(response).to render_template :new
          end
        end

        context 'and invalid event' do
          it 'renders 404' do
            post :create, event_id: 'foo', registration_period: { title: '' }
            expect(response).to have_http_status 404
          end
        end
      end
    end
  end
end