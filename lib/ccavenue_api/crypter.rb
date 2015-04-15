require 'aes_crypter'

module CcavenueApi
  class Crypter

    def initialize(encryption_key)
      @encryption_key = encryption_key
    end

    def encrypt(data)
      AESCrypter.encrypt(data, @encryption_key)
    end

    def decrypt(data)
      AESCrypter.decrypt(data, @encryption_key)
    end

  end
end