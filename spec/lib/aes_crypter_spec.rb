AESCrypter.describe do

  subject { AESCrypter }

  let(:plain_text) { "hello world" }
  let(:encrypted_text) { "734ab345ce3c187691998bcc368d02e4" }
  let(:key) { "spec_key" }

  context "#encrypt" do

    it "encrypts values" do
      expect(subject.encrypt(plain_text, key)).to eq encrypted_text
    end

    it "supports empty key" do
      expect { subject.encrypt(plain_text, "") }.not_to raise_error
    end

    it "raises error when nil key provided" do
      expect { subject.encrypt(plain_text, nil) }.to raise_error
    end

  end

  context "#decrypt" do

    it "decrypts value when original key provided" do
      expect(subject.decrypt(encrypted_text, key)).to eq plain_text
    end

    it "raises error when wrong key provided" do
      expect { subject.decrypt(encrypted_text, "not the original key") }.to raise_error
    end

    it "fails to decrypt when nil key provided" do
      expect { subject.decrypt(encrypted_text, nil) }.to raise_error
    end

    it "fails when nil value provided" do
      expect { subject.decrypt(nil, key) }.to raise_error
    end

  end

end