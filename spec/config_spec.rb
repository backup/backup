# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)

describe 'Backup::Config' do
  let(:config) { Backup::Config }

  # Note: spec_helper resets Config before each example

  describe '#update' do
    let(:default_root_path) { config.root_path }

    context 'when a root_path is given' do
      it 'should use #set_root_path to set the new root_path' do
        config.expects(:set_root_path).with('a/path')

        config.update(:root_path => 'a/path')
      end

      it 'should set all paths using the new root_path' do
        config.expects(:set_root_path).with('path').returns('/root/path')
        Backup::Config::DEFAULTS.each do |key, val|
          config.expects(:set_path_variable).with(key, nil, val, '/root/path')
        end

        config.update(:root_path => 'path')
      end
    end # context 'when a root_path is given'

    context 'when a root_path is not given' do
      it 'should set all paths without using a root_path' do
        Backup::Config::DEFAULTS.each do |key, val|
          config.expects(:set_path_variable).with(key, nil, val, false)
        end

        config.update
      end
    end # context 'when a root_path is not given'

  end # describe '#update'

  describe '#load_config!' do
    context 'when @config_file exists' do
      before do
        File.expects(:exist?).with(config.config_file).returns(true)
      end

      it 'should load the config file' do
        File.expects(:read).with(config.config_file).returns(:file_contents)
        config.expects(:module_eval).with(:file_contents, config.config_file)

        expect do
          config.load_config!
        end.not_to raise_error
      end
    end

    context 'when @config_file does not exist' do
      before do
        File.expects(:exist?).returns(false)
      end

      it 'should raise an error' do
        File.expects(:read).never
        config.expects(:module_eval).never

        expect do
          config.load_config!
        end.to raise_error {|err|
          err.should be_an_instance_of Backup::Config::Error
          err.message.should match(
            /Could not find configuration file: '#{config.config_file}'/
          )
        }
      end
    end
  end # describe '#load_config!'

  describe '#preconfigure' do
    after do
      Backup.send(:remove_const, 'MyBackup') if Backup.const_defined?('MyBackup')
    end

    specify 'name must be a String' do
      expect do
        config.preconfigure(:Abc)
      end.to raise_error(Backup::Config::Error)
    end

    specify 'name must begin with a capital letter' do
      expect do
        config.preconfigure('myBackup')
      end.to raise_error(Backup::Config::Error)
    end

    specify 'name must not be a constant already in use' do
      expect do
        config.preconfigure('Archive')
      end.to raise_error(Backup::Config::Error)
    end

    specify 'Backup::Model may not be preconfigured' do
      expect do
        config.preconfigure('Model')
      end.to raise_error(Backup::Config::Error)
    end

    specify 'preconfigured models can only be preconfigured once' do
      block = Proc.new {}
      config.preconfigure('MyBackup', &block)
      klass = Backup.const_get('MyBackup')
      klass.superclass.should == Backup::Model

      expect do
        config.preconfigure('MyBackup', &block)
      end.to raise_error(Backup::Config::Error)
    end
  end

  describe '#hostname' do
    before do
      config.instance_variable_set(:@hostname, nil)
      Backup::Utilities.stubs(:utility).with(:hostname).returns('/path/to/hostname')
    end

    it 'caches the hostname' do
      Backup::Utilities.expects(:run).once.
          with('/path/to/hostname').returns('my_hostname')
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
          err.should be_an_instance_of Backup::Config::Error
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
      config.constants.each {|const| config.send(:remove_const, const) }

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

  describe '#add_dsl_constants!' do
    it 'should be called when the module is loaded' do
      config.constants.each {|const| config.send(:remove_const, const) }
      config.constants.should be_empty

      load File.expand_path('../../lib/backup/config.rb', __FILE__)

      Backup::Config.const_defined?('MySQL').should be_true
      Backup::Config.const_defined?('RSync').should be_true
      Backup::Config::RSync.const_defined?('Local').should be_true
    end
  end # describe '#add_dsl_constants!'

  describe '#create_modules' do
    module TestScope; end

    context 'when given an array of constant names' do
      it 'should create modules for the given scope' do
        config.send(:create_modules, TestScope, ['Foo', 'Bar'])
        TestScope.const_defined?('Foo').should be_true
        TestScope.const_defined?('Bar').should be_true
        TestScope::Foo.class.should == Module
        TestScope::Bar.class.should == Module
      end
    end

    context 'when the given array contains Hash values' do
      it 'should create deeply nested modules' do
        config.send(
          :create_modules,
          TestScope,
          [ 'FooBar', {
            :LevelA => [ 'NameA', {
              :LevelB => ['NameB']
            } ]
          } ]
        )
        TestScope.const_defined?('FooBar').should be_true
        TestScope.const_defined?('LevelA').should be_true
        TestScope::LevelA.const_defined?('NameA').should be_true
        TestScope::LevelA.const_defined?('LevelB').should be_true
        TestScope::LevelA::LevelB.const_defined?('NameB').should be_true
      end
    end
  end

  describe 'Backup.const_missing' do
    it 'should warn if Backup::CONFIG_FILE is referenced from an older config.rb' do
      Backup::Logger.expects(:warn)
      expect do
        Backup.const_get('CONFIG_FILE').should == Backup::Config.config_file
      end.not_to raise_error
    end

    it 'should still handle other missing constants' do
      expect do
        Backup.const_get('FOO')
      end.to raise_error(NameError, 'uninitialized constant Backup::FOO')
    end
  end
end
