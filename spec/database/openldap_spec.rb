require "spec_helper"

module Backup
  describe Database::OpenLDAP do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:db) { Database::OpenLDAP.new(model) }
    let(:s) { sequence "" }

    before do
      allow_any_instance_of(Database::OpenLDAP).to receive(:utility)
        .with(:slapcat).and_return("/real/slapcat")
      allow_any_instance_of(Database::OpenLDAP).to receive(:utility)
        .with(:cat).and_return("cat")
      allow_any_instance_of(Database::OpenLDAP).to receive(:utility)
        .with(:sudo).and_return("sudo")
    end

    it_behaves_like "a class that includes Config::Helpers"
    it_behaves_like "a subclass of Database::Base"

    describe "#initialize" do
      it "provides default values" do
        expect(db.name).to eq("ldap_backup")
        expect(db.slapcat_args).to be_empty
        expect(db.use_sudo).to eq(false)
        expect(db.slapcat_utility).to eq "/real/slapcat"
        expect(db.slapcat_conf).to eq "/etc/ldap/slapd.d"
      end

      it "configures the database" do
        db = Database::OpenLDAP.new(model) do |ldap|
          ldap.name         = "my_name"
          ldap.slapcat_args = ["--query", "--foo"]
        end

        expect(db.name).to eq "my_name"
        expect(db.slapcat_args).to eq ["--query", "--foo"]
      end
    end # describe '#initialize'

    describe "#perform!" do
      let(:pipeline) { double }
      let(:compressor) { double }

      before do
        allow(db).to receive(:slapcat).and_return("slapcat_command")
        allow(db).to receive(:dump_path).and_return("/tmp/trigger/databases")

        expect(db).to receive(:log!).ordered.with(:started)
        expect(db).to receive(:prepare!).ordered
      end

      context "without a compressor" do
        it "packages the dump without compression" do
          expect(Pipeline).to receive(:new).ordered.and_return(pipeline)

          expect(pipeline).to receive(:<<).ordered.with("slapcat_command")

          expect(pipeline).to receive(:<<).ordered.with(
            "cat > '/tmp/trigger/databases/OpenLDAP.ldif'"
          )

          expect(pipeline).to receive(:run).ordered
          expect(pipeline).to receive(:success?).ordered.and_return(true)

          expect(db).to receive(:log!).ordered.with(:finished)

          db.perform!
        end
      end # context 'without a compressor'

      context "with a compressor" do
        before do
          allow(model).to receive(:compressor).and_return(compressor)
          allow(compressor).to receive(:compress_with).and_yield("cmp_cmd", ".cmp_ext")
        end

        it "packages the dump with compression" do
          expect(Pipeline).to receive(:new).ordered.and_return(pipeline)

          expect(pipeline).to receive(:<<).ordered.with("slapcat_command")

          expect(pipeline).to receive(:<<).ordered.with("cmp_cmd")

          expect(pipeline).to receive(:<<).ordered.with(
            "cat > '/tmp/trigger/databases/OpenLDAP.ldif.cmp_ext'"
          )

          expect(pipeline).to receive(:run).ordered
          expect(pipeline).to receive(:success?).ordered.and_return(true)

          expect(db).to receive(:log!).ordered.with(:finished)

          db.perform!
        end
      end # context 'without a compressor'

      context "when the pipeline fails" do
        before do
          allow_any_instance_of(Pipeline).to receive(:success?).and_return(false)
          allow_any_instance_of(Pipeline).to receive(:error_messages).and_return("error messages")
        end

        it "raises an error" do
          expect do
            db.perform!
          end.to raise_error(Database::OpenLDAP::Error) { |err|
            expect(err.message).to eq(
              "Database::OpenLDAP::Error: Dump Failed!\n  error messages"
            )
          }
        end
      end # context 'when the pipeline fails'
    end # describe '#perform!'

    describe "#slapcat" do
      let(:slapcat_args) do
        [
          "-H",
          "ldap:///subtree-dn",
          "-a",
          %("(!(entryDN:dnSubtreeMatch:=ou=People,dc=example,dc=com))")
        ]
      end

      before do
        allow(db).to receive(:slapcat_utility).and_return("real_slapcat")
      end

      it "returns full slapcat command built from confdir" do
        expect(db.send(:slapcat)).to eq(
          "real_slapcat -F /etc/ldap/slapd.d "
        )
      end

      it "returns full slapcat command built from additional options and conf file" do
        allow(db).to receive(:slapcat_args).and_return(slapcat_args)
        expect(db.send(:slapcat)).to eq "real_slapcat -F /etc/ldap/slapd.d -H ldap:///subtree-dn "\
          "-a \"(!(entryDN:dnSubtreeMatch:=ou=People,dc=example,dc=com))\""
      end

      it "supports sudo" do
        allow(db).to receive(:use_sudo).and_return("true")
        expect(db.send(:slapcat)).to eq(
          "sudo real_slapcat -F /etc/ldap/slapd.d "
        )
      end

      it "returns full slapcat command built from additional options and conf file and sudo" do
        allow(db).to receive(:slapcat_args).and_return(slapcat_args)
        allow(db).to receive(:use_sudo).and_return("true")
        expect(db.send(:slapcat)).to eq "sudo real_slapcat -F /etc/ldap/slapd.d -H "\
          "ldap:///subtree-dn -a \"(!(entryDN:dnSubtreeMatch:=ou=People,dc=example,dc=com))\""
      end

      context "slapcat_conf_option" do
        it "supports both slapcat confdir" do
          db.instance_variable_set(:@slapcat_conf, "/etc/ldap/slapd.d")
          expect(db.send(:slapcat)).to eq(
            "real_slapcat -F /etc/ldap/slapd.d "
          )
        end

        it "supports both slapcat conffile" do
          db.instance_variable_set(:@slapcat_conf, "/etc/ldap/ldap.conf")
          expect(db.send(:slapcat)).to eq(
            "real_slapcat -f /etc/ldap/ldap.conf "
          )
        end
      end
    end # describe '#slapcat'
  end
end
