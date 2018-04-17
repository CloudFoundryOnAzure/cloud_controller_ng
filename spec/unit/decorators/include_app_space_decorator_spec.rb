require 'spec_helper'

module VCAP::CloudController
  RSpec.describe IncludeAppSpaceDecorator do
    subject(:decorator) {IncludeAppSpaceDecorator}
    let(:space1) {Space.make(name: 'first-space')}
    let(:space2) {Space.make(name: 'second-space')}
    let(:apps) { [AppModel.make(space: space1), AppModel.make(space: space2), AppModel.make(space: space1)] }

    it 'decorates the given hash with spaces from apps' do
      wreathless_hash = {foo: 'bar'}
      hash = subject.decorate(wreathless_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to match_array([SpacePresenter.new(space1).to_hash, SpacePresenter.new(space2).to_hash])
    end

    it 'does not overwrite other included fields' do
      wreathless_hash = {foo: 'bar', included: {monkeys: ['zach', 'greg']}}
      hash = subject.decorate(wreathless_hash, apps)
      expect(hash[:foo]).to eq('bar')
      expect(hash[:included][:spaces]).to match_array([SpacePresenter.new(space1).to_hash, SpacePresenter.new(space2).to_hash])
      expect(hash[:included][:monkeys]).to match_array(['zach', 'greg'])
    end
  end
end
