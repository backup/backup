# encoding: utf-8

require File.dirname(__FILE__) + '/../spec_helper'

describe Backup::Encryptor::GPG do

  let(:encryptor) do
    Backup::Encryptor::GPG.new do |e|
      e.key = <<-KEY
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Version: GnuPG v1.4.11 (Darwin)

        mQENBE12G/8BCAC4mnlSMYMBwBYTHe5zURcnYYNCORPWOr0iXGiLWuKxYtrDQyLm
        X2Nws44Iz7Wp7AuJRAjkitf1cRBgXyDu8wuogXO7JqPmtsUdBCABz9w5NH6IQjgR
        WNa3g2n0nokA7Zr5FA4GXoEaYivfbvGiyNpd6P4okH+//G2p+3FIryu5xz+89D1b
        =Yvhg
        -----END PGP PUBLIC KEY BLOCK-----
      KEY
    end
  end

  context "when a block is provided" do
    it do
      key = <<-KEY
        -----BEGIN PGP PUBLIC KEY BLOCK-----
        Version: GnuPG v1.4.11 (Darwin)

        mQENBE12G/8BCAC4mnlSMYMBwBYTHe5zURcnYYNCORPWOr0iXGiLWuKxYtrDQyLm
        X2Nws44Iz7Wp7AuJRAjkitf1cRBgXyDu8wuogXO7JqPmtsUdBCABz9w5NH6IQjgR
        WNa3g2n0nokA7Zr5FA4GXoEaYivfbvGiyNpd6P4okH+//G2p+3FIryu5xz+89D1b
        =Yvhg
        -----END PGP PUBLIC KEY BLOCK-----
      KEY

      encryptor.key.should == key.gsub(/^(\s|\t)+/, '')
    end
  end
end
