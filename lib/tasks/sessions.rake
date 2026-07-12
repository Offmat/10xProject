namespace :sessions do
  desc 'Delete expired session records older than Session::LIFETIME'
  task sweep: :environment do
    deleted = Session.sweep
    puts "Sessions: #{deleted} expired session(s) deleted"
  end
end
