require "spec_helper"
require "rubygems/dependency_installer"

describe "Backup::CLI" do
  let(:cli)     { Backup::CLI }
  let(:s)       { sequence "" }

  before  { @argv_save = ARGV }
  after   { ARGV.replace(@argv_save) }

  describe "#perform" do
    let(:model_a) { Backup::Model.new(:test_trigger_a, "test label a") }
    let(:model_b) { Backup::Model.new(:test_trigger_b, "test label b") }
    let(:s) { sequence "" }

    after { Backup::Model.send(:reset!) }

    describe "setting logger options" do
      let(:logger_options) { Backup::Logger.instance_variable_get(:@config).dsl }

      before do
        expect(Backup::Config).to receive(:load).ordered
        expect(Backup::Logger).to receive(:start!).ordered
        expect(model_a).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered
        expect(model_b).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered
      end

      it "configures console and logfile loggers by default" do
        ARGV.replace(["perform", "-t", "test_trigger_a,test_trigger_b"])
        cli.start

        expect(logger_options.console.quiet).to eq(false)
        expect(logger_options.logfile.enabled).to eq(true)
        expect(logger_options.logfile.log_path).to eq("")
        expect(logger_options.syslog.enabled).to eq(false)
      end

      it "configures only the syslog" do
        ARGV.replace(
          ["perform", "-t", "test_trigger_a,test_trigger_b",
           "--quiet", "--no-logfile", "--syslog"]
        )
        cli.start

        expect(logger_options.console.quiet).to eq(true)
        expect(logger_options.logfile.enabled).to eq(false)
        expect(logger_options.logfile.log_path).to eq("")
        expect(logger_options.syslog.enabled).to eq(true)
      end

      it "forces console logging" do
        ARGV.replace(
          ["perform", "-t", "test_trigger_a,test_trigger_b", "--no-quiet"]
        )
        cli.start

        expect(logger_options.console.quiet).to eq(false)
        expect(logger_options.logfile.enabled).to eq(true)
        expect(logger_options.logfile.log_path).to eq("")
        expect(logger_options.syslog.enabled).to eq(false)
      end

      it "forces the logfile and syslog to be disabled" do
        ARGV.replace(
          ["perform", "-t", "test_trigger_a,test_trigger_b",
           "--no-logfile", "--no-syslog"]
        )
        cli.start

        expect(logger_options.console.quiet).to eq(false)
        expect(logger_options.logfile.enabled).to eq(false)
        expect(logger_options.logfile.log_path).to eq("")
        expect(logger_options.syslog.enabled).to eq(false)
      end

      it "configures the log_path" do
        ARGV.replace(
          ["perform", "-t", "test_trigger_a,test_trigger_b",
           "--log-path", "my/log/path"]
        )
        cli.start

        expect(logger_options.console.quiet).to eq(false)
        expect(logger_options.logfile.enabled).to eq(true)
        expect(logger_options.logfile.log_path).to eq("my/log/path")
        expect(logger_options.syslog.enabled).to eq(false)
      end
    end # describe 'setting logger options'

    describe "setting triggers" do
      let(:model_c) { Backup::Model.new(:test_trigger_c, "test label c") }

      before do
        expect(Backup::Logger).to receive(:configure).ordered
        expect(Backup::Config).to receive(:load).ordered
        expect(Backup::Logger).to receive(:start!).ordered
      end

      it "performs a given trigger" do
        expect(model_a).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered
        expect(model_b).to receive(:perform!).never

        ARGV.replace(
          ["perform", "-t", "test_trigger_a"]
        )
        cli.start
      end

      it "performs multiple triggers" do
        expect(model_a).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered
        expect(model_b).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        ARGV.replace(
          ["perform", "-t", "test_trigger_a,test_trigger_b"]
        )
        cli.start
      end

      it "performs multiple models that share a trigger name" do
        expect(model_c).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        model_d = Backup::Model.new(:test_trigger_c, "test label d")
        expect(model_d).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        ARGV.replace(
          ["perform", "-t", "test_trigger_c"]
        )
        cli.start
      end

      it "performs unique models only once, in the order first found" do
        expect(model_a).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered
        expect(model_b).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered
        expect(model_c).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        ARGV.replace(
          ["perform", "-t", "test_trigger_a,test_trigger_b,test_trigger_c,test_trigger_b"]
        )
        cli.start
      end

      it "performs unique models only once, in the order first found (wildcard)" do
        expect(model_a).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered
        expect(model_b).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered
        expect(model_c).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        ARGV.replace(
          ["perform", "-t", "test_trigger_*"]
        )
        cli.start
      end
    end # describe 'setting triggers'

    describe "failure to prepare for backups" do
      before do
        expect(Backup::Logger).to receive(:configure).ordered
        expect(Backup::Logger).to receive(:start!).never
        expect(model_a).to receive(:perform!).never
        expect(model_b).to receive(:perform!).never
        expect(Backup::Logger).to receive(:clear!).never
      end

      describe "when errors are raised while loading config.rb" do
        before do
          expect(Backup::Config).to receive(:load).ordered.and_raise("config load error")
        end

        it "aborts with status code 3 and logs messages to the console only" do
          expectations = [
            proc do |err|
              expect(err).to be_a(Backup::CLI::Error)
              expect(err.message).to match(/config load error/)
            end,
            proc { |err| expect(err).to be_a(String) }
          ]
          expect(Backup::Logger).to receive(:error).ordered.exactly(2).times do |err|
            expectation = expectations.shift
            expectation.call(err) if expectation
          end

          expect(Backup::Logger).to receive(:abort!).ordered

          expect do
            ARGV.replace(
              ["perform", "-t", "test_trigger_a"]
            )
            cli.start
          end.to raise_error(SystemExit) { |exit| expect(exit.status).to be(3) }
        end
      end

      describe "when no models are found for the given triggers" do
        before do
          expect(Backup::Config).to receive(:load).ordered
        end

        it "aborts and logs messages to the console only" do
          expect(Backup::Logger).to receive(:error).ordered do |err|
            expect(err).to be_a(Backup::CLI::Error)
            expect(err.message).to match(
              /No Models found for trigger\(s\) 'test_trigger_foo'/
            )
          end

          expect(Backup::Logger).to receive(:abort!).ordered

          expect do
            ARGV.replace(
              ["perform", "-t", "test_trigger_foo"]
            )
            cli.start
          end.to raise_error(SystemExit) { |exit| expect(exit.status).to be(3) }
        end
      end
    end # describe 'failure to prepare for backups'

    describe "exit codes and notifications" do
      let(:notifier_a) { double }
      let(:notifier_b) { double }
      let(:notifier_c) { double }
      let(:notifier_d) { double }

      before do
        allow(Backup::Config).to receive(:load)
        allow(Backup::Logger).to receive(:start!)
        allow(model_a).to receive(:notifiers).and_return([notifier_a, notifier_c])
        allow(model_b).to receive(:notifiers).and_return([notifier_b, notifier_d])
      end

      specify "when jobs are all successful" do
        allow(model_a).to receive(:exit_status).and_return(0)
        allow(model_b).to receive(:exit_status).and_return(0)

        expect(model_a).to receive(:perform!).ordered
        expect(notifier_a).to receive(:perform!).ordered
        expect(notifier_c).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        expect(model_b).to receive(:perform!).ordered
        expect(notifier_b).to receive(:perform!).ordered
        expect(notifier_d).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        ARGV.replace(
          ["perform", "-t", "test_trigger_a,test_trigger_b"]
        )
        cli.start
      end

      specify "when a job has warnings" do
        allow(model_a).to receive(:exit_status).and_return(1)
        allow(model_b).to receive(:exit_status).and_return(0)

        expect(model_a).to receive(:perform!).ordered
        expect(notifier_a).to receive(:perform!).ordered
        expect(notifier_c).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        expect(model_b).to receive(:perform!).ordered
        expect(notifier_b).to receive(:perform!).ordered
        expect(notifier_d).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        expect do
          ARGV.replace(
            ["perform", "-t", "test_trigger_a,test_trigger_b"]
          )
          cli.start
        end.to raise_error(SystemExit) { |err| expect(err.status).to be(1) }
      end

      specify "when a job has non-fatal errors" do
        allow(model_a).to receive(:exit_status).and_return(2)
        allow(model_b).to receive(:exit_status).and_return(0)

        expect(model_a).to receive(:perform!).ordered
        expect(notifier_a).to receive(:perform!).ordered
        expect(notifier_c).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        expect(model_b).to receive(:perform!).ordered
        expect(notifier_b).to receive(:perform!).ordered
        expect(notifier_d).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        expect do
          ARGV.replace(
            ["perform", "-t", "test_trigger_a,test_trigger_b"]
          )
          cli.start
        end.to raise_error(SystemExit) { |err| expect(err.status).to be(2) }
      end

      specify "when a job has fatal errors" do
        allow(model_a).to receive(:exit_status).and_return(3)
        allow(model_b).to receive(:exit_status).and_return(0)

        expect(model_a).to receive(:perform!).ordered
        expect(notifier_a).to receive(:perform!).ordered
        expect(notifier_c).to receive(:perform!).ordered

        expect(Backup::Logger).to receive(:clear!).never
        expect(model_b).to receive(:perform!).never

        expect do
          ARGV.replace(
            ["perform", "-t", "test_trigger_a,test_trigger_b"]
          )
          cli.start
        end.to raise_error(SystemExit) { |err| expect(err.status).to be(3) }
      end

      specify "when jobs have errors and warnings" do
        allow(model_a).to receive(:exit_status).and_return(2)
        allow(model_b).to receive(:exit_status).and_return(1)

        expect(model_a).to receive(:perform!).ordered
        expect(notifier_a).to receive(:perform!).ordered
        expect(notifier_c).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        expect(model_b).to receive(:perform!).ordered
        expect(notifier_b).to receive(:perform!).ordered
        expect(notifier_d).to receive(:perform!).ordered
        expect(Backup::Logger).to receive(:clear!).ordered

        expect do
          ARGV.replace(
            ["perform", "-t", "test_trigger_a,test_trigger_b"]
          )
          cli.start
        end.to raise_error(SystemExit) { |err| expect(err.status).to be(2) }
      end
    end # describe 'exit codes and notifications'

    describe "--check" do
      it "runs the check command" do
        # RSpec aliases old check method to __check_without_any_instance__,
        # and thor does not like it, rendering a warning message about the lack
        # of description. Here we define a description before stubbing the method.
        cli.desc "check", "RSpec Check Command"

        expect_any_instance_of(cli).to receive(:check).and_raise(SystemExit)
        expect do
          ARGV.replace(
            ["perform", "-t", "test_trigger_foo", "--check"]
          )
          cli.start
        end.to raise_error(SystemExit)
      end
    end # describe '--check'
  end # describe '#perform'

  describe "#check" do
    it "fails if errors are raised" do
      allow(Backup::Config).to receive(:load).and_raise("an error")

      out, err = capture_io do
        ARGV.replace(["check"])
        expect do
          cli.start
        end.to raise_error(SystemExit) { |exit| expect(exit.status).to be(1) }
      end

      expect(err).to match(/RuntimeError: an error/)
      expect(err).to match(/\[error\] Configuration Check Failed/)
      expect(out).to be_empty
    end

    it "fails if warnings are issued" do
      allow(Backup::Config).to receive(:load) do
        Backup::Logger.warn "warning message"
      end

      out, err = capture_io do
        ARGV.replace(["check"])
        expect do
          cli.start
        end.to raise_error(SystemExit) { |exit| expect(exit.status).to be(1) }
      end

      expect(err).to match(/\[warn\] warning message/)
      expect(err).to match(/\[error\] Configuration Check Failed/)
      expect(out).to be_empty
    end

    it "succeeds if there are no errors or warnings" do
      allow(Backup::Config).to receive(:load)

      out, err = capture_io do
        ARGV.replace(["check"])
        expect do
          cli.start
        end.to raise_error(SystemExit) { |exit| expect(exit.status).to be(0) }
      end

      expect(err).to be_empty
      expect(out).to match(/\[info\] Configuration Check Succeeded/)
    end

    it "uses --config-file if given" do
      # Note: Thor#options is returning a HashWithIndifferentAccess.
      expect(Backup::Config).to receive(:load) do |options|
        options[:config_file] == "/my/config.rb"
      end
      allow(Backup::Logger).to receive(:abort!) # suppress output

      ARGV.replace(["check", "--config-file", "/my/config.rb"])
      expect do
        cli.start
      end.to raise_error(SystemExit) { |exit| expect(exit.status).to be(0) }
    end
  end # describe '#check'

  describe "#generate:model" do
    before do
      @tmpdir = Dir.mktmpdir("backup_spec")
      SandboxFileUtils.activate!(@tmpdir)
    end

    after do
      FileUtils.rm_r(@tmpdir, force: true, secure: true)
    end

    context "when given a --config-file" do
      context "when no config file exists" do
        it "should create both a config and a model under the given path" do
          Dir.chdir(@tmpdir) do |path|
            model_file  = File.join(path, "custom", "models", "my_test_trigger.rb")
            config_file = File.join(path, "custom", "config.rb")

            out, err = capture_io do
              ARGV.replace([
                "generate:model",
                "--config-file", config_file,
                "--trigger",
                "my test#trigger"
              ])
              cli.start
            end

            expect(err).to be_empty
            expect(out).to eq("Generated configuration file: '#{config_file}'.\n" \
                          "Generated model file: '#{model_file}'.\n")
            expect(File.exist?(model_file)).to eq(true)
            expect(File.exist?(config_file)).to eq(true)
          end
        end
      end

      context "when a config file already exists" do
        it "should only create a model under the given path" do
          Dir.chdir(@tmpdir) do |path|
            model_file  = File.join(path, "custom", "models", "my_test_trigger.rb")
            config_file = File.join(path, "custom", "config.rb")
            FileUtils.mkdir_p(File.join(path, "custom"))
            FileUtils.touch(config_file)

            expect(cli::Helpers).to receive(:overwrite?).with(config_file).never
            expect(cli::Helpers).to receive(:overwrite?).with(model_file).and_return(true)

            out, err = capture_io do
              ARGV.replace([
                "generate:model",
                "--config-file", config_file,
                "--trigger",
                "my+test@trigger"
              ])
              cli.start
            end

            expect(err).to be_empty
            expect(out).to eq("Generated model file: '#{model_file}'.\n")
            expect(File.exist?(model_file)).to eq(true)
          end
        end
      end

      context "when a model file already exists" do
        it "should prompt to overwrite the model under the given path" do
          Dir.chdir(@tmpdir) do |path|
            model_file  = File.join(path, "models", "test_trigger.rb")
            config_file = File.join(path, "config.rb")
            FileUtils.mkdir_p(File.dirname(model_file))
            FileUtils.touch(model_file)

            expect($stdin).to receive(:gets).and_return("n")

            out, err = capture_io do
              ARGV.replace([
                "generate:model",
                "--config-file", config_file,
                "--trigger",
                "test_trigger"
              ])
              cli.start
            end

            expect(err).to include("Do you want to overwrite?")
            expect(out).to eq("Generated configuration file: '#{config_file}'.\n")
            expect(File.exist?(config_file)).to eq(true)
          end
        end
      end
    end # context 'when given a --config-file'

    context "when not given a --config-file" do
      it "should create both a config and a model under the root path" do
        Dir.chdir(@tmpdir) do |path|
          Backup::Config.send(:update, root_path: path)
          model_file  = File.join(path, "models", "test_trigger.rb")
          config_file = File.join(path, "config.rb")

          out, err = capture_io do
            ARGV.replace(["generate:model", "--trigger", "test_trigger"])
            cli.start
          end

          expect(err).to be_empty
          expect(out).to eq("Generated configuration file: '#{config_file}'.\n" \
                        "Generated model file: '#{model_file}'.\n")
          expect(File.exist?(model_file)).to eq(true)
          expect(File.exist?(config_file)).to eq(true)
        end
      end
    end

    it "should include the correct option values" do
      options = <<-EOS.lines.to_a.map(&:strip).map { |l| l.partition(" ") }
        databases (mongodb, mysql, openldap, postgresql, redis, riak)
        storages (cloud_files, dropbox, ftp, local, qiniu, rsync, s3, scp, sftp)
        syncers (cloud_files, rsync_local, rsync_pull, rsync_push, s3)
        encryptor (gpg, openssl)
        compressor (bzip2, custom, gzip)
        notifiers (campfire, command, datadog, flowdock, hipchat, http_post, mail, nagios, pagerduty, prowl, pushover, ses, slack, twitter)
      EOS

      out, err = capture_io do
        ARGV.replace(["help", "generate:model"])
        cli.start
      end

      expect(err).to be_empty
      options.each do |option|
        expect(out).to match(/#{ option[0] }.*#{ option[2] }/)
      end
    end
  end # describe '#generate:model'

  describe "#generate:config" do
    before do
      @tmpdir = Dir.mktmpdir("backup_spec")
      SandboxFileUtils.activate!(@tmpdir)
    end

    after do
      FileUtils.rm_r(@tmpdir, force: true, secure: true)
    end

    context "when given a --config-file" do
      it "should create a config file in the given path" do
        Dir.chdir(@tmpdir) do |path|
          config_file = File.join(path, "custom", "my_config.rb")

          out, err = capture_io do
            ARGV.replace(["generate:config",
                          "--config-file", config_file])
            cli.start
          end

          expect(err).to be_empty
          expect(out).to eq("Generated configuration file: '#{config_file}'.\n")
          expect(File.exist?(config_file)).to eq(true)
        end
      end
    end

    context "when not given a --config-file" do
      it "should create a config file in the root path" do
        Dir.chdir(@tmpdir) do |path|
          Backup::Config.send(:update, root_path: path)
          config_file = File.join(path, "config.rb")

          out, err = capture_io do
            ARGV.replace(["generate:config"])
            cli.start
          end

          expect(err).to be_empty
          expect(out).to eq("Generated configuration file: '#{config_file}'.\n")
          expect(File.exist?(config_file)).to eq(true)
        end
      end
    end

    context "when a config file already exists" do
      it "should prompt to overwrite the config file" do
        Dir.chdir(@tmpdir) do |path|
          Backup::Config.send(:update, root_path: path)
          config_file = File.join(path, "config.rb")
          FileUtils.mkdir_p(File.dirname(config_file))
          FileUtils.touch(config_file)

          expect($stdin).to receive(:gets).and_return("n")

          out, err = capture_io do
            ARGV.replace(["generate:config"])
            cli.start
          end

          expect(err).to include("Do you want to overwrite?")
          expect(out).to be_empty
        end
      end
    end
  end # describe '#generate:config'

  describe "#version" do
    specify "using `backup version`" do
      ARGV.replace ["version"]
      out, err = capture_io do
        cli.start
      end
      expect(err).to be_empty
      expect(out).to eq("Backup #{Backup::VERSION}\n")
    end

    specify "using `backup -v`" do
      ARGV.replace ["-v"]
      out, err = capture_io do
        cli.start
      end
      expect(err).to be_empty
      expect(out).to eq("Backup #{Backup::VERSION}\n")
    end
  end

  describe "Helpers" do
    let(:helpers) { Backup::CLI::Helpers }

    describe "#overwrite?" do
      it "prompts user and accepts confirmation" do
        expect(File).to receive(:exist?).with("a/path").and_return(true)
        expect($stderr).to receive(:print).with(
          "A file already exists at 'a/path'.\nDo you want to overwrite? [y/n] "
        )
        expect($stdin).to receive(:gets).and_return("yes\n")

        expect(helpers.overwrite?("a/path")).to be_truthy
      end

      it "prompts user and accepts cancelation" do
        expect(File).to receive(:exist?).with("a/path").and_return(true)
        expect($stderr).to receive(:print).with(
          "A file already exists at 'a/path'.\nDo you want to overwrite? [y/n] "
        )
        expect($stdin).to receive(:gets).and_return("no\n")

        expect(helpers.overwrite?("a/path")).to be_falsy
      end

      it "returns true if path does not exist" do
        expect(File).to receive(:exist?).with("a/path").and_return(false)
        expect($stderr).to receive(:print).never
        expect(helpers.overwrite?("a/path")).to eq(true)
      end
    end
  end # describe 'Helpers'
end
