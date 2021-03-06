# frozen_string_literal: true

RSpec.describe RegistrationGroup, type: :model do
  let(:event) { FactoryBot.create :event }
  let(:group) { FactoryBot.create :registration_group, event: event }

  context 'associations' do
    it { is_expected.to have_many(:attendances).dependent(:restrict_with_error) }
    it { is_expected.to belong_to :event }
    it { is_expected.to belong_to(:leader).class_name('User') }
    it { is_expected.to belong_to(:registration_quota) }
  end

  context 'validations' do
    it { is_expected.to validate_presence_of :event }
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_numericality_of(:discount).allow_nil }

    context 'paid_in_advance group validation' do
      context 'when is a paid_in_advance group' do
        subject(:group) { FactoryBot.build(:registration_group, paid_in_advance: true) }
        it 'not be valid and will have errors on capacity and amount presence' do
          expect(group.valid?).to be_falsey
          expect(group.errors.full_messages).to eq ['Capacidade: não pode ficar em branco', 'Valor das inscrições no grupo: não pode ficar em branco']
        end
      end
      context 'when is not a paid_in_advance group' do
        subject(:group) { FactoryBot.build(:registration_group, paid_in_advance: false) }
        it { expect(group.valid?).to be_truthy }
      end
    end

    context '#enough_capacity' do
      context 'for event' do
        let(:event) { FactoryBot.create :event, attendance_limit: 5 }
        let(:group) { FactoryBot.build :registration_group, event: event, paid_in_advance: true, capacity: 10, amount: 100 }
        it 'not consider the group as valid and gives the correct error message' do
          expect(group.valid?).to be_falsey
          expect(group.errors[:capacity]).to eq [I18n.t('registration_group.event_capacity_error')]
        end
      end
      context 'for quota' do
        let(:quota) { FactoryBot.create :registration_quota, quota: 5 }
        let(:group) { FactoryBot.build :registration_group, registration_quota: quota, paid_in_advance: true, capacity: 10, amount: 100 }
        it 'not consider the group as valid and gives the correct error message' do
          expect(group.valid?).to be_falsey
          expect(group.errors[:capacity]).to eq [I18n.t('registration_group.quota_capacity_error')]
        end
      end
    end

    context '#discount_or_amount_present?' do
      context 'having no discount or amount' do
        let!(:group) { FactoryBot.build :registration_group, event: event, amount: nil, discount: nil }
        it 'not consider the group as valid and gives the correct error message' do
          expect(group.valid?).to be false
          expect(group.errors[:discount]).to eq [I18n.t('registration_group.errors.discount_or_amount_present')]
        end
      end
      context 'having discount' do
        let!(:group) { FactoryBot.build :registration_group, event: event, amount: nil, discount: 10 }
        it { expect(group.valid?).to be true }
      end
      context 'having amount' do
        let!(:group) { FactoryBot.build :registration_group, event: event, amount: 10, discount: nil }
        it { expect(group.valid?).to be true }
      end
    end
  end

  describe '#generate_token' do
    let(:event) { FactoryBot.create :event }
    let(:group) { FactoryBot.create :registration_group, event: event }
    before { SecureRandom.expects(:hex).returns('eb693ec8252cd630102fd0d0fb7c3485') }
    it { expect(group.token).to eq 'eb693ec8252cd630102fd0d0fb7c3485' }
  end

  describe '#qtd_attendances' do
    context 'just pending attendances' do
      let(:group) { FactoryBot.create :registration_group, event: event }
      before { 2.times { FactoryBot.create :attendance, registration_group: group } }
      it { expect(group.qtd_attendances).to eq 2 }
    end

    context 'with cancelled attendances' do
      let(:group) { FactoryBot.create :registration_group, event: event }
      before do
        2.times { @last_attendance = FactoryBot.create(:attendance, registration_group: group) }
        @last_attendance.cancelled!
      end
      it { expect(group.qtd_attendances).to eq 1 }
    end
  end

  describe '#total_price' do
    let(:group) { FactoryBot.create :registration_group, event: event }

    context 'with one attendance and 20% discount over full price' do
      let!(:attendance) { FactoryBot.create(:attendance, event: event, registration_group: group) }
      it { expect(group.total_price).to eq 400.00 }
    end

    context 'with more attendances and 20% discount' do
      let!(:first_attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, registration_value: 440.00) }
      let!(:second_attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, registration_value: 530.00) }
      let!(:third_attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, registration_value: 700.00) }
      let!(:fourth_attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, registration_value: nil) }
      it { expect(group.total_price).to eq 1670.00 }
    end

    context 'when has cancelled attendances' do
      let!(:attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, registration_value: 440.00) }
      let!(:other) { FactoryBot.create(:attendance, event: event, registration_group: group, registration_value: 530.00) }
      before { other.cancelled! }
      it { expect(group.total_price).to eq 440.00 }
    end
  end

  describe '#price?' do
    let!(:period) { RegistrationPeriod.create(event: event, start_at: 1.month.ago, end_at: 1.month.from_now, price: 100) }
    let(:group) { FactoryBot.create :registration_group, event: event, discount: 20 }

    context 'without attendances' do
      it { expect(group.price?).to be_falsey }
    end

    context 'with attendances' do
      context 'and no value' do
        let(:group) { FactoryBot.create :registration_group, event: event }
        let!(:attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, registration_value: 0) }
        it { expect(group.price?).to be_falsey }
      end

      context 'and having value' do
        let!(:attendance) { FactoryBot.create(:attendance, event: event, registration_group: group) }
        it { expect(group.price?).to be_truthy }
      end
    end
  end

  describe '#accept_members?' do
    let(:group) { FactoryBot.create :registration_group, event: event, discount: 100 }

    context 'with a pending attendance' do
      let!(:attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, status: 'pending') }
      it { expect(group.accept_members?).to be_truthy }
    end
  end

  describe '#payment_pendent?' do
    context 'consistent data' do
      context 'with one pendent' do
        let(:group) { FactoryBot.create :registration_group, event: event, discount: 20 }
        let!(:attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, status: 'pending') }
        it { expect(group.paid?).to be_falsey }
      end

      context 'with one paid' do
        let(:group) { FactoryBot.create :registration_group, event: event, discount: 20 }
        let!(:attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, status: 'paid') }
        it { expect(group.paid?).to be_truthy }
      end
    end

    context 'with inconsistent data' do
      context 'with one paid and one pendent' do
        let(:group) { FactoryBot.create :registration_group, event: event, discount: 20 }
        let!(:attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, status: 'paid') }
        let!(:other_attendance) { FactoryBot.create(:attendance, event: event, registration_group: group, status: 'pending') }
        it { expect(group.paid?).to be_truthy }
      end
    end
  end

  describe '#leader_name' do
    let(:user) { FactoryBot.create :user }
    context 'with a defined leader' do
      let(:group) { FactoryBot.create :registration_group, event: event, discount: 20, leader: user }
      it { expect(group.leader_name).to eq user.full_name }
    end

    context 'with a defined leader' do
      let(:group) { FactoryBot.create :registration_group, event: event }
      it { expect(group.leader_name).to eq nil }
    end
  end

  describe '#free?' do
    context 'with a free' do
      let(:group) { FactoryBot.create(:registration_group, event: event, discount: 100) }
      it { expect(group.free?).to be_truthy }
    end

    context 'with a non free' do
      let(:group) { FactoryBot.create(:registration_group, event: event, discount: 99) }
      it { expect(group.free?).to be_falsey }
    end
  end

  describe '#floor?' do
    context 'with minimun_size nil' do
      let(:group) { FactoryBot.create(:registration_group, minimum_size: nil) }
      it { expect(group.floor?).to be_falsey }
    end

    context 'with minimun_size 0' do
      let(:group) { FactoryBot.create(:registration_group, minimum_size: 0) }
      it { expect(group.floor?).to be_falsey }
    end

    context 'with minimun_size 1' do
      let(:group) { FactoryBot.create(:registration_group, minimum_size: 1) }
      it { expect(group.floor?).to be_falsey }
    end

    context 'with minimun_size 2' do
      let(:group) { FactoryBot.create(:registration_group, minimum_size: 2) }
      it { expect(group.floor?).to be_truthy }
    end

    context 'with minimun_size greather than 2' do
      let(:group) { FactoryBot.create(:registration_group, minimum_size: 10) }
      it { expect(group.floor?).to be_truthy }
    end
  end

  describe '#incomplete?' do
    context 'with nil minimun_size' do
      let(:group) { FactoryBot.create(:registration_group, minimum_size: nil) }
      it { expect(group.incomplete?).to be_falsey }
    end

    context 'with minimun_size of 0' do
      let(:group) { FactoryBot.create(:registration_group, minimum_size: 0) }
      it { expect(group.incomplete?).to be_falsey }
    end

    context 'with minimun_size of 2' do
      let(:group) { FactoryBot.create(:registration_group, minimum_size: 2) }
      context 'and two attendances pending' do
        let!(:attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'pending') }
        let!(:other_attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'pending') }
        it { expect(group.incomplete?).to be_truthy }
      end
      context 'and one attendance paid and other pending' do
        let!(:attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'paid') }
        let!(:other_attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'pending') }
        it { expect(group.incomplete?).to be_truthy }
      end
      context 'and one attendance paid and other accepted' do
        let!(:attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'paid') }
        let!(:other_attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'accepted') }
        it { expect(group.incomplete?).to be_truthy }
      end
      context 'and two attendances paid' do
        let!(:attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'paid') }
        let!(:other_attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'paid') }
        it { expect(group.incomplete?).to be_falsey }
      end
      context 'and one attendance paid and other confirmed' do
        let!(:attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'paid') }
        let!(:other_attendance) { FactoryBot.create(:attendance, registration_group: group, status: 'confirmed') }
        it { expect(group.incomplete?).to be_falsey }
      end
    end
  end

  describe '#to_s' do
    let(:group) { FactoryBot.create :registration_group }
    it { expect(group.to_s).to eq group.name }
  end

  describe '#capacity_left' do
    context 'having capacity' do
      let(:group) { FactoryBot.create :registration_group, capacity: 100 }
      let!(:attendance) { FactoryBot.create :attendance, registration_group: group }
      let!(:other_attendance) { FactoryBot.create :attendance, registration_group: group, status: :cancelled }
      it { expect(group.capacity_left).to eq 99 }
    end
    context 'having no capacity' do
      let(:group) { FactoryBot.create :registration_group, capacity: nil }
      let!(:attendance) { FactoryBot.create :attendance, registration_group: group }
      let!(:other_attendance) { FactoryBot.create :attendance, registration_group: group, status: :cancelled }
      it { expect(group.capacity_left).to eq 0 }
    end
  end

  describe '#vacancies?' do
    context 'having vacancies' do
      let(:group) { FactoryBot.create :registration_group, capacity: 3 }
      let!(:attendance) { FactoryBot.create :attendance, registration_group: group }
      let!(:other_attendance) { FactoryBot.create :attendance, registration_group: group, status: :accepted }
      let!(:cancelled_attendance) { FactoryBot.create :attendance, registration_group: group, status: :cancelled }

      it { expect(group.vacancies?).to eq true }
    end
    context 'having no vacancies' do
      let(:group) { FactoryBot.create :registration_group, capacity: 2 }
      let!(:attendance) { FactoryBot.create :attendance, registration_group: group }
      let!(:cancelled_attendance) { FactoryBot.create :attendance, registration_group: group, status: :cancelled }
      let!(:other_attendance) { FactoryBot.create :attendance, registration_group: group, status: :accepted }
      it { expect(group.vacancies?).to eq false }
    end
    context 'having no capacity defined' do
      let(:group) { FactoryBot.create :registration_group, capacity: nil }
      it { expect(group.vacancies?).to be true }
    end
  end
end
