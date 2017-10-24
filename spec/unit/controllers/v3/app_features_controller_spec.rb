require 'rails_helper'

RSpec.describe AppFeaturesController, type: :controller do
  let(:app_model) { VCAP::CloudController::AppModel.make(enable_ssh: true) }
  let(:space) { app_model.space }
  let(:org) { space.organization }
  let(:user) { VCAP::CloudController::User.make }
  let(:app_feature_ssh_response) { { 'name' => 'ssh', 'description' => 'Enable SSHing into the app.', 'enabled' => true } }

  before do
    space.update(allow_ssh: true)
    TestConfig.override(allow_app_ssh_access: true)
    set_current_user_as_role(role: 'admin', org: nil, space: nil, user: user)
  end

  describe '#index' do
    let(:pagination_hash) do
      {
        'total_results' => 1,
        'total_pages' => 1,
        'first' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
        'last' => { 'href' => "/v3/apps/#{app_model.guid}/features" },
        'next' => nil,
        'previous' => nil,
      }
    end
    describe 'authorization' do
      role_to_expected_http_response = {
        'admin' => 200,
        'admin_read_only' => 200,
        'global_auditor' => 200,
        'space_developer' => 200,
        'space_manager' => 200,
        'space_auditor' => 200,
        'org_manager' => 200,
        'org_auditor' => 404,
        'org_billing_manager' => 404,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            get :index, app_guid: app_model.guid

            expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
            if expected_return_value == 200
              expect(parsed_body).to eq(
                'resources' => [app_feature_ssh_response],
                'pagination' => pagination_hash
              ), "failed to match parsed_body for role #{role}: got #{parsed_body}"
            end
          end
        end
      end
    end

    it 'returns app features' do
      get :index, app_guid: app_model.guid
      expect(parsed_body).to eq(
        'resources' => [app_feature_ssh_response],
        'pagination' => pagination_hash
      )
    end

    it 'responds 404 when the app does not exist' do
      get :index, app_guid: 'no-such-guid'

      expect(response.status).to eq(404)
    end
  end

  describe '#show' do
    describe 'authorization' do
      role_to_expected_http_response = {
        'admin' => 200,
        'admin_read_only' => 200,
        'global_auditor' => 200,
        'space_developer' => 200,
        'space_manager' => 200,
        'space_auditor' => 200,
        'org_manager' => 200,
        'org_auditor' => 404,
        'org_billing_manager' => 404,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            get :show, app_guid: app_model.guid, name: 'ssh'

            expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
            if expected_return_value == 200
              expect(parsed_body).to eq(app_feature_ssh_response), "failed to match parsed_body for role #{role}: got #{parsed_body}"
            end
          end
        end
      end
    end

    it 'returns specific app feature' do
      get :show, app_guid: app_model.guid, name: 'ssh'
      expect(parsed_body).to eq(app_feature_ssh_response)
    end

    it 'throws 404 for a non-existent feature' do
      set_current_user_as_role(role: 'admin', org: org, space: space, user: user)

      get :show, app_guid: app_model.guid, name: 'i-dont-exist'

      expect(response.status).to eq(404)
      expect(response).to have_error_message('Feature not found')
    end

    it 'responds 404 when the app does not exist' do
      get :show, app_guid: 'no-such-guid', name: 'ssh'

      expect(response.status).to eq(404)
    end
  end

  describe '#update' do
    before do
    end

    describe 'authorization' do
      role_to_expected_http_response = {
        'admin' => 200,
        'admin_read_only' => 403,
        'global_auditor' => 403,
        'space_developer' => 200,
        'space_manager' => 403,
        'space_auditor' => 403,
        'org_manager' => 403,
        'org_auditor' => 404,
        'org_billing_manager' => 404,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        describe "as an #{role}" do
          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            patch :update, app_guid: app_model.guid, name: 'ssh', body: { enabled: false }

            expect(response.status).to eq(expected_return_value), "role #{role}: expected  #{expected_return_value}, got: #{response.status}"
          end
        end
      end
    end

    it 'updates a given app feature' do
      expect {
        patch :update, app_guid: app_model.guid, name: 'ssh', body: { enabled: false }
      }.to change { app_model.reload.enable_ssh }.to(false)

      expect(response.status).to eq(200)
      expect(parsed_body['name']).to eq('ssh')
      expect(parsed_body['description']).to eq('Enable SSHing into the app.')
      expect(parsed_body['enabled']).to eq(false)
    end

    it 'responds 404 when the feature does not exist' do
      expect {
        patch :update, app_guid: app_model.guid, name: 'no-such-feature', body: { enabled: false }
      }.not_to change { app_model.reload.values }

      expect(response.status).to eq(404)
    end

    it 'responds 404 when the app does not exist' do
      patch :update, app_guid: 'no-such-guid', name: 'ssh', body: { enabled: false }

      expect(response.status).to eq(404)
    end

    it 'responds 422 when enabled param is missing' do
      expect {
        patch :update, app_guid: app_model.guid, name: 'ssh'
      }.not_to change { app_model.reload.values }

      expect(response.status).to eq(422)
      expect(response).to have_error_message('Enabled must be a boolean')
    end
  end
end
