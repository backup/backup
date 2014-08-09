# encoding: utf-8

require File.expand_path('../spec_helper.rb', __FILE__)
require 'rubygems/dependency_installer'

describe 'Backup::CLI' do
  let(:cli)     { Backup::CLI }
  let(:s)       { sequence '' }

  before  { @argv_save = ARGV }
  after   { ARGV.replace(@argv_save) }

  describe '#perform' do
    let(:model_a) { Backup::Model.new(:test_trigger_a, 'test label a') }
    let(:model_b) { Backup::Model.new(:test_trigger_b, 'test label b') }
    let(:s) { sequence '' }

    after { Backup::Model.send(:reset!) }

    describe 'setting logger options' do
      let(:logger_options) { Backup::Logger.instance_variable_get(:@config).dsl }

      before do
        Backup::Config.expects(:load).in_sequence(s)
        Backup::Logger.expects(:start!).in_sequence(s)
        model_a.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)
        model_b.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)
      end

      it 'configures console and logfile loggers by default' do
        expect do
          ARGV.replace(['perform', '-t', 'test_trigger_a,test_trigger_b'])
          cli.start
        end.not_to raise_error

        logger_options.console.quiet.should be(false)
        logger_options.logfile.enabled.should be_true
        logger_options.logfile.log_path.should == ''
        logger_options.syslog.enabled.should be(false)
      end

      it 'configures only the syslog' do
        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a,test_trigger_b',
            '--quiet', '--no-logfile', '--syslog']
          )
          cli.start
        end.not_to raise_error

        logger_options.console.quiet.should be_true
        logger_options.logfile.enabled.should be_nil
        logger_options.logfile.log_path.should == ''
        logger_options.syslog.enabled.should be_true
      end

      it 'forces console logging' do
        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a,test_trigger_b', '--no-quiet']
          )
          cli.start
        end.not_to raise_error

        logger_options.console.quiet.should be_nil
        logger_options.logfile.enabled.should be_true
        logger_options.logfile.log_path.should == ''
        logger_options.syslog.enabled.should be(false)
      end

      it 'forces the logfile and syslog to be disabled' do
        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a,test_trigger_b',
              '--no-logfile', '--no-syslog']
          )
          cli.start
        end.not_to raise_error

        logger_options.console.quiet.should be(false)
        logger_options.logfile.enabled.should be_nil
        logger_options.logfile.log_path.should == ''
        logger_options.syslog.enabled.should be_nil
      end

      it 'configures the log_path' do
        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a,test_trigger_b',
              '--log-path', 'my/log/path']
          )
          cli.start
        end.not_to raise_error

        logger_options.console.quiet.should be(false)
        logger_options.logfile.enabled.should be_true
        logger_options.logfile.log_path.should == 'my/log/path'
        logger_options.syslog.enabled.should be(false)
      end
    end # describe 'setting logger options'

    describe 'setting triggers' do
      let(:model_c) { Backup::Model.new(:test_trigger_c, 'test label c') }

      before do
        Backup::Logger.expects(:configure).in_sequence(s)
        Backup::Config.expects(:load).in_sequence(s)
        Backup::Logger.expects(:start!).in_sequence(s)
      end

      it 'performs a given trigger' do
        model_a.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)
        model_b.expects(:perform!).never

        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a']
          )
          cli.start
        end.not_to raise_error
      end

      it 'performs multiple triggers' do
        model_a.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)
        model_b.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a,test_trigger_b']
          )
          cli.start
        end.not_to raise_error
      end

      it 'performs multiple models that share a trigger name' do
        model_c.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        model_d = Backup::Model.new(:test_trigger_c, 'test label d')
        model_d.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_c']
          )
          cli.start
        end.not_to raise_error
      end

      it 'performs unique models only once, in the order first found' do
        model_a.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)
        model_b.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)
        model_c.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        expect do
          ARGV.replace(
            ['perform', '-t',
             'test_trigger_a,test_trigger_b,test_trigger_c,test_trigger_b']
          )
          cli.start
        end.not_to raise_error
      end

      it 'performs unique models only once, in the order first found (wildcard)' do
        model_a.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)
        model_b.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)
        model_c.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_*']
          )
          cli.start
        end.not_to raise_error
      end

    end # describe 'setting triggers'

    describe 'failure to prepare for backups' do
      before do
        Backup::Logger.expects(:configure).in_sequence(s)
        Backup::Logger.expects(:start!).never
        model_a.expects(:perform!).never
        model_b.expects(:perform!).never
        Backup::Logger.expects(:clear!).never
      end

      describe 'when errors are raised while loading config.rb' do
        before do
          Backup::Config.expects(:load).in_sequence(s).raises('config load error')
        end

        it 'aborts with status code 3 and logs messages to the console only' do

          Backup::Logger.expects(:error).in_sequence(s).with do |err|
            err.should be_a(Backup::CLI::Error)
            err.message.should match(/config load error/)
          end

          Backup::Logger.expects(:abort!).in_sequence(s)

          expect do
            ARGV.replace(
              ['perform', '-t', 'test_trigger_a']
            )
            cli.start
          end.to raise_error(SystemExit) {|exit| exit.status.should be(3) }
        end
      end

      describe 'when no models are found for the given triggers' do
        before do
          Backup::Config.expects(:load).in_sequence(s)
        end

        it 'aborts and logs messages to the console only' do
          Backup::Logger.expects(:error).in_sequence(s).with do |err|
            err.should be_a(Backup::CLI::Error)
            err.message.should match(
              /No Models found for trigger\(s\) 'test_trigger_foo'/
            )
          end

          Backup::Logger.expects(:abort!).in_sequence(s)

          expect do
            ARGV.replace(
              ['perform', '-t', 'test_trigger_foo']
            )
            cli.start
          end.to raise_error(SystemExit) {|exit| exit.status.should be(3) }
        end
      end
    end # describe 'failure to prepare for backups'

    describe 'exit codes and notifications' do
      let(:notifier_a) { mock }
      let(:notifier_b) { mock }
      let(:notifier_c) { mock }
      let(:notifier_d) { mock }

      before do
        Backup::Config.stubs(:load)
        Backup::Logger.stubs(:start!)
        model_a.stubs(:notifiers).returns([notifier_a, notifier_c])
        model_b.stubs(:notifiers).returns([notifier_b, notifier_d])
      end

      specify 'when jobs are all successful' do
        model_a.stubs(:exit_status).returns(0)
        model_b.stubs(:exit_status).returns(0)

        model_a.expects(:perform!).in_sequence(s)
        notifier_a.expects(:perform!).in_sequence(s)
        notifier_c.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        model_b.expects(:perform!).in_sequence(s)
        notifier_b.expects(:perform!).in_sequence(s)
        notifier_d.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        ARGV.replace(
          ['perform', '-t', 'test_trigger_a,test_trigger_b']
        )
        cli.start
      end

      specify 'when a job has warnings' do
        model_a.stubs(:exit_status).returns(1)
        model_b.stubs(:exit_status).returns(0)

        model_a.expects(:perform!).in_sequence(s)
        notifier_a.expects(:perform!).in_sequence(s)
        notifier_c.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        model_b.expects(:perform!).in_sequence(s)
        notifier_b.expects(:perform!).in_sequence(s)
        notifier_d.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a,test_trigger_b']
          )
          cli.start
        end.to raise_error(SystemExit) {|err| err.status.should be(1) }
      end

      specify 'when a job has non-fatal errors' do
        model_a.stubs(:exit_status).returns(2)
        model_b.stubs(:exit_status).returns(0)

        model_a.expects(:perform!).in_sequence(s)
        notifier_a.expects(:perform!).in_sequence(s)
        notifier_c.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        model_b.expects(:perform!).in_sequence(s)
        notifier_b.expects(:perform!).in_sequence(s)
        notifier_d.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a,test_trigger_b']
          )
          cli.start
        end.to raise_error(SystemExit) {|err| err.status.should be(2) }
      end

      specify 'when a job has fatal errors' do
        model_a.stubs(:exit_status).returns(3)
        model_b.stubs(:exit_status).returns(0)

        model_a.expects(:perform!).in_sequence(s)
        notifier_a.expects(:perform!).in_sequence(s)
        notifier_c.expects(:perform!).in_sequence(s)

        Backup::Logger.expects(:clear!).never
        model_b.expects(:perform!).never

        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a,test_trigger_b']
          )
          cli.start
        end.to raise_error(SystemExit) {|err| err.status.should be(3) }
      end

      specify 'when jobs have errors and warnings' do
        model_a.stubs(:exit_status).returns(2)
        model_b.stubs(:exit_status).returns(1)

        model_a.expects(:perform!).in_sequence(s)
        notifier_a.expects(:perform!).in_sequence(s)
        notifier_c.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        model_b.expects(:perform!).in_sequence(s)
        notifier_b.expects(:perform!).in_sequence(s)
        notifier_d.expects(:perform!).in_sequence(s)
        Backup::Logger.expects(:clear!).in_sequence(s)

        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_a,test_trigger_b']
          )
          cli.start
        end.to raise_error(SystemExit) {|err| err.status.should be(2) }
      end
    end # describe 'exit codes and notifications'

    describe '--check' do
      it 'runs the check command' do
        cli.any_instance.expects(:check).raises(SystemExit)
        expect do
          ARGV.replace(
            ['perform', '-t', 'test_trigger_foo', '--check']
          )
          cli.start
        end.to raise_error(SystemExit)
      end
    end # describe '--check'

  end # describe '#perform'

  describe '#check' do
    it 'fails if errors are raised' do
      Backup::Config.stubs(:load).raises('an error')

      out, err = capture_io do
        ARGV.replace(['check'])
        expect do
          cli.start
        end.to raise_error(SystemExit) {|exit| expect( exit.status ).to be(1) }
      end

      expect( err ).to match(/RuntimeError: an error/)
      expect( err ).to match(/\[error\] Configuration Check Failed/)
      expect( out ).to be_empty
    end

    it 'fails if warnings are issued' do
      Backup::Config.stubs(:load).with do
        Backup::Logger.warn 'warning message'
      end

      out, err = capture_io do
        ARGV.replace(['check'])
        expect do
          cli.start
        end.to raise_error(SystemExit) {|exit| expect( exit.status ).to be(1) }
      end

      expect( err ).to match(/\[warn\] warning message/)
      expect( err ).to match(/\[error\] Configuration Check Failed/)
      expect( out ).to be_empty
    end

    it 'succeeds if there are no errors or warnings' do
      Backup::Config.stubs(:load)

      out, err = capture_io do
        ARGV.replace(['check'])
        expect do
          cli.start
        end.to raise_error(SystemExit) {|exit| expect( exit.status ).to be(0) }
      end

      expect( err ).to be_empty
      expect( out ).to match(/\[info\] Configuration Check Succeeded/)
    end

    it 'uses --config-file if given' do
      # Note: Thor#options is returning a HashWithIndifferentAccess.
      Backup::Config.expects(:load).with do |options|
        options[:config_file] == '/my/config.rb'
      end
      Backup::Logger.stubs(:abort!) # suppress output

      ARGV.replace(['check', '--config-file', '/my/config.rb'])
      expect do
        cli.start
      end.to raise_error(SystemExit) {|exit| expect( exit.status ).to be(0) }
    end
  end # describe '#check'

  describe '#generate:model' do
    before do
      @tmpdir = Dir.mktmpdir('backup_spec')
      SandboxFileUtils.activate!(@tmpdir)
    end

    after do
      FileUtils.rm_r(@tmpdir, :force => true, :secure => true)
    end

    context 'when given a --config-file' do
      context 'when no config file exists' do
        it 'should create both a config and a model under the given path' do
          Dir.chdir(@tmpdir) do |path|
            model_file  = File.join(path, 'custom', 'models', 'my_test_trigger.rb')
            config_file = File.join(path, 'custom', 'config.rb')

            out, err = capture_io do
              ARGV.replace(['generate:model',
                 '--config-file', config_file,
                 '--trigger', 'my test#trigger'
              ])
              cli.start
            end

            err.should be_empty
            out.should == "Generated configuration file: '#{ config_file }'.\n" +
                          "Generated model file: '#{ model_file }'.\n"
            File.exist?(model_file).should be_true
            File.exist?(config_file).should be_true
          end
        end
      end

      context 'when a config file already exists' do
        it 'should only create a model under the given path' do
          Dir.chdir(@tmpdir) do |path|
            model_file  = File.join(path, 'custom', 'models', 'my_test_trigger.rb')
            config_file = File.join(path, 'custom', 'config.rb')
            FileUtils.mkdir_p(File.join(path, 'custom'))
            FileUtils.touch(config_file)

            cli::Helpers.expects(:overwrite?).with(config_file).never
            cli::Helpers.expects(:overwrite?).with(model_file).returns(true)

            out, err = capture_io do
              ARGV.replace(['generate:model',
                 '--config-file', config_file,
                 '--trigger', 'my+test@trigger'
              ])
              cli.start
            end

            err.should be_empty
            out.should == "Generated model file: '#{ model_file }'.\n"
            File.exist?(model_file).should be_true
          end
        end
      end

      context 'when a model file already exists' do
        it 'should prompt to overwrite the model under the given path' do
          Dir.chdir(@tmpdir) do |path|
            model_file  = File.join(path, 'models', 'test_trigger.rb')
            config_file = File.join(path, 'config.rb')
            FileUtils.mkdir_p(File.dirname(model_file))
            FileUtils.touch(model_file)

            $stdin.expects(:gets).returns('n')

            out, err = capture_io do
              ARGV.replace(['generate:model',
                  '--config-file', config_file,
                  '--trigger', 'test_trigger'
              ])
              cli.start
            end

            err.should include('Do you want to overwrite?')
            out.should == "Generated configuration file: '#{ config_file }'.\n"
            File.exist?(config_file).should be_true
          end
        end
      end

    end # context 'when given a --config-file'

    context 'when not given a --config-file' do
      it 'should create both a config and a model under the root path' do
        Dir.chdir(@tmpdir) do |path|
          Backup::Config.send(:update, :root_path => path)
          model_file  = File.join(path, 'models', 'test_trigger.rb')
          config_file = File.join(path, 'config.rb')

          out, err = capture_io do
            ARGV.replace(['generate:model', '--trigger', 'test_trigger'])
            cli.start
          end

          err.should be_empty
          out.should == "Generated configuration file: '#{ config_file }'.\n" +
                        "Generated model file: '#{ model_file }'.\n"
          File.exist?(model_file).should be_true
          File.exist?(config_file).should be_true
        end
      end
    end

    it 'should include the correct option values' do
      options = <<-EOS.lines.to_a.map(&:strip).map {|l| l.partition(' ') }
        databases (mongodb, mysql, openldap, postgresql, redis, riak)
        storages (cloud_files, dropbox, ftp, local, ninefold, rsync, s3, scp, sftp)
        syncers (cloud_files, rsync_local, rsync_pull, rsync_push, s3)
        encryptor (gpg, openssl)
        compressor (bzip2, custom, gzip)
        notifiers (campfire, flowdock, hipchat, http_post, mail, nagios, prowl, pushover, slack, twitter)
      EOS

      out, err = capture_io do
        ARGV.replace(['help', 'generate:model'])
        cli.start
      end

      expect( err ).to be_empty
      options.each do |option|
        expect( out ).to match(/#{ option[0] }.*#{ option[2] }/)
      end
    end

  end # describe '#generate:model'

  describe '#generate:config' do
    before do
      @tmpdir = Dir.mktmpdir('backup_spec')
      SandboxFileUtils.activate!(@tmpdir)
    end

    after do
      FileUtils.rm_r(@tmpdir, :force => true, :secure => true)
    end

    context 'when given a --config-file' do
      it 'should create a config file in the given path' do
        Dir.chdir(@tmpdir) do |path|
          config_file = File.join(path, 'custom', 'my_config.rb')

          out, err = capture_io do
            ARGV.replace(['generate:config',
                '--config-file', config_file
            ])
            cli.start
          end

          err.should be_empty
          out.should == "Generated configuration file: '#{ config_file }'.\n"
          File.exist?(config_file).should be_true
        end
      end
    end

    context 'when not given a --config-file' do
      it 'should create a config file in the root path' do
        Dir.chdir(@tmpdir) do |path|
          Backup::Config.send(:update, :root_path => path)
          config_file = File.join(path, 'config.rb')

          out, err = capture_io do
            ARGV.replace(['generate:config'])
            cli.start
          end

          err.should be_empty
          out.should == "Generated configuration file: '#{ config_file }'.\n"
          File.exist?(config_file).should be_true
        end
      end
    end

    context 'when a config file already exists' do
      it 'should prompt to overwrite the config file' do
        Dir.chdir(@tmpdir) do |path|
          Backup::Config.send(:update, :root_path => path)
          config_file = File.join(path, 'config.rb')
          FileUtils.mkdir_p(File.dirname(config_file))
          FileUtils.touch(config_file)

          $stdin.expects(:gets).returns('n')

          out, err = capture_io do
            ARGV.replace(['generate:config'])
            cli.start
          end

          err.should include('Do you want to overwrite?')
          out.should be_empty
        end
      end
    end

  end # describe '#generate:config'

  describe '#version' do
    specify 'using `backup version`' do
      ARGV.replace ['version']
      out, err = capture_io do
        cli.start
      end
      err.should be_empty
      out.should == "Backup #{ Backup::VERSION }\n"
    end

    specify 'using `backup -v`' do
      ARGV.replace ['-v']
      out, err = capture_io do
        cli.start
      end
      err.should be_empty
      out.should == "Backup #{ Backup::VERSION }\n"
    end
  end

  describe 'Helpers' do
    let(:helpers) { Backup::CLI::Helpers }

    describe '#overwrite?' do

      it 'prompts user and accepts confirmation' do
        File.expects(:exist?).with('a/path').returns(true)
        $stderr.expects(:print).with(
          "A file already exists at 'a/path'.\nDo you want to overwrite? [y/n] "
        )
        $stdin.expects(:gets).returns("yes\n")

        expect( helpers.overwrite?('a/path') ).to be_true
      end

      it 'prompts user and accepts cancelation' do
        File.expects(:exist?).with('a/path').returns(true)
        $stderr.expects(:print).with(
          "A file already exists at 'a/path'.\nDo you want to overwrite? [y/n] "
        )
        $stdin.expects(:gets).returns("no\n")

        expect( helpers.overwrite?('a/path') ).to be_false
      end

      it 'returns true if path does not exist' do
        File.expects(:exist?).with('a/path').returns(false)
        $stderr.expects(:print).never
        expect( helpers.overwrite?('a/path') ).to be_true
      end
    end

  end # describe 'Helpers'

end
