# encoding: utf-8

require File.expand_path('../../spec_helper.rb', __FILE__)

module Backup
describe Storage::Hg do
  let(:model)   { Model.new(:test_trigger, 'test label') }
  let(:storage) { Storage::Hg.new(model) }
  let(:s) { sequence '' }

  it_behaves_like 'a subclass of Storage::SCMBase'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:ssh) { mock }
    let(:timestamp) { Time.now.strftime("%Y.%m.%d.%H.%M.%S") }
    let(:remote_path) { File.join('my/path') }
    let(:syncer_dirs) {
      [ "tmp" ]
    }

    before do
      Timecop.freeze
      storage.package.time = timestamp
      storage.ip = '123.45.678.90'
      storage.path = 'my/path'
      storage.syncer.add '/tmp'
      connection.stubs(:ssh).returns(ssh)
    end
    after { Timecop.return }

    it 'init repo and commit' do
      storage.stubs(:utility).with(:hg).returns('hg')

      storage.expects(:connection).yields(connection)

      connection.expects(:exec!).with(
        "mkdir -p '#{remote_path}'"
      )
      connection.expects(:exec!).with(
        "cd '#{remote_path}' && hg init"
      )

      storage.syncer.expects(:perform!)

      connection.expects(:exec!).with(
        "cd '#{remote_path}' && hg add #{storage.package.trigger}"
      )
      syncer_dirs.each do |dir|
        connection.expects(:exec!).with(
          "cd '#{remote_path}' && hg add #{dir}"
        )
      end
      connection.expects(:exec!).with(
        "cd '#{remote_path}' && hg commit -m 'backup #{storage.package.time}'"
      )

      storage.send(:transfer!)
    end

  end

end
end
