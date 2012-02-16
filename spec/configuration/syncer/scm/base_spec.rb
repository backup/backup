# encoding: utf-8

require File.expand_path('../../../../spec_helper.rb', __FILE__)

describe Backup::Configuration::Syncer::SCM do
  before do
    Backup::Configuration::Syncer::SCM::Base.defaults do |default|
      default.protocol           = 'http'
      default.username           = 'my_user_name'
      default.password           = 'secret'
      default.ip                 = 'example.com'
      default.port               = 1234
      default.path               = '~/backups/'
      default.additional_options = 'some_additional_options'
      # base.directories/repositories # can not have a default value

    end
  end

  after { Backup::Configuration::Syncer::SCM::Base.clear_defaults! }

  it 'should set the default base configuration' do
    base = Backup::Configuration::Syncer::SCM::Base
    base.protocol.should    == 'http'
    base.username.should    == 'my_user_name'
    base.password.should    == 'secret'
    base.ip.should          == 'example.com'
    base.port.should        == 1234
    base.path.should        == '~/backups/'
    base.additional_options == 'some_additional_options'
  end

  describe '#clear_defaults!' do
    it 'should clear all the defaults, resetting them to nil' do
      Backup::Configuration::Syncer::SCM::Base.clear_defaults!

      base = Backup::Configuration::Syncer::SCM::Base
      base.protocol.should    == nil
      base.username.should    == nil
      base.password.should    == nil
      base.ip.should          == nil
      base.port.should        == nil
      base.path.should        == nil
      base.additional_options == nil
    end
  end

end
