# encoding: utf-8

module Backup
shared_examples 'a subclass of Storage::SSHBase' do

  it_behaves_like 'a subclass of Storage::Base'

  describe '#initialize' do

    it 'provides default values' do
      expect( storage.storage_id  ).to be_nil
      expect( storage.keep        ).to be_nil
      expect( storage.username    ).to be_nil
      expect( storage.password    ).to be_nil
      expect( storage.ssh_options ).to eq({})
      expect( storage.ip          ).to be_nil
      expect( storage.port        ).to be 22
      expect( storage.path        ).to eq 'backups'
    end

    it 'configures the storage' do
      storage = Storage::SSHBase.new(model, :my_id) do |ssh|
        ssh.keep = 2
        ssh.username    = 'my_username'
        ssh.password    = 'my_password'
        ssh.ssh_options = { :keys => ['my/key'] }
        ssh.ip          = 'my_host'
        ssh.port        = 123
        ssh.path        = 'my/path'
      end

      expect( storage.storage_id  ).to eq 'my_id'
      expect( storage.keep        ).to be 2
      expect( storage.username    ).to eq 'my_username'
      expect( storage.password    ).to eq 'my_password'
      expect( storage.ssh_options ).to eq :keys => ['my/key']
      expect( storage.ip          ).to eq 'my_host'
      expect( storage.port        ).to be 123
      expect( storage.path        ).to eq 'my/path'
    end

    it 'converts a tilde path to a relative path' do
      storage = Storage::SSHBase.new(model) do |ssh|
        ssh.path = '~/my/path'
      end
      expect( storage.path ).to eq 'my/path'
    end

    it 'does not alter an absolute path' do
      storage = Storage::SSHBase.new(model) do |ssh|
        ssh.path = '/my/path'
      end
      expect( storage.path ).to eq '/my/path'
    end

  end # describe '#initialize'

  describe '#connection' do
    let(:connection) { mock }

    before do
      storage.ip = '123.45.678.90'
      storage.username = 'my_user'
      storage.password = 'my_pass'
      storage.ssh_options = { :keys => ['my/key'] }
    end

    it 'yields a connection to the remote server' do
      Net::SSH.expects(:start).with(
        '123.45.678.90', 'my_user', :password => 'my_pass', :port => 22,
        :keys => ['my/key']
      ).yields(connection)

      storage.send(:connection) do |ssh|
        expect( ssh ).to be connection
      end
    end
  end # describe '#connection'

end
end
