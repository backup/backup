require "spec_helper"

module Backup
  describe Config do
    let(:config) { Config }
    let(:major_gem_version) { Gem::Version.new(Backup::VERSION).segments.first }

    # Note: spec_helper resets Config before each example

    describe "#load" do
      it "loads config.rb and models" do
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:read).and_return("# Backup v#{major_gem_version}.x Configuration\n@loaded << :config")
        allow(File).to receive(:directory?).and_return(true)
        allow(Dir).to receive(:[]).and_return(["model_a", "model_b"])
        expect(File).to receive(:read).with("model_a").and_return("@loaded << :model_a")
        expect(File).to receive(:read).with("model_b").and_return("@loaded << :model_b")

        dsl = config::DSL.new
        dsl.instance_variable_set(:@loaded, [])
        allow(config::DSL).to receive(:new).and_return(dsl)

        config.load

        expect(dsl.instance_variable_get(:@loaded)).to eq(
          [:config, :model_a, :model_b]
        )
      end

      it "raises an error if config_file does not exist" do
        config_file = File.expand_path("foo")
        expect do
          config.load(config_file: config_file)
        end.to raise_error config::Error, /Could not find configuration file: '#{ config_file }'/
      end

      it "raises an error if config file version is invalid" do
        allow(File).to receive(:exist?).and_return(true)
        allow(File).to receive(:read).and_return("# Backup v3.x Configuration")
        allow(File).to receive(:directory?).and_return(true)
        allow(Dir).to receive(:[]).and_return([])

        expect do
          config.load(config_file: "/foo")
        end.to raise_error config::Error, /Invalid Configuration File/
      end

      describe "setting config paths from command line options" do
        let(:default_root_path) do
          File.join(File.expand_path(ENV["HOME"] || ""), "Backup")
        end

        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(File).to receive(:read).and_return("# Backup v#{major_gem_version}.x Configuration")
          allow(File).to receive(:directory?).and_return(true)
          allow(Dir).to receive(:[]).and_return([])
        end

        context "when no options are given" do
          it "uses defaults" do
            config.load

            config::DEFAULTS.each do |attr, ending|
              expect(config.send(attr)).to eq File.join(default_root_path, ending)
            end
          end
        end

        context "when no root_path is given" do
          it "updates the given paths" do
            options = { data_path: "/my/data" }
            config.load(options)

            expect(config.root_path).to eq default_root_path
            expect(config.tmp_path).to eq(
              File.join(default_root_path, config::DEFAULTS[:tmp_path])
            )
            expect(config.data_path).to eq "/my/data"
          end

          it "expands relative paths using PWD" do
            options = {
              tmp_path: "my_tmp",
              data_path: "/my/data"
            }
            config.load(options)

            expect(config.root_path).to eq default_root_path
            expect(config.tmp_path).to eq File.expand_path("my_tmp")
            expect(config.data_path).to eq "/my/data"
          end

          it "overrides config.rb settings only for the paths given" do
            expect_any_instance_of(config::DSL).to receive(:_config_options).and_return(
              root_path: "/orig/root",
                tmp_path: "/orig/root/my_tmp",
                data_path: "/orig/root/my_data"
            )
            options = { tmp_path: "new_tmp" }
            config.load(options)

            expect(config.root_path).to eq "/orig/root"
            # the root_path set in config.rb will not apply
            # to relative paths given on the command line.
            expect(config.tmp_path).to eq File.expand_path("new_tmp")
            expect(config.data_path).to eq "/orig/root/my_data"
          end
        end

        context "when a root_path is given" do
          it "updates all paths" do
            options = {
              root_path: "/my/root",
              tmp_path: "my_tmp",
              data_path: "/my/data"
            }
            config.load(options)

            expect(config.root_path).to eq "/my/root"
            expect(config.tmp_path).to eq "/my/root/my_tmp"
            expect(config.data_path).to eq "/my/data"
          end

          it "uses root_path to update defaults" do
            config.load(root_path: "/my/root")

            config::DEFAULTS.each do |attr, ending|
              expect(config.send(attr)).to eq File.join("/my/root", ending)
            end
          end

          it "overrides all config.rb settings" do
            expect_any_instance_of(config::DSL).to receive(:_config_options).and_return(
              root_path: "/orig/root",
                tmp_path: "/orig/root/my_tmp",
                data_path: "/orig/root/my_data"
            )
            options = { root_path: "/new/root", tmp_path: "new_tmp" }
            config.load(options)

            expect(config.root_path).to eq "/new/root"
            expect(config.tmp_path).to eq "/new/root/new_tmp"
            # paths not given on the command line will be updated to their
            # default location (relative to the new root)
            expect(config.data_path).to eq(
              File.join("/new/root", config::DEFAULTS[:data_path])
            )
          end
        end
      end
    end # describe '#load'

    describe "#hostname" do
      before do
        config.instance_variable_set(:@hostname, nil)
        allow(Utilities).to receive(:utility).with(:hostname).and_return("/path/to/hostname")
      end

      it "caches the hostname" do
        expect(Utilities).to receive(:run).once.with("/path/to/hostname").and_return("my_hostname")
        expect(config.hostname).to eq("my_hostname")
        expect(config.hostname).to eq("my_hostname")
      end
    end

    describe "#set_root_path" do
      context "when the given path == @root_path" do
        it "should return @root_path without requiring the path to exist" do
          expect(File).to receive(:directory?).never
          expect(config.send(:set_root_path, config.root_path)).to eq(config.root_path)
        end
      end

      context "when the given path exists" do
        it "should set and return the @root_path" do
          expect(config.send(:set_root_path, Dir.pwd)).to eq(Dir.pwd)
          expect(config.root_path).to eq(Dir.pwd)
        end

        it "should expand relative paths" do
          expect(config.send(:set_root_path, "")).to eq(Dir.pwd)
          expect(config.root_path).to eq(Dir.pwd)
        end
      end

      context "when the given path does not exist" do
        it "should raise an error" do
          path = File.expand_path("foo")
          expect do
            config.send(:set_root_path, "foo")
          end.to raise_error(proc do |err|
            expect(err).to be_an_instance_of config::Error
            expect(err.message).to match(/Root Path Not Found/)
            expect(err.message).to match(/Path was: #{ path }/)
          end)
        end
      end
    end # describe '#set_root_path'

    describe "#set_path_variable" do
      after do
        if config.instance_variable_defined?(:@var)
          config.send(:remove_instance_variable, :@var)
        end
      end

      context "when a path is given" do
        context "when the given path is an absolute path" do
          it "should always use the given path" do
            path = File.expand_path("foo")

            config.send(:set_path_variable, "var", path, "none", "/root/path")
            expect(config.instance_variable_get(:@var)).to eq(path)

            config.send(:set_path_variable, "var", path, "none", nil)
            expect(config.instance_variable_get(:@var)).to eq(path)
          end
        end

        context "when the given path is a relative path" do
          context "when a root_path is given" do
            it "should append the path to the root_path" do
              config.send(:set_path_variable, "var", "foo", "none", "/root/path")
              expect(config.instance_variable_get(:@var)).to eq("/root/path/foo")
            end
          end
          context "when a root_path is not given" do
            it "should expand the path" do
              path = File.expand_path("foo")

              config.send(:set_path_variable, "var", "foo", "none", false)
              expect(config.instance_variable_get(:@var)).to eq(path)
            end
          end
        end
      end # context 'when a path is given'

      context "when no path is given" do
        context "when a root_path is given" do
          it "should use the root_path with the given ending" do
            config.send(:set_path_variable, "var", nil, "ending", "/root/path")
            expect(config.instance_variable_get(:@var)).to eq("/root/path/ending")
          end
        end
        context "when a root_path is not given" do
          it "should do nothing" do
            config.send(:set_path_variable, "var", nil, "ending", false)
            expect(config.instance_variable_defined?(:@var)).to eq(false)
          end
        end
      end # context 'when no path is given'
    end # describe '#set_path_variable'

    describe "#reset!" do
      before do
        @env_user = ENV["USER"]
        @env_home = ENV["HOME"]
      end

      after do
        ENV["USER"] = @env_user
        ENV["HOME"] = @env_home
      end

      it "should be called to set variables when module is loaded" do
        # just to avoid 'already initialized constant' warnings
        config.send(:remove_const, "DEFAULTS")

        expected = config.instance_variables.sort.map(&:to_sym) - [:@hostname, :@mocha]
        config.instance_variables.each do |var|
          config.send(:remove_instance_variable, var)
        end
        expect(config.instance_variables).to be_empty

        load File.expand_path("../../lib/backup/config.rb", __FILE__)
        expect(config.instance_variables.sort.map(&:to_sym)).to eq(expected)
      end

      context "when setting @user" do
        context 'when ENV["USER"] is set' do
          before { ENV["USER"] = "test" }

          it 'should set value for @user to ENV["USER"]' do
            config.send(:reset!)
            expect(config.user).to eq("test")
          end
        end

        context 'when ENV["USER"] is not set' do
          before { ENV.delete("USER") }

          it "should set value using the user login name" do
            config.send(:reset!)
            expect(config.user).to eq(Etc.getpwuid.name)
          end
        end
      end # context 'when setting @user'

      context "when setting @root_path" do
        context 'when ENV["HOME"] is set' do
          before { ENV["HOME"] = "test/home/dir" }

          it 'should set value using ENV["HOME"]' do
            config.send(:reset!)
            expect(config.root_path).to eq(
              File.join(File.expand_path("test/home/dir"), "Backup")
            )
          end
        end

        context 'when ENV["HOME"] is not set' do
          before { ENV.delete("HOME") }

          it "should set value using $PWD" do
            config.send(:reset!)
            expect(config.root_path).to eq(File.expand_path("Backup"))
          end
        end
      end # context 'when setting @root_path'

      context "when setting other path variables" do
        before { ENV["HOME"] = "test/home/dir" }

        it "should use #update" do
          expect(config).to receive(:update).with(
            root_path: File.join(File.expand_path("test/home/dir"), "Backup")
          )
          config.send(:reset!)
        end
      end
    end # describe '#reset!'
  end
end
