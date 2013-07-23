# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Logger::FogAdapter do

  it 'replaces STDOUT fog warning channel' do
    expect( Fog::Logger[:warning] ).to be Logger::FogAdapter
  end

  describe '#tty?' do
    it 'returns false' do
      expect( Logger::FogAdapter.tty? ).to be(false)
    end
  end

  describe '#write' do
    it 'logs fog warnings as info messages' do
      Logger.expects(:info).with('[fog] [WARNING] some message')
      Fog::Logger.warning 'some message'
    end

    it 'handles multiline messages' do
      Logger.expects(:info).with(
        "[fog] [WARNING] some message\n" +
        "[fog] with multiple lines"
      )
      Fog::Logger.warning "some message\nwith multiple lines"
    end
  end
end
end
