# encoding: utf-8

shared_examples 'a subclass of Storage::SCMBase' do

  it_behaves_like 'a subclass of Storage::SSHBase'

  describe '#transfer!' do
    let(:connection) { mock }
    let(:ssh) { mock }
    let(:remote_path) { File.join('my/path') }

    before do
      storage.ip = '123.45.678.90'
      storage.path = 'my/path'
      connection.stubs(:ssh).returns(ssh)
    end

    it 'call abstract methods' do
      storage.expects(:connection).yields(connection)

      storage.expects(:init_repo)
      storage.syncer.expects(:perform!)
      storage.expects(:commit)

      storage.send(:transfer!)
    end

  end

end
