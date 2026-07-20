module Friendships
  CreateRequestResult = Data.define(:status, :friendship)

  class CreateRequest
    def self.call(requester:, addressee_email:)
      new(requester:, addressee_email:).call
    end

    def initialize(requester:, addressee_email:)
      @requester = requester
      @addressee_email = addressee_email.to_s.strip.downcase
    end

    def call
      addressee = User.find_by(email: addressee_email)
      return result(:not_found) unless addressee
      return result(:self_request) if addressee.id == requester.id

      Friendship.transaction do
        return result(:already_friends) if Friendship.accepted_between?(requester, addressee)

        forward = Friendship.find_by(requester: requester, addressee: addressee)

        return result(:already_requested, forward) if forward&.pending?

        reverse = Friendship.find_by(requester: addressee, addressee: requester)
        if reverse&.pending?
          reverse.accept!
          return result(:auto_accepted, reverse)
        end

        if forward&.declined?
          forward.update!(status: :pending)
          return result(:requested, forward)
        end

        friendship = Friendship.create!(requester: requester, addressee: addressee)
        reconcile_concurrent_reverse!(friendship)
      end
    end

    private

    attr_reader :requester, :addressee_email

    def reconcile_concurrent_reverse!(friendship)
      reverse = Friendship.pending.find_by(
        requester: friendship.addressee,
        addressee: friendship.requester
      )
      return result(:requested, friendship) unless reverse && reverse.id != friendship.id

      reverse.accept!
      friendship.destroy!
      result(:auto_accepted, reverse)
    end

    def result(status, friendship = nil)
      CreateRequestResult.new(status:, friendship:)
    end
  end
end
