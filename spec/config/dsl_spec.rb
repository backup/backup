require "spec_helper"

module Backup
  describe Config::DSL do
    describe ".add_dsl_constants" do
      it "adds constants when the module is loaded" do
        described_class.constants.each do |const|
          described_class.send(:remove_const, const)
        end
        expect(described_class.constants).to be_empty

        load File.expand_path("../../../lib/backup/config/dsl.rb", __FILE__)

        expect(described_class.const_defined?("MySQL")).to eq(true)
        expect(described_class.const_defined?("RSync")).to eq(true)
        expect(described_class::RSync.const_defined?("Local")).to eq(true)
      end
    end

    describe ".create_modules" do
      module TestScope; end

      context "when given an array of constant names" do
        it "creates modules for the given scope" do
          described_class.send(:create_modules, TestScope, ["Foo", "Bar"])
          expect(TestScope.const_defined?("Foo")).to eq(true)
          expect(TestScope.const_defined?("Bar")).to eq(true)
          expect(TestScope::Foo.class).to eq(Module)
          expect(TestScope::Bar.class).to eq(Module)
        end
      end

      context "when the given array contains Hash values" do
        it "creates deeply nested modules" do
          described_class.send(
            :create_modules,
            TestScope,
            ["FooBar", {
              LevelA: ["NameA", {
                LevelB: ["NameB"]
              }]
            }]
          )
          expect(TestScope.const_defined?("FooBar")).to eq(true)
          expect(TestScope.const_defined?("LevelA")).to eq(true)
          expect(TestScope::LevelA.const_defined?("NameA")).to eq(true)
          expect(TestScope::LevelA.const_defined?("LevelB")).to eq(true)
          expect(TestScope::LevelA::LevelB.const_defined?("NameB")).to eq(true)
        end
      end
    end

    describe "#_config_options" do
      it "returns paths set in config.rb" do
        [:root_path, :data_path, :tmp_path].each { |name| subject.send(name, name) }
        expect(subject._config_options).to eq(
          root_path: :root_path,
            data_path: :data_path,
            tmp_path: :tmp_path
        )
      end
    end

    describe "#preconfigure" do
      after do
        if described_class.const_defined?("MyBackup")
          described_class.send(:remove_const, "MyBackup")
        end
      end

      specify "name must be a String" do
        expect do
          subject.preconfigure(:Abc)
        end.to raise_error(described_class::Error)
      end

      specify "name must begin with a capital letter" do
        expect do
          subject.preconfigure("myBackup")
        end.to raise_error(described_class::Error)
      end

      specify "Backup::Model may not be preconfigured" do
        expect do
          subject.preconfigure("Model")
        end.to raise_error(described_class::Error)
      end

      specify "preconfigured models can only be preconfigured once" do
        block = proc {}
        subject.preconfigure("MyBackup", &block)
        klass = described_class.const_get("MyBackup")
        expect(klass.superclass).to eq(Backup::Model)

        expect do
          subject.preconfigure("MyBackup", &block)
        end.to raise_error(described_class::Error)
      end
    end
  end
end
