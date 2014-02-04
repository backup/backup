# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

module Backup
describe Config do
  let(:config) { Config }

  # Note: spec_helper resets Config before each example

  describe '#load' do

    it 'loads config.rb and models' do
      File.stubs(
        :exist? => true,
        :read => "# Backup v4.x Configuration\n@loaded << :config",
        :directory? => true
      )
      Dir.stubs(:[] => ['model_a', 'model_b'])
      File.expects(:read).with('model_a').returns('@loaded << :model_a')
      File.expects(:read).with('model_b').returns('@loaded << :model_b')

      dsl = config::DSL.new
      dsl.instance_variable_set(:@loaded, [])
      config::DSL.stubs(:new => dsl)

      config.load

      expect( dsl.instance_variable_get(:@loaded) ).to eq(
        [:config, :model_a, :model_b]
      )
    end

    it 'raises an error if config_file does not exist' do
      config_file = File.expand_path('foo')
      expect do
        config.load(:config_file => config_file)
      end.to raise_error {|err|
        expect( err ).to be_a config::Error
        expect( err.message ).to match(
          /Could not find configuration file: '#{ config_file }'/
        )
      }
    end

    it 'raises an error if config file version is invalid' do
      File.stubs(
        :exist? => true,
        :read => '# Backup v3.x Configuration',
        :directory? => true
      )
      Dir.stubs(:[] => [])

      expect do
        config.load(:config_file => '/foo')
      end.to raise_error {|err|
        expect( err ).to be_a config::Error
        expect( err.message ).to match(/Invalid Configuration File/)
      }
    end

    describe 'setting config paths from command line options' do
      let(:default_root_path) {
        File.join(File.expand_path(ENV['HOME'] || ''), 'Backup')
      }

      before do
        File.stubs(
          :exist? => true,
          :read => '# Backup v4.x Configuration',
          :directory? => true
        )
        Dir.stubs(:[] => [])
      end

      context 'when no options are given' do
        it 'uses defaults' do
          config.load

          config::DEFAULTS.each do |attr, ending|
            expect( config.send(attr) ).to eq File.join(default_root_path, ending)
          end
        end
      end

      context 'when no root_path is given' do

        it 'updates the given paths' do
          options = { :data_path => '/my/data' }
          config.load(options)

          expect( config.root_path ).to eq default_root_path
          expect( config.tmp_path  ).to eq(
            File.join(default_root_path, config::DEFAULTS[:tmp_path])
          )
          expect( config.data_path ).to eq '/my/data'
        end

        it 'expands relative paths using PWD' do
          options = {
            :tmp_path  => 'my_tmp',
            :data_path => '/my/data'
          }
          config.load(options)

          expect( config.root_path ).to eq default_root_path
          expect( config.tmp_path  ).to eq File.expand_path('my_tmp')
          expect( config.data_path ).to eq '/my/data'
        end

        it 'overrides config.rb settings only for the paths given' do
          config::DSL.any_instance.expects(:_config_options).returns(
            { :root_path => '/orig/root',
              :tmp_path  => '/orig/root/my_tmp',
              :data_path => '/orig/root/my_data' }
          )
          options = { :tmp_path => 'new_tmp' }
          config.load(options)

          expect( config.root_path ).to eq '/orig/root'
          # the root_path set in config.rb will not apply
          # to relative paths given on the command line.
          expect( config.tmp_path  ).to eq File.expand_path('new_tmp')
          expect( config.data_path ).to eq '/orig/root/my_data'
        end

      end

      context 'when a root_path is given' do

        it 'updates all paths' do
          options = {
            :root_path => '/my/root',
            :tmp_path  => 'my_tmp',
            :data_path => '/my/data'
          }
          config.load(options)

          expect( config.root_path ).to eq '/my/root'
          expect( config.tmp_path  ).to eq '/my/root/my_tmp'
          expect( config.data_path ).to eq '/my/data'
        end

        it 'uses root_path to update defaults' do
          config.load(:root_path => '/my/root')

          config::DEFAULTS.each do |attr, ending|
            expect( config.send(attr) ).to eq File.join('/my/root', ending)
          end
        end

        it 'overrides all config.rb settings' do
          config::DSL.any_instance.expects(:_config_options).returns(
            { :root_path => '/orig/root',
              :tmp_path  => '/orig/root/my_tmp',
              :data_path => '/orig/root/my_data' }
          )
          options = { :root_path => '/new/root', :tmp_path => 'new_tmp' }
          config.load(options)

          expect( config.root_path ).to eq '/new/root'
          expect( config.tmp_path  ).to eq '/new/root/new_tmp'
          # paths not given on the command line will be updated to their
          # default location (relative to the new root)
          expect( config.data_path ).to eq(
            File.join('/new/root', config::DEFAULTS[:data_path])
          )
        end

      end

    end

  end # describe '#load'

  describe '#hostname' do
    before do
      config.instance_variable_set(:@hostname, nil)
      Utilities.stubs(:utility).with(:hostname).returns('/path/to/hostname')
    end

    it 'caches the hostname' do
      Utilities.expects(:run).once.with('/path/to/hostname').returns('my_hostname')
      config.hostname.should == 'my_hostname'
      config.hostname.should == 'my_hostname'
    end
  end


  describe '#set_root_path' do

    context 'when the given path == @root_path' do
      it 'should return @root_path without requiring the path to exist' do
        File.expects(:directory?).never
        expect do
          config.send(:set_root_path, config.root_path).
              should == config.root_path
        end.not_to raise_error
      end
    end

    context 'when the given path exists' do
      it 'should set and return the @root_path' do
        expect do
          config.send(:set_root_path, Dir.pwd).should == Dir.pwd
        end.not_to raise_error
        config.root_path.should == Dir.pwd
      end

      it 'should expand relative paths' do
        expect do
          config.send(:set_root_path, '').should == Dir.pwd
        end.not_to raise_error
        config.root_path.should == Dir.pwd
      end
    end

    context 'when the given path does not exist' do
      it 'should raise an error' do
        path = File.expand_path('foo')
        expect do
          config.send(:set_root_path, 'foo')
        end.to raise_error {|err|
          err.should be_an_instance_of config::Error
          err.message.should match(/Root Path Not Found/)
          err.message.should match(/Path was: #{ path }/)
        }
      end
    end

  end # describe '#set_root_path'

  describe '#set_path_variable' do
    after do
      if config.instance_variable_defined?(:@var)
        config.send(:remove_instance_variable, :@var)
      end
    end

    context 'when a path is given' do
      context 'when the given path is an absolute path' do
        it 'should always use the given path' do
          path = File.expand_path('foo')

          config.send(:set_path_variable, 'var', path, 'none', '/root/path')
          config.instance_variable_get(:@var).should == path

          config.send(:set_path_variable, 'var', path, 'none', nil)
          config.instance_variable_get(:@var).should == path
        end
      end

      context 'when the given path is a relative path' do
        context 'when a root_path is given' do
          it 'should append the path to the root_path' do
            config.send(:set_path_variable, 'var', 'foo', 'none', '/root/path')
            config.instance_variable_get(:@var).should == '/root/path/foo'
          end
        end
        context 'when a root_path is not given' do
          it 'should expand the path' do
            path = File.expand_path('foo')

            config.send(:set_path_variable, 'var', 'foo', 'none', false)
            config.instance_variable_get(:@var).should == path
          end
        end
      end
    end # context 'when a path is given'

    context 'when no path is given' do
      context 'when a root_path is given' do
        it 'should use the root_path with the given ending' do
          config.send(:set_path_variable, 'var', nil, 'ending', '/root/path')
          config.instance_variable_get(:@var).should == '/root/path/ending'
        end
      end
      context 'when a root_path is not given' do
        it 'should do nothing' do
          config.send(:set_path_variable, 'var', nil, 'ending', false)
          config.instance_variable_defined?(:@var).should be_false
        end
      end
    end # context 'when no path is given'

  end # describe '#set_path_variable'

  describe '#reset!' do
    before do
      @env_user = ENV['USER']
      @env_home = ENV['HOME']
    end

    after do
      ENV['USER'] = @env_user
      ENV['HOME'] = @env_home
    end

    it 'should be called to set variables when module is loaded' do
      # just to avoid 'already initialized constant' warnings
      config.send(:remove_const, 'DEFAULTS')

      expected = config.instance_variables.sort.map(&:to_sym) - [:@hostname, :@mocha]
      config.instance_variables.each do |var|
        config.send(:remove_instance_variable, var)
      end
      config.instance_variables.should be_empty

      load File.expand_path('../../lib/backup/config.rb', __FILE__)
      config.instance_variables.sort.map(&:to_sym).should == expected
    end

    context 'when setting @user' do
      context 'when ENV["USER"] is set' do
        before { ENV['USER'] = 'test' }

        it 'should set value for @user to ENV["USER"]' do
          config.send(:reset!)
          config.user.should == 'test'
        end
      end

      context 'when ENV["USER"] is not set' do
        before { ENV.delete('USER') }

        it 'should set value using the user login name' do
          config.send(:reset!)
          config.user.should == Etc.getpwuid.name
        end
      end
    end # context 'when setting @user'

    context 'when setting @root_path' do
      context 'when ENV["HOME"] is set' do
        before { ENV['HOME'] = 'test/home/dir' }

        it 'should set value using ENV["HOME"]' do
          config.send(:reset!)
          config.root_path.should ==
              File.join(File.expand_path('test/home/dir'),'Backup')
        end
      end

      context 'when ENV["HOME"] is not set' do
        before { ENV.delete('HOME') }

        it 'should set value using $PWD' do
          config.send(:reset!)
          config.root_path.should == File.expand_path('Backup')
        end
      end
    end # context 'when setting @root_path'

    context 'when setting other path variables' do
      before { ENV['HOME'] = 'test/home/dir' }

      it 'should use #update' do
        config.expects(:update).with(
          :root_path => File.join(File.expand_path('test/home/dir'),'Backup')
        )
        config.send(:reset!)
      end
    end

  end # describe '#reset!'

end
end
