# frozen_string_literal: true

module AgileAllianceService
  def self.check_member(email)
    url = "#{APP_CONFIG[:agile_alliance][:api_host]}/check_member/#{email}"
    response = HTTParty.get(url, headers: { 'AUTHORIZATION' => APP_CONFIG[:agile_alliance][:api_token] })
    response.present? && JSON.parse(response.body)['member']
  rescue JSON::ParserError
    false
  rescue URI::InvalidURIError
    false
  end
end
